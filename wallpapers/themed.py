#!/usr/bin/env python3
"""Pre-draws four quiet wallpapers for every color preset of the shell.

    wallpapers/themed.py [KEY...] [--out DIR] [--size WxH]

Reads the presets straight from ThemeStore.qml, so a new preset gets its
wallpapers on the next run. Writes DIR/<key>/<n>-<design>.png, which
[SYS] > [LOOK] offers beside the preset (as small vector sketches of the
four designs, ThemeStore.wallpaperLayouts — keep them in step); DIR
defaults to ~/.local/share/muthur-shell/wallpapers. With KEYs, only
those presets are drawn.

The four designs stay in the background: low contrast, the palette's
dim tones, almost no text.
  1-grid      a fine drafting grid, a few accent ticks on the major lines
  2-topo      topographic lines, one level in the accent
  3-horizon   the wireframe ground plane fading into a soft horizon
  4-dots      a dot matrix swelling and thinning like a halftone
"""

import math
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate as g  # noqa: E402  (shared SVG helpers and noise)

HERE = os.path.dirname(os.path.abspath(__file__))
THEMESTORE = os.path.join(HERE, "..", "dotfiles", "quickshell", "muthur", "ThemeStore.qml")


def presets():
    s = open(THEMESTORE).read()
    block = s[s.index("readonly property var builtinPresets"):s.index("// The wallpaper-derived palette")]
    pat = re.compile(r'\{ key: "(\w+)", name: "([^"]+)",\s*special: \{([^}]*)\},\s*colors: \{([^}]*)\}', re.S)
    out = []
    for key, name, special, colors in pat.findall(block):
        sp = dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', special))
        co = dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', colors))
        main = sp["foreground"]
        second, third = companions(main, [co["color%d" % i] for i in range(1, 7)])
        out.append(dict(key=key, name=name, bg=sp["background"], fg=main, accent=sp["cursor"],
                        dim=co["color8"], second=second, third=third))
    return out


def hsl(hexcolor):
    import colorsys
    r, gg, b = (int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, gg, b)
    return h, s, l


def hue_gap(a, b):
    d = abs(hsl(a)[0] - hsl(b)[0])
    return min(d, 1 - d)


def companions(main, hues):
    """The wallpaper's second and third colors: the palette's 3rd and 4th
    slots (color2, color3: what the preset's swatch row shows after
    black and red), skipping any that is just the main color again or a
    grey, then on through color4.. and color1. A monochrome theme falls
    back on the main color itself."""
    order = [hues[i] for i in (1, 2, 3, 4, 5, 0)]   # color2, 3, 4, 5, 6, 1
    picked = []
    for c in order:
        if hsl(c)[1] > 0.15 and hue_gap(c, main) > 0.04 and all(hue_gap(c, q) > 0.04 for q in picked):
            picked.append(c)
        if len(picked) == 2:
            break
    while len(picked) < 2:
        picked.append(main)
    return picked[0], picked[1]


def light(hexcolor):
    r, gg, b = (int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return (max(r, gg, b) + min(r, gg, b)) / 2 > 0.5


def seed_of(key):
    return sum(ord(c) * (i + 1) for i, c in enumerate(key)) % 9973


# --- The four designs -------------------------------------------------------

def grid(p, seed):
    W, H = g.W, g.H
    minor = "".join(f"M{x} 0V{H}" for x in range(0, W, 32)) + "".join(f"M0 {y}H{W}" for y in range(0, H, 32))
    major = "".join(f"M{x} 0V{H}" for x in range(0, W, 160)) + "".join(f"M0 {y}H{W}" for y in range(0, H, 160))
    ticks = ([], [])
    noise = g.Noise(seed)
    for x in range(160, W, 160):
        for y in range(160, H, 160):
            v = noise.value(x / 400.0, y / 400.0)
            if v > 0.78:
                ticks[int(v * 1000) % 2].append(f"M{x - 8} {y}H{x + 8}M{x} {y - 8}V{y + 8}")
    body = (f'<path d="{minor}" stroke="{p["dim"]}" stroke-width="1" opacity="0.15"/>'
            f'<path d="{major}" stroke="{p["fg"]}" stroke-width="1" opacity="0.12"/>'
            f'<path d="{"".join(ticks[0])}" stroke="{p["second"]}" stroke-width="1.6" opacity="0.6"/>'
            f'<path d="{"".join(ticks[1])}" stroke="{p["third"]}" stroke-width="1.6" opacity="0.6"/>')
    vdefs, vrect = g.vignette(0.2 if light(p["bg"]) else 0.45)
    return g.svg(body + vrect, p["bg"], vdefs)


def topo(p, seed):
    W, H = g.W, g.H
    noise = g.Noise(seed)
    step = 14
    cols, rows = W // step + 2, H // step + 2
    field = [[noise.fbm(i * step / 560.0, j * step / 560.0, 4) for i in range(cols)] for j in range(rows)]
    levels = [0.22 + k * 0.024 for k in range(24)]
    paths = g.contour_paths(field, cols, rows, step, levels)
    body = []
    for k, level in enumerate(levels):
        accent = k == 12
        color = p["fg"] if accent else p["second"] if k < 8 else p["third"] if k > 16 else p["dim"]
        body.append(f'<path d="{paths[level]}" fill="none" stroke="{color}" '
                    f'stroke-width="{1.5 if accent else 1.0}" opacity="{0.55 if accent else 0.2 if color != p["dim"] else 0.26}"/>')
    body.append(f'<rect x="120" y="{H - 150}" width="140" height="3" fill="{p["accent"]}" opacity="0.7"/>')
    body.append(g.text(120, H - 110, p["name"], 24, p["dim"], spacing=8, opacity=0.8))
    vdefs, vrect = g.vignette(0.2 if light(p["bg"]) else 0.45)
    return g.svg("".join(body) + vrect, p["bg"], vdefs)


def horizon(p, seed):
    W, H = g.W, g.H
    hz = H * 0.62
    depth = H - hz
    rails = "".join(f"M{W / 2:.1f} {hz:.1f}L{W / 2 + (i / 40 - 0.5) * 3.4 * W:.1f} {H}" for i in range(41))
    cross = "".join(f"M0 {hz + depth / d:.1f}H{W}" for d in range(1, 24))
    defs = (f'<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{p["bg"]}" stop-opacity="1"/>'
            f'<stop offset="1" stop-color="{p["bg"]}" stop-opacity="0"/></linearGradient>'
            f'<radialGradient id="sky" cx="50%" cy="62%" r="55%">'
            f'<stop offset="0" stop-color="{p["second"]}" stop-opacity="0.09"/>'
            f'<stop offset="1" stop-color="{p["second"]}" stop-opacity="0"/></radialGradient>')
    body = (f'<rect width="{W}" height="{H}" fill="url(#sky)"/>'
            f'<path d="{rails}" stroke="{p["fg"]}" stroke-width="1.2" opacity="0.18"/>'
            f'<path d="{cross}" stroke="{p["second"]}" stroke-width="1.2" opacity="0.22"/>'
            f'<rect y="{hz:.1f}" width="{W}" height="{depth * 0.4:.1f}" fill="url(#haze)"/>'
            f'<path d="M0 {hz:.1f}H{W}" stroke="{p["third"]}" stroke-width="1.5" opacity="0.55"/>')
    sdefs, srect = g.scanlines(0.12)
    vdefs, vrect = g.vignette(0.25 if light(p["bg"]) else 0.55)
    return g.svg(body + srect + vrect, p["bg"], defs + sdefs + vdefs)


def dots(p, seed):
    W, H = g.W, g.H
    noise = g.Noise(seed)
    gap = 26
    bands = {"dim": [], "fg": [], "second": [], "third": []}
    tint = g.Noise(seed + 1)
    for y in range(gap // 2, H, gap):
        for x in range(gap // 2, W, gap):
            v = noise.fbm(x / 700.0, y / 700.0, 3)
            r = max(0.0, (v - 0.35) * 9.0)
            if r > 0.4:
                t = tint.fbm(x / 900.0, y / 900.0, 2)
                band = "dim" if r < 1.2 else "second" if t > 0.6 else "third" if t < 0.38 else "fg"
                bands[band].append(f"M{x - r:.1f} {y}a{r:.1f} {r:.1f} 0 1 0 {2 * r:.1f} 0a{r:.1f} {r:.1f} 0 1 0 {-2 * r:.1f} 0")
    opacity = {"dim": 0.4, "fg": 0.22, "second": 0.26, "third": 0.26}
    body = "".join(f'<path d="{"".join(d)}" fill="{p[k]}" opacity="{opacity[k]}"/>' for k, d in bands.items())
    vdefs, vrect = g.vignette(0.2 if light(p["bg"]) else 0.45)
    return g.svg(body + vrect, p["bg"], vdefs)


DESIGNS = [("1-grid", grid), ("2-topo", topo), ("3-horizon", horizon), ("4-dots", dots)]


def main(argv):
    out = os.path.expanduser("~/.local/share/muthur-shell/wallpapers")
    keys = []
    args = iter(argv)
    for a in args:
        if a == "--out":
            out = os.path.expanduser(next(args))
        elif a == "--size":
            g.W, g.H = (int(n) for n in next(args).lower().split("x"))
        else:
            keys.append(a)
    for p in presets():
        if keys and p["key"] not in keys:
            continue
        folder = os.path.join(out, p["key"])
        os.makedirs(folder, exist_ok=True)
        for name, draw in DESIGNS:
            target = os.path.join(folder, name + ".png")
            with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
                f.write(draw(p, seed_of(p["key"] + name)))
                svg = f.name
            subprocess.run(["rsvg-convert", "-o", target, svg], check=True)
            os.unlink(svg)
        print(folder)


if __name__ == "__main__":
    main(sys.argv[1:])
