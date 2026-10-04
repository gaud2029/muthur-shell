#!/usr/bin/env python3
"""Draws the muthur wallpapers: SVG by hand, rendered to PNG by rsvg-convert.

    wallpapers/generate.py [OUT_DIR] [--size WxH] [--only NAME...]

OUT_DIR defaults to ~/Pictures/Wallpapers, the folder [SYS] > [LOOK]
lists; the default size is 3440x1440 (swaybg crops to fill, and every
design keeps its subject away from the sides). Each run with the same
size draws the same images: the noise is seeded per design.

Four families, in the shell's palettes:
  corpo-carbon[-light]    topographic lines over a dot grid, for work
  crt-*                   the lock screen's tube as a still
  nostromo-schematic-*    a technical drawing of the ship
  flow / ridges / contours  generative, after Neo, Hackers and Tron
"""

import math
import os
import random
import subprocess
import sys
import tempfile

W, H = 3440, 1440
FONT = "Noto Sans Mono"


# --- Palettes (from ThemeStore.qml) ---------------------------------------

PAL = {
    "corpo": dict(bg="#2b2d30", fg="#c9ccd0", dim="#83888f", accent="#a3b6c8"),
    "corpoLight": dict(bg="#d4d6d9", fg="#2a2d31", dim="#5d6269", accent="#405871"),
    "muthur": dict(bg="#0a0c06", fg="#a8d848", dim="#4a6820", accent="#f0f0c0"),
    "amber": dict(bg="#0a0c16", fg="#f0a828", dim="#6a4c1a", accent="#ffd890"),
    "nostromo": dict(bg="#e8e4d8", fg="#2c2a26", dim="#8a8478", accent="#c07a18"),
    "nostromoDark": dict(bg="#101318", fg="#cfc8b4", dim="#5c5a52", accent="#e09a3a"),
    "neo": dict(bg="#04120a", fg="#33ff66", dim="#1a7a3a", accent="#aaffcc",
                hues=["#33ff66", "#4fd0b0", "#aaffcc", "#b8c65a", "#1a7a3a"]),
    "hackers": dict(bg="#0a0616", fg="#4cf0c8", dim="#4a3a7a", accent="#ff3fbf",
                    hues=["#4cf0c8", "#5a7cff", "#c85aff", "#ff3fbf"]),
    "tron": dict(bg="#04080f", fg="#6fc3df", dim="#1f4a5c", accent="#f0a030",
                 hues=["#1f4a5c", "#3a8fbf", "#6fc3df", "#a0e0f8", "#f0a030"]),
}


# --- Noise --------------------------------------------------------------

class Noise:
    """Smooth value noise with octaves, seeded."""

    def __init__(self, seed):
        self.seed = seed

    def lattice(self, ix, iy):
        h = (ix * 374761393 + iy * 668265263 + self.seed * 982451653) & 0xFFFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

    def value(self, x, y):
        ix, iy = math.floor(x), math.floor(y)
        fx, fy = x - ix, y - iy
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a, b = self.lattice(ix, iy), self.lattice(ix + 1, iy)
        c, d = self.lattice(ix, iy + 1), self.lattice(ix + 1, iy + 1)
        return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy

    def fbm(self, x, y, octaves=4):
        total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
        for _ in range(octaves):
            total += amp * self.value(x * freq, y * freq)
            norm += amp
            amp *= 0.5
            freq *= 2.0
        return total / norm


# --- SVG helpers ----------------------------------------------------------

def svg(body, bg, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><defs>{defs}</defs>'
            f'<rect width="{W}" height="{H}" fill="{bg}"/>{body}</svg>')


def text(x, y, s, size, fill, anchor="start", weight="normal", spacing=0, opacity=1.0):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" '
            f'font-weight="{weight}" letter-spacing="{spacing}" fill="{fill}" '
            f'fill-opacity="{opacity}" text-anchor="{anchor}">{s}</text>')


def vignette(strength=0.55):
    defs = (f'<radialGradient id="vig" cx="50%" cy="50%" r="75%">'
            f'<stop offset="55%" stop-color="#000" stop-opacity="0"/>'
            f'<stop offset="100%" stop-color="#000" stop-opacity="{strength}"/></radialGradient>')
    return defs, f'<rect width="{W}" height="{H}" fill="url(#vig)"/>'


def scanlines(opacity=0.22):
    defs = ('<pattern id="scan" width="4" height="3" patternUnits="userSpaceOnUse">'
            '<rect y="2" width="4" height="1" fill="#000"/></pattern>')
    return defs, f'<rect width="{W}" height="{H}" fill="url(#scan)" opacity="{opacity}"/>'


def glow(name, radius):
    return (f'<filter id="{name}" x="-10%" y="-10%" width="120%" height="120%">'
            f'<feGaussianBlur stdDeviation="{radius}" result="b"/>'
            f'<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')


def contour_paths(field, cols, rows, step, levels):
    """Marching squares: {level: path data} for a field sampled on a grid."""
    out = {}
    for level in levels:
        d = []
        for j in range(rows - 1):
            for i in range(cols - 1):
                a, b = field[j][i], field[j][i + 1]
                c, e = field[j + 1][i + 1], field[j + 1][i]
                idx = (a > level) | (b > level) << 1 | (c > level) << 2 | (e > level) << 3
                if idx in (0, 15):
                    continue
                x, y = i * step, j * step

                def lerp(p, q):
                    return 0.5 if p == q else (level - p) / (q - p)
                top = (x + lerp(a, b) * step, y)
                right = (x + step, y + lerp(b, c) * step)
                bottom = (x + lerp(e, c) * step, y + step)
                left = (x, y + lerp(a, e) * step)
                segs = {1: [(left, top)], 2: [(top, right)], 3: [(left, right)],
                        4: [(right, bottom)], 5: [(left, top), (right, bottom)],
                        6: [(top, bottom)], 7: [(left, bottom)], 8: [(bottom, left)],
                        9: [(bottom, top)], 10: [(top, right), (bottom, left)],
                        11: [(bottom, right)], 12: [(right, left)], 13: [(right, top)],
                        14: [(top, left)]}[idx]
                for p, q in segs:
                    d.append(f"M{p[0]:.1f} {p[1]:.1f}L{q[0]:.1f} {q[1]:.1f}")
        out[level] = "".join(d)
    return out


# --- Corpo Carbon -----------------------------------------------------------

def corpo(pal, seed):
    p = PAL[pal]
    noise = Noise(seed)
    step = 14
    cols, rows = W // step + 2, H // step + 2
    field = [[noise.fbm(i * step / 520.0, j * step / 520.0, 4) for i in range(cols)] for j in range(rows)]
    levels = [0.22 + k * 0.022 for k in range(26)]
    paths = contour_paths(field, cols, rows, step, levels)

    body = []
    dots = []
    for y in range(40, H, 48):
        for x in range(40, W, 48):
            dots.append(f"M{x} {y}h1.6")
    body.append(f'<path d="{"".join(dots)}" stroke="{p["dim"]}" stroke-width="1.6" '
                f'stroke-linecap="round" opacity="0.35"/>')
    for k, level in enumerate(levels):
        accent = k == 13
        body.append(f'<path d="{paths[level]}" fill="none" stroke="{p["accent"] if accent else p["dim"]}" '
                    f'stroke-width="{1.6 if accent else 1.0}" opacity="{0.75 if accent else 0.28}"/>')
    body.append(text(120, H - 110, "CORPO CARBON", 26, p["dim"], spacing=8, opacity=0.8))
    body.append(text(120, H - 76, "WORKSTATION  //  SECTOR 7G  //  " + ("LIGHT" if "Light" in pal else "DARK"),
                     16, p["dim"], spacing=4, opacity=0.6))
    body.append(f'<rect x="120" y="{H - 150}" width="160" height="3" fill="{p["accent"]}" opacity="0.8"/>')
    vdefs, vrect = vignette(0.25 if "Light" in pal else 0.45)
    return svg("".join(body) + vrect, p["bg"], vdefs)


# --- MU/TH/UR CRT -----------------------------------------------------------

def crt(pal, seed):
    p = PAL[pal]
    rnd = random.Random(seed)
    horizon = H * 0.6
    depth = H - horizon
    body = []

    # The ground plane, as in VectorTerrain.qml.
    rails = []
    for i in range(41):
        xb = W / 2 + (i / 40 - 0.5) * 3.4 * W
        rails.append(f"M{W / 2:.1f} {horizon:.1f}L{xb:.1f} {H}")
    cross = []
    for d in range(1, 26):
        y = horizon + depth / d
        cross.append(f"M0 {y:.1f}H{W}")
    defs = (glow("g1", 3) + glow("g2", 6)
            + f'<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1">'
              f'<stop offset="0" stop-color="{p["bg"]}" stop-opacity="1"/>'
              f'<stop offset="1" stop-color="{p["bg"]}" stop-opacity="0"/></linearGradient>'
            + f'<radialGradient id="tube" cx="50%" cy="45%" r="70%">'
              f'<stop offset="0" stop-color="{p["fg"]}" stop-opacity="0.07"/>'
              f'<stop offset="1" stop-color="{p["fg"]}" stop-opacity="0"/></radialGradient>')
    body.append(f'<rect width="{W}" height="{H}" fill="url(#tube)"/>')
    body.append(f'<g filter="url(#g1)" stroke="{p["fg"]}" stroke-width="1.4" opacity="0.4">'
                f'<path d="{"".join(rails)}"/><path d="{"".join(cross)}"/></g>')
    body.append(f'<rect y="{horizon:.1f}" width="{W}" height="{depth * 0.3:.1f}" fill="url(#haze)"/>')
    body.append(f'<path d="M0 {horizon:.1f}H{W}" stroke="{p["fg"]}" stroke-width="2" filter="url(#g2)"/>')

    # Header and a console, in the lock screen's layout.
    m = 140
    g = [text(m, m + 40, "MU/TH/UR 6000", 56, p["fg"], weight="bold", spacing=12),
         text(m, m + 84, "INTERFACE 2037  ·  MAINFRAME ACCESS", 24, p["fg"], spacing=6, opacity=0.55),
         text(W - m, m + 30, "WEYLAND-YUTANI CORP", 24, p["fg"], anchor="end", spacing=6),
         text(W - m, m + 66, "USCSS NOSTROMO  ·  180924609", 24, p["fg"], anchor="end", spacing=6, opacity=0.55),
         f'<rect x="{m}" y="{m + 118}" width="{W - 2 * m}" height="1.5" fill="{p["dim"]}"/>',
         f'<rect x="{m}" y="{m + 116}" width="260" height="5" fill="{p["fg"]}"/>']
    lines = ["> SPECIAL ORDER 937", "> SCIENCE OFFICER EYES ONLY",
             "> PRIORITY ONE: INSURE RETURN OF ORGANISM FOR ANALYSIS.",
             "> ALL OTHER CONSIDERATIONS SECONDARY.", "> CREW EXPENDABLE."]
    for k, line in enumerate(lines):
        g.append(text(m, H * 0.33 + k * 52, line, 30, p["fg"] if k < 4 else p["accent"], spacing=4,
                      opacity=0.85 if k < 4 else 1.0))
    g.append(f'<rect x="{m + 30 * 0.6 * 22 + 8}" y="{H * 0.33 + 4 * 52 - 28:.1f}" width="18" height="32" fill="{p["accent"]}"/>')
    words = " ".join(f"{rnd.randrange(65536):04X}" for _ in range(8))
    g.append(text(W / 2, H - m + 30, words, 20, p["dim"], anchor="middle", spacing=6))
    body.append(f'<g filter="url(#g1)">{"".join(g)}</g>')

    sdefs, srect = scanlines(0.28)
    vdefs, vrect = vignette(0.7)
    return svg("".join(body) + srect + vrect, p["bg"], defs + sdefs + vdefs)


# --- Nostromo schematic -------------------------------------------------------

def schematic(pal, seed):
    p = PAL[pal]
    ink, dim, acc = p["fg"], p["dim"], p["accent"]
    body = []

    # Drafting grid.
    minor = "".join(f"M{x} 0V{H}" for x in range(0, W, 40)) + "".join(f"M0 {y}H{W}" for y in range(0, H, 40))
    major = "".join(f"M{x} 0V{H}" for x in range(0, W, 200)) + "".join(f"M0 {y}H{W}" for y in range(0, H, 200))
    body.append(f'<path d="{minor}" stroke="{dim}" stroke-width="0.6" opacity="0.18"/>')
    body.append(f'<path d="{major}" stroke="{dim}" stroke-width="1" opacity="0.32"/>')
    body.append(f'<rect x="60" y="60" width="{W - 120}" height="{H - 120}" fill="none" stroke="{ink}" stroke-width="2.5"/>')
    body.append(f'<rect x="76" y="76" width="{W - 152}" height="{H - 152}" fill="none" stroke="{ink}" stroke-width="1"/>')

    # The ship in profile: a long spine, the command block and its
    # towers, the refinery clamps, three engines at the stern.
    x0, x1, cy = 620, 2780, 700
    S = []
    def poly(pts, width=2.0, fill="none", color=None):
        d = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + "Z"
        S.append(f'<path d="{d}" fill="{fill}" stroke="{color or ink}" stroke-width="{width}" stroke-linejoin="round"/>')
    poly([(x0, cy - 40), (x0 + 120, cy - 70), (x1 - 520, cy - 70), (x1 - 470, cy - 120), (x1 - 220, cy - 120),
          (x1 - 160, cy - 60), (x1, cy - 50), (x1, cy + 60), (x1 - 160, cy + 80), (x1 - 470, cy + 90),
          (x0 + 120, cy + 60), (x0, cy + 30)], 2.6)
    poly([(x0 + 260, cy - 70), (x0 + 300, cy - 190), (x0 + 560, cy - 190), (x0 + 600, cy - 70)])
    poly([(x0 + 340, cy - 190), (x0 + 360, cy - 280), (x0 + 470, cy - 280), (x0 + 500, cy - 190)])
    poly([(x0 + 900, cy - 70), (x0 + 930, cy - 150), (x0 + 1180, cy - 150), (x0 + 1210, cy - 70)])
    for k in range(9):
        x = x0 + 700 + k * 120
        S.append(f'<path d="M{x} {cy - 70}V{cy + 70}" stroke="{ink}" stroke-width="1" opacity="0.6"/>')
    for k in range(3):
        ey = cy - 70 + k * 70
        poly([(x1, ey), (x1 + 120, ey - 10), (x1 + 170, ey + 20), (x1 + 120, ey + 50), (x1, ey + 40)], 2.0)
    S.append(f'<path d="M{x0 + 410} {cy - 280}V{cy - 380}M{x0 + 390} {cy - 340}H{x0 + 430}" stroke="{ink}" stroke-width="2"/>')
    # Greebles: pipe runs along the spine, vent banks underneath, the
    # sensor mast and dish on the command tower.
    for k in range(22):
        x = x0 + 640 + k * 62
        h = 14 + (k * 37 % 5) * 6
        S.append(f'<rect x="{x}" y="{cy - 70 - h}" width="40" height="{h}" fill="none" stroke="{ink}" stroke-width="1.2"/>')
    S.append(f'<path d="M{x0 + 620} {cy - 50}H{x1 - 520}M{x0 + 620} {cy - 40}H{x1 - 520}" stroke="{ink}" stroke-width="1" opacity="0.7"/>')
    for k in range(12):
        x = x0 + 300 + k * 140
        S.append(f'<path d="M{x} {cy + 60}l20 34h70l20 -34" fill="none" stroke="{ink}" stroke-width="1.3"/>')
    S.append(f'<path d="M{x0 + 470} {cy - 280}l60 -50M{x0 + 505} {cy - 330}a40 16 -30 0 1 60 -30" fill="none" stroke="{ink}" stroke-width="1.6"/>')
    S.append(f'<path d="M{x0} {cy - 40}L{x0 - 60} {cy - 10}L{x0 - 60} {cy + 10}L{x0} {cy + 30}" fill="none" stroke="{ink}" stroke-width="2"/>')
    for k in range(14):
        S.append(f'<rect x="{x0 + 160 + k * 26}" y="{cy - 20}" width="12" height="8" fill="{acc}" opacity="0.8"/>')
    S.append(f'<path d="M{x0 - 80} {cy + 5}H{x1 + 260}" stroke="{acc}" stroke-width="1.2" stroke-dasharray="40 10 6 10"/>')
    body.append("".join(S))

    # Dimensions.
    def dim_h(xa, xb, y, label):
        arrow = 14
        body.append(f'<path d="M{xa} {y}H{xb}M{xa} {y - 18}V{y + 18}M{xb} {y - 18}V{y + 18}'
                    f'M{xa} {y}l{arrow} -6v12zM{xb} {y}l{-arrow} -6v12z" stroke="{ink}" stroke-width="1.4" fill="{ink}"/>')
        body.append(text((xa + xb) / 2, y - 14, label, 22, ink, anchor="middle", spacing=3))
    dim_h(x0, x1 + 170, cy + 260, "243.84 M  (800 FT)")
    dim_h(x0 + 260, x0 + 600, cy - 420, "COMMAND MODULE  42.6 M")
    body.append(f'<path d="M{x0} {cy + 60}V{cy + 280}M{x1 + 170} {cy + 20}V{cy + 280}" stroke="{ink}" stroke-width="0.8" stroke-dasharray="6 6"/>')

    # Callouts.
    def callout(px, py, tx, ty, label, sub):
        body.append(f'<circle cx="{px}" cy="{py}" r="7" fill="none" stroke="{acc}" stroke-width="2"/>'
                    f'<path d="M{px} {py}L{tx} {ty}H{tx + (300 if tx > px else -300)}" stroke="{acc}" stroke-width="1.4" fill="none"/>')
        anchor = "start" if tx > px else "end"
        body.append(text(tx + (12 if tx > px else -12), ty - 12, label, 22, ink, anchor=anchor, spacing=3))
        body.append(text(tx + (12 if tx > px else -12), ty + 24, sub, 16, dim, anchor=anchor, spacing=2))
    callout(x0 + 430, cy - 240, x0 + 700, cy - 560, "BRIDGE / MU-TH-UR 6000", "INTERFACE 2037")
    callout(x0 + 1050, cy - 120, x0 + 1300, cy - 400, "HYPERSLEEP VAULT", "7 CHAMBERS")
    callout(x1 - 330, cy - 100, x1 - 120, cy - 330, "REFINERY CLAMPS", "TOW: 20 000 000 T ORE")
    callout(x1 + 140, cy + 60, x1 - 520, cy + 430, "ENGINES  ×3", "SPECIAL ORDER 937")

    # Title block.
    bx, by, bw, bh = W - 1060, H - 380, 980, 300
    body.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{p["bg"]}" stroke="{ink}" stroke-width="2"/>'
                f'<path d="M{bx} {by + 90}H{bx + bw}M{bx} {by + 160}H{bx + bw}M{bx} {by + 230}H{bx + bw}'
                f'M{bx + 560} {by + 90}V{by + bh}" stroke="{ink}" stroke-width="1.2"/>')
    body.append(text(bx + 30, by + 60, "USCSS NOSTROMO", 44, ink, weight="bold", spacing=8))
    body.append(text(bx + 30, by + 135, "M-CLASS STARFREIGHTER", 22, ink, spacing=3))
    body.append(text(bx + 30, by + 205, "REG. 180924609", 22, ink, spacing=3))
    body.append(text(bx + 30, by + 275, "WEYLAND-YUTANI CORP", 22, ink, spacing=3))
    body.append(text(bx + 590, by + 135, "DWG  MU-TH-UR/6000", 20, dim, spacing=2))
    body.append(text(bx + 590, by + 205, "SCALE  1:400", 20, dim, spacing=2))
    body.append(text(bx + 590, by + 275, "SHEET  1 / 1", 20, acc, spacing=2))
    body.append(text(140, 150, "SIDE ELEVATION", 30, ink, spacing=10))
    body.append(text(140, 186, "PORT  //  NOT FOR CONSTRUCTION", 18, dim, spacing=4))
    vdefs, vrect = vignette(0.18 if pal == "nostromo" else 0.5)
    return svg("".join(body) + vrect, p["bg"], vdefs)


# --- Generative ---------------------------------------------------------------

def flow(pal, seed):
    """Streamlines through a noise field."""
    p = PAL[pal]
    noise = Noise(seed)
    rnd = random.Random(seed)
    paths = []
    for _ in range(2600):
        x, y = rnd.uniform(-100, W + 100), rnd.uniform(-100, H + 100)
        pts = [(x, y)]
        for _ in range(rnd.randint(30, 110)):
            a = noise.fbm(x / 700.0, y / 700.0, 3) * math.pi * 4
            x += math.cos(a) * 9
            y += math.sin(a) * 9
            pts.append((x, y))
        color = rnd.choice(p["hues"])
        d = "M" + "L".join(f"{px:.1f} {py:.1f}" for px, py in pts)
        paths.append(f'<path d="{d}" stroke="{color}" stroke-width="{rnd.uniform(0.6, 1.8):.2f}" '
                     f'opacity="{rnd.uniform(0.15, 0.6):.2f}" fill="none" stroke-linecap="round"/>')
    vdefs, vrect = vignette(0.6)
    return svg("".join(paths) + vrect, p["bg"], vdefs)


def ridges(pal, seed):
    """Stacked ridgelines, each hiding the ones behind it."""
    p = PAL[pal]
    noise = Noise(seed)
    hues = p["hues"]
    out = []
    count, top, bottom = 56, H * 0.18, H * 0.9
    for k in range(count):
        base = top + (bottom - top) * k / (count - 1)
        pts = []
        for x in range(-20, W + 21, 10):
            centre = math.exp(-((x - W / 2) / (W * 0.18)) ** 2)
            v = noise.fbm(x / 160.0, k * 0.37, 4)
            pts.append((x, base - centre * (v ** 2) * 260 - v * 18))
        t = k / (count - 1)
        color = hues[min(len(hues) - 1, int(t * len(hues)))]
        d = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
        out.append(f'<path d="{d}L{W + 20} {H + 20}L-20 {H + 20}Z" fill="{p["bg"]}"/>'
                   f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2" opacity="0.85"/>')
    defs = glow("rg", 2.5)
    vdefs, vrect = vignette(0.6)
    return svg(f'<g filter="url(#rg)">{"".join(out)}</g>' + vrect, p["bg"], defs + vdefs)


def contours(pal, seed):
    """Glowing contour lines, like a light-cycle arena seen from above."""
    p = PAL[pal]
    noise = Noise(seed)
    step = 12
    cols, rows = W // step + 2, H // step + 2
    field = [[noise.fbm(i * step / 650.0, j * step / 650.0, 5) for i in range(cols)] for j in range(rows)]
    levels = [0.28 + k * 0.03 for k in range(16)]
    paths = contour_paths(field, cols, rows, step, levels)
    hues = p["hues"]
    out = []
    for k, level in enumerate(levels):
        color = p["accent"] if k == 11 else hues[k * (len(hues) - 1) // len(levels)]
        out.append(f'<path d="{paths[level]}" fill="none" stroke="{color}" '
                   f'stroke-width="{2.2 if k == 11 else 1.3}" opacity="{0.95 if k == 11 else 0.55}"/>')
    defs = glow("cg", 3)
    vdefs, vrect = vignette(0.65)
    return svg(f'<g filter="url(#cg)">{"".join(out)}</g>' + vrect, p["bg"], defs + vdefs)


DESIGNS = {
    "corpo-carbon": lambda: corpo("corpo", 11),
    "corpo-carbon-light": lambda: corpo("corpoLight", 11),
    "crt-phosphor": lambda: crt("muthur", 5),
    "crt-amber": lambda: crt("amber", 6),
    "nostromo-schematic-bone": lambda: schematic("nostromo", 1),
    "nostromo-schematic-dark": lambda: schematic("nostromoDark", 1),
    "flow-neo": lambda: flow("neo", 23),
    "ridges-hackers": lambda: ridges("hackers", 42),
    "contours-tron": lambda: contours("tron", 7),
}


def main(argv):
    global W, H
    out_dir = os.path.expanduser("~/Pictures/Wallpapers")
    only = []
    args = iter(argv)
    for a in args:
        if a == "--size":
            W, H = (int(n) for n in next(args).lower().split("x"))
        elif a == "--only":
            only = list(args)
        else:
            out_dir = os.path.expanduser(a)
    os.makedirs(out_dir, exist_ok=True)
    for name, draw in DESIGNS.items():
        if only and name not in only:
            continue
        target = os.path.join(out_dir, f"muthur-{name}.png")
        with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
            f.write(draw())
            path = f.name
        subprocess.run(["rsvg-convert", "-o", target, path], check=True)
        os.unlink(path)
        print(target)


if __name__ == "__main__":
    main(sys.argv[1:])
