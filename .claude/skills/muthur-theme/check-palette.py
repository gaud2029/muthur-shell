#!/usr/bin/env python3
"""Contrast report for muthur color presets, read from ThemeStore.qml.

    check-palette.py KEY [KEY...]     one or more presets
    check-palette.py --all            every preset

For each preset: whether it counts as light or dark (the LOOK tab sorts
it by its background's HSL lightness), then the WCAG contrast of the
foreground, dim (color8), focus (cursor) and the twelve hue slots
against the background, flagged when under the recipe's floors (see
SKILL.md): foreground 7, focus 4.5, dim 3, hue slots 4.5 (color0, 7, 8
and 15 are structural and skipped from the hue check).
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
THEMESTORE = os.path.join(ROOT, "dotfiles", "quickshell", "muthur", "ThemeStore.qml")


def presets():
    s = open(THEMESTORE).read()
    block = s[s.index("readonly property var builtinPresets"):s.index("// The wallpaper-derived palette")]
    pat = re.compile(r'\{ key: "(\w+)", name: "([^"]+)",\s*special: \{([^}]*)\},\s*colors: \{([^}]*)\}', re.S)
    for key, name, special, colors in pat.findall(block):
        yield key, name, dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', special)), \
            dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', colors))


def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def lightness(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return (max(c) + min(c)) / 2


def report(key, name, sp, co):
    bg = sp["background"]
    print(f"{name} ({key}): {'LIGHT' if lightness(bg) > 0.5 else 'DARK'}, background {bg}")
    bad = 0
    rows = [("foreground", sp["foreground"], 7.0), ("focus", sp["cursor"], 4.5), ("dim", co["color8"], 3.0)]
    rows += [(f"color{i}", co[f"color{i}"], 4.5) for i in list(range(1, 7)) + list(range(9, 15))]
    for label, color, floor in rows:
        r = ratio(color, bg)
        flag = "" if r >= floor else f"   < {floor}"
        bad += bool(flag)
        print(f"  {label:<11}{color}  {r:5.1f}{flag}")
    print(f"  {'OK' if not bad else str(bad) + ' under the floor'}\n")
    return bad


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    found = {k: (k, n, sp, co) for k, n, sp, co in presets()}
    keys = list(found) if argv == ["--all"] else argv
    total = 0
    for k in keys:
        if k not in found:
            print(f"{k}: no such preset in ThemeStore.qml\n")
            total += 1
            continue
        total += report(*found[k])
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
