#!/usr/bin/env python3
"""Build a pywal-shaped palette from an image, in the shell's muted style.

Usage: wallpaper-palette.py <image>
Prints {"wallpaper": path, "special": {background, foreground, cursor},
        "colors": {color0 .. color15}} — the same shape pywal's colors.json
has, so ThemeStore.paletteFromPywal() accepts it as a preset.

Colors are quantized with ImageMagick (no Pillow/pywal dependency). The
image's dominant saturated hue becomes the theme's foreground/cursor, the
background is its darkest tone pulled near black, and the twelve ANSI hue
slots are muted and pulled toward that dominant hue — same rules as the
built-in presets, so a wallpaper theme still reads as one phosphor screen.
"""
import colorsys
import json
import os
import re
import subprocess
import sys

ANSI_HUES = {1: 0.0, 3: 1 / 6, 2: 1 / 3, 6: 1 / 2, 4: 2 / 3, 5: 5 / 6}   # red yellow green cyan blue magenta


def quantize(path, n=24):
    out = subprocess.run(
        ["magick", path + "[0]", "-resize", "256x256!", "-depth", "8", "-colors", str(n),
         "-format", "%c", "histogram:info:-"],
        capture_output=True, text=True, check=True).stdout
    colors = []
    for line in out.splitlines():
        m = re.search(r"^\s*(\d+):.*#([0-9A-Fa-f]{6})", line)
        if m:
            count, hexcode = int(m.group(1)), m.group(2)
            r, g, b = (int(hexcode[i:i + 2], 16) for i in (0, 2, 4))
            colors.append((count, (r / 255, g / 255, b / 255)))
    if not colors:
        raise RuntimeError("no colors extracted")
    return colors


def hsl(rgb):
    h, l, s = colorsys.rgb_to_hls(*rgb)
    return h, s, l


def from_hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def hue_distance(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1 - d)


def blend_hue(h, toward, amount):
    d = (toward - h + 0.5) % 1.0 - 0.5
    return (h + d * amount) % 1.0


def main():
    if len(sys.argv) < 2 or not os.path.isfile(sys.argv[1]):
        print(json.dumps({"error": "image not found"}))
        return 1
    path = os.path.abspath(sys.argv[1])
    colors = quantize(path)
    total = sum(c for c, _ in colors)

    # Dominant saturated hue: weight by pixel share and saturation, ignoring
    # near-black/near-white tones that carry no hue information.
    best, best_score = None, -1
    for count, rgb in colors:
        h, s, l = hsl(rgb)
        if l < 0.12 or l > 0.92:
            continue
        score = (count / total) * (s ** 1.5) * (1 - abs(l - 0.5))
        if score > best_score:
            best, best_score = (h, s, l), score
    if best is None:
        best = (1 / 3, 0.2, 0.5)
    hue, sat, _ = best
    sat = max(0.45, min(0.9, sat + 0.2))

    darkest = min(colors, key=lambda c: hsl(c[1])[2])
    bg_h, bg_s, _ = hsl(darkest[1])
    bg_s = min(bg_s, 0.6)
    background = from_hsl(bg_h, bg_s, 0.05)
    foreground = from_hsl(hue, sat, 0.62)
    cursor = from_hsl(hue, sat, 0.82)

    palette = {
        "color0": from_hsl(bg_h, bg_s, 0.10),
        "color7": from_hsl(hue, sat * 0.4, 0.72),
        "color8": from_hsl(hue, sat * 0.7, 0.28),
        "color15": from_hsl(hue, sat * 0.3, 0.92),
    }
    for slot, ansi_hue in ANSI_HUES.items():
        h = blend_hue(ansi_hue, hue, 0.35)
        # The theme's own hue slot carries the foreground itself.
        if hue_distance(ansi_hue, hue) < 1 / 12:
            palette["color%d" % slot] = foreground
            palette["color%d" % (slot + 8)] = cursor
            continue
        palette["color%d" % slot] = from_hsl(h, 0.32, 0.55)
        palette["color%d" % (slot + 8)] = from_hsl(h, 0.36, 0.70)

    print(json.dumps({
        "wallpaper": path,
        "special": {"background": background, "foreground": foreground, "cursor": cursor},
        "colors": {("color%d" % i): palette["color%d" % i] for i in range(16)},
    }))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # surfaced in the LOOK tab
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
