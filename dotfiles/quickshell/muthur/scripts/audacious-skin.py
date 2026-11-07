#!/usr/bin/env python3
"""Draws the shell's look as a classic (Winamp 2) skin for Audacious.

Usage: audacious-skin.py THEME_JSON [OUT_DIR]

THEME_JSON is {"bg", "fg", "dim", "focus"} as "#rrggbb". OUT_DIR defaults
to Audacious's user skin directory ($XDG_DATA_HOME/audacious/Skins/muthur),
where it shows up in Settings > Appearance as "muthur".

Every sprite is drawn here, pixel by pixel, in the shell's style: flat
background, 1px lines in the dim color, labels in a 4x5 pixel font, and
the filled "chip" for whatever is on. The sprite sheets' layouts follow
Audacious's skins plugin (src/skins/*.cc), which reads the same files as
Winamp 2. Written as PNGs without any imaging library. A file is only
rewritten when its content changes; Audacious reads the skin when it
starts or when it's picked again.
"""

import json
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------- colors


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


CLEAR = (0, 0, 0, 0)

# ------------------------------------------------------------ pixel font

# 4x5 glyphs, drawn in 5x6 cells like Winamp's text.bmp.
FONT = {
    "A": [".##.", "#..#", "####", "#..#", "#..#"],
    "B": ["###.", "#..#", "###.", "#..#", "###."],
    "C": [".###", "#...", "#...", "#...", ".###"],
    "D": ["###.", "#..#", "#..#", "#..#", "###."],
    "E": ["####", "#...", "###.", "#...", "####"],
    "F": ["####", "#...", "###.", "#...", "#..."],
    "G": [".###", "#...", "#.##", "#..#", ".###"],
    "H": ["#..#", "#..#", "####", "#..#", "#..#"],
    "I": ["###.", ".#..", ".#..", ".#..", "###."],
    "J": ["..##", "...#", "...#", "#..#", ".##."],
    "K": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
    "L": ["#...", "#...", "#...", "#...", "####"],
    "M": ["#..#", "####", "####", "#..#", "#..#"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "P": ["###.", "#..#", "###.", "#...", "#..."],
    "Q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#"],
    "S": [".###", "#...", ".##.", "...#", "###."],
    "T": ["###.", ".#..", ".#..", ".#..", ".#.."],
    "U": ["#..#", "#..#", "#..#", "#..#", ".##."],
    "V": ["#..#", "#..#", "#..#", ".##.", ".##."],
    "W": ["#..#", "#..#", "####", "####", "#..#"],
    "X": ["#..#", "#..#", ".##.", "#..#", "#..#"],
    "Y": ["#.#.", "#.#.", ".#..", ".#..", ".#.."],
    "Z": ["####", "...#", ".##.", "#...", "####"],
    "0": [".##.", "#.##", "#..#", "##.#", ".##."],
    "1": [".#..", "##..", ".#..", ".#..", "###."],
    "2": ["###.", "...#", ".##.", "#...", "####"],
    "3": ["###.", "...#", ".##.", "...#", "###."],
    "4": ["#..#", "#..#", "####", "...#", "...#"],
    "5": ["####", "#...", "###.", "...#", "###."],
    "6": [".##.", "#...", "###.", "#..#", ".##."],
    "7": ["####", "...#", "..#.", ".#..", ".#.."],
    "8": [".##.", "#..#", ".##.", "#..#", ".##."],
    "9": [".##.", "#..#", ".###", "...#", ".##."],
    '"': ["#.#.", "#.#.", "....", "....", "...."],
    "@": [".##.", "#..#", "#.##", "#...", ".##."],
    " ": ["....", "....", "....", "....", "...."],
    ":": ["....", ".#..", "....", ".#..", "...."],
    "(": ["..#.", ".#..", ".#..", ".#..", "..#."],
    ")": [".#..", "..#.", "..#.", "..#.", ".#.."],
    "-": ["....", "....", "###.", "....", "...."],
    "'": [".#..", ".#..", "....", "....", "...."],
    "!": [".#..", ".#..", ".#..", "....", ".#.."],
    "_": ["....", "....", "....", "....", "####"],
    "+": ["....", ".#..", "###.", ".#..", "...."],
    "\\": ["#...", ".#..", ".#..", "..#.", "...#"],
    "/": ["...#", "..#.", ".#..", ".#..", "#..."],
    "[": [".##.", ".#..", ".#..", ".#..", ".##."],
    "]": [".##.", "..#.", "..#.", "..#.", ".##."],
    "^": [".#..", "#.#.", "....", "....", "...."],
    "&": [".#..", "#.#.", ".#..", "#.#.", ".#.#"],
    "%": ["#..#", "..#.", ".#..", "#...", "#..#"],
    ".": ["....", "....", "....", "....", ".#.."],
    "=": ["....", "###.", "....", "###.", "...."],
    "$": [".###", "##..", ".##.", "..##", "###."],
    "#": ["#.#.", "####", "#.#.", "####", "#.#."],
    "?": ["###.", "...#", ".##.", "....", ".#.."],
    "*": ["....", "#.#.", ".#..", "#.#.", "...."],
    "…": ["....", "....", "....", "....", "#.#."],
}

# Where Audacious looks each character up in text.bmp (textbox.cc).
TEXT_CELLS = (
    [(c, i, 0) for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")]
    + [('"', 26, 0), ("@", 27, 0), (" ", 29, 0)]
    + [(c, i, 1) for i, c in enumerate("0123456789")]
    + [(c, 10 + i, 1) for i, c in enumerate("….:()-'!_+\\/[]^&%.=$#")]
    + [("A", 0, 2), ("O", 1, 2), ("A", 2, 2), ("?", 3, 2), ("*", 4, 2)]
)


def text_width(s):
    return len(s) * 5 - 1

# ------------------------------------------------------------- the canvas


class Img:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [fill] * (w * h)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def fill(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, c)

    def hline(self, x, y, w, c):
        self.fill(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.fill(x, y, 1, h, c)

    def rect(self, x, y, w, h, c):
        self.hline(x, y, w, c)
        self.hline(x, y + h - 1, w, c)
        self.vline(x, y, h, c)
        self.vline(x + w - 1, y, h, c)

    def pattern(self, x, y, rows, c):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "#":
                    self.set(x + i, y + j, c)

    def text(self, x, y, s, c):
        for k, ch in enumerate(s.upper()):
            self.pattern(x + k * 5, y, FONT.get(ch, FONT["?"]), c)

    def text_center(self, x, y, w, s, c):
        self.text(x + (w - text_width(s) + 1) // 2, y, s, c)

    def png(self):
        raw = b"".join(
            b"\0" + bytes(v for p in self.px[y * self.w:(y + 1) * self.w] for v in p)
            for y in range(self.h))

        def chunk(kind, data):
            body = kind + data
            return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

        return (b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9))
                + chunk(b"IEND", b""))

# ---------------------------------------------------------------- glyphs


def tri_right(img, x, y, h, c):
    for r in range(h):
        img.hline(x, y + r, min(r, h - 1 - r) + 1, c)


def tri_left(img, x, y, h, c):
    half = (h + 1) // 2
    for r in range(h):
        w = min(r, h - 1 - r) + 1
        img.hline(x + half - w, y + r, w, c)


def tri_up(img, x, y, w, c):
    for r in range((w + 1) // 2):
        img.hline(x + (w - 1) // 2 - r, y + r, 2 * r + 1, c)


def transport(img, x, y, kind, c, h):
    """The playback glyphs, h (odd) pixels tall, from (x, y)."""
    t = (h + 1) // 2
    if kind == "prev":
        img.vline(x, y, h, c)
        tri_left(img, x + 1, y, h, c)
        tri_left(img, x + 1 + t, y, h, c)
    elif kind == "next":
        tri_right(img, x, y, h, c)
        tri_right(img, x + t, y, h, c)
        img.vline(x + 2 * t, y, h, c)
    elif kind == "play":
        tri_right(img, x, y, h, c)
    elif kind == "pause":
        bw = 2 if h > 5 else 1
        img.fill(x, y, bw, h, c)
        img.fill(x + bw + 2, y, bw, h, c)
    elif kind == "stop":
        s = h - 2
        img.fill(x, y + 1, s, s, c)
    elif kind == "eject":
        tri_up(img, x, y, h, c)
        img.hline(x, y + (h + 1) // 2 + 1, h, c)
        if h > 5:
            img.hline(x, y + (h + 1) // 2 + 2, h, c)


def transport_width(kind, h):
    t = (h + 1) // 2
    return {"prev": 1 + 2 * t, "next": 1 + 2 * t, "play": t,
            "pause": (2 if h > 5 else 1) * 2 + 2, "stop": h - 2, "eject": h}[kind]


TITLE_GLYPHS = {
    "menu": ["#####", ".....", "#####", ".....", "#####"],
    "min": [".....", ".....", ".....", ".....", "#####"],
    "close": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "shade": [".....", "..#..", ".#.#.", "#...#", "....."],
    "unshade": [".....", "#...#", ".#.#.", "..#..", "....."],
}


class Look:
    def __init__(self, theme):
        self.bg = rgb(theme["bg"])
        self.fg = rgb(theme["fg"])
        self.dim = rgb(theme["dim"])
        self.focus = rgb(theme["focus"])
        self.muted = mix(self.fg, self.dim, 0.5)
        self.ghost = mix(self.bg, self.dim, 0.3)
        self.sel = mix(self.bg, self.dim, 0.35)

    def title_button(self, img, x, y, kind, pressed):
        """A 9x9 window button: the bare glyph, or a filled chip pressed."""
        if pressed:
            img.fill(x, y, 9, 9, self.fg)
        img.pattern(x + 2, y + 2, TITLE_GLYPHS[kind], self.bg if pressed else self.fg)

    def chip(self, img, x, y, w, h, label, on=False, pressed=False):
        """A labeled button: outlined when off, filled when on, like the
        shell's tabs; pressed fills it with the dim (off) or focus (on)."""
        if on or pressed:
            img.fill(x, y, w, h, (self.focus if on else self.dim) if pressed else self.fg)
            ink = self.bg if on else self.fg
        else:
            img.fill(x, y, w, h, self.bg)
            img.rect(x, y, w, h, self.dim)
            ink = self.fg
        img.text_center(x, y + (h - 5) // 2, w, label, ink)

    def knob_marker(self, img, x, y, w, h, track, pressed, filled=False):
        """A horizontal slider's knob: a 2px bar across the track. Audacious
        draws knobs opaque (no alpha), so the box around the bar repeats
        the track under it: its outline from row `track` (5 rows tall),
        filled left of the bar when `filled`, since the fill ends there."""
        img.fill(x, y, w, h, self.bg)
        img.hline(x, y + track, w, self.dim)
        img.hline(x, y + track + 4, w, self.dim)
        cx = x + w // 2 - 1
        if filled:
            img.fill(x, y + track + 1, cx - 1 - x, 3, self.fg)
        img.fill(cx, y, 2, h, self.focus if pressed else self.fg)

# --------------------------------------------------------------- sprites


def main_bmp(L):
    m = Img(275, 116, L.bg)
    m.rect(0, 0, 275, 116, L.dim)
    # The display: time, play status and the visualizer.
    m.rect(18, 22, 88, 40, L.dim)
    m.fill(72, 30, 2, 2, L.fg)
    m.fill(72, 35, 2, 2, L.fg)
    # Song title, then bitrate / sample rate / channels.
    m.rect(108, 23, 161, 14, L.dim)
    m.rect(108, 39, 161, 16, L.dim)
    m.text(128, 43, "KBPS", L.muted)
    m.text(168, 43, "KHZ", L.muted)
    # The about button: the name, stacked.
    m.rect(247, 84, 20, 23, L.dim)
    for i, s in enumerate(("MU", "TH", "UR")):
        m.text(252, 87 + 7 * i, s, L.fg)
    return m


def titlebar_bmp(L):
    t = Img(344, 87, L.bg)
    for col, kind in enumerate(("menu", "min", "close")):
        L.title_button(t, 9 * col, 0, kind, False)
        L.title_button(t, 9 * col, 9, kind, True)
    for row, kind in ((18, "shade"), (27, "unshade")):
        L.title_button(t, 0, row, kind, False)
        L.title_button(t, 9, row, kind, True)
    # Shaded mode's seek bar track (17x7) and its knobs (3x7).
    t.hline(0, 39, 17, L.dim)
    t.vline(0, 37, 5, L.dim)
    t.vline(16, 37, 5, L.dim)
    for x in (17, 20, 23):
        t.fill(x, 36, 3, 7, L.fg)

    for y, focused in ((0, True), (15, False)):
        ink = L.fg if focused else L.dim
        t.hline(27, y, 275, L.dim)
        t.vline(27, y, 14, L.dim)
        t.vline(27 + 274, y, 14, L.dim)
        t.hline(27, y + 13, 275, L.dim)
        t.text(27 + 20, y + 4, "MU/TH/UR 6000", ink)
        t.text(27 + 238 - text_width("AUDIO"), y + 4, "AUDIO", L.muted if focused else L.dim)

    for y, focused in ((29, True), (42, False)):
        ink = L.fg if focused else L.dim
        t.rect(27, y, 275, 14 if y == 29 else 13, L.dim)
        t.text(27 + 20, y + 4, "MU/TH/UR", ink)
        t.fill(27 + 145, y + 5, 1, 1, ink)
        t.fill(27 + 145, y + 8, 1, 1, ink)
        for kind, x in (("prev", 169), ("play", 177), ("pause", 187),
                        ("stop", 197), ("next", 206), ("eject", 216)):
            w = {"prev": 8, "play": 10, "pause": 10, "stop": 9, "next": 8, "eject": 9}[kind]
            gx = x + (w - transport_width(kind, 5)) // 2
            transport(t, 27 + gx, y + 5, kind, ink, 5)
    return t


def cbuttons_bmp(L):
    c = Img(136, 36, L.bg)
    buttons = (("prev", 0, 23, 18), ("play", 23, 23, 18), ("pause", 46, 23, 18),
               ("stop", 69, 23, 18), ("next", 92, 22, 18), ("eject", 114, 22, 16))
    for kind, x, w, h in buttons:
        for y, pressed in ((0, False), (h, True)):
            bw = w - 1  # a 1px gap between neighbours
            if pressed:
                c.fill(x, y, bw, h, L.fg)
            else:
                c.rect(x, y, bw, h, L.dim)
            gh = 7
            gw = transport_width(kind, gh)
            transport(c, x + (bw - gw) // 2, y + (h - gh) // 2, kind,
                      L.bg if pressed else L.fg, gh)
    return c


def shufrep_bmp(L):
    s = Img(92, 85, L.bg)
    for row, (on, pressed) in enumerate(((False, False), (False, True),
                                         (True, False), (True, True))):
        L.chip(s, 0, 15 * row, 27, 15, "REP", on, pressed)
        L.chip(s, 28, 15 * row, 45, 15, "SHUFFLE", on, pressed)
    for y, on in ((61, False), (73, True)):
        L.chip(s, 0, y, 22, 12, "EQ", on, False)
        L.chip(s, 23, y, 22, 12, "PL", on, False)
        L.chip(s, 46, y, 22, 12, "EQ", on, True)
        L.chip(s, 69, y, 22, 12, "PL", on, True)
    return s


def numbers_bmp(L):
    # Seven thin segments per digit, unlit ones faintly drawn like an LCD.
    segs = {
        "a": (1, 0, 5, 1), "b": (6, 1, 1, 4), "c": (6, 6, 1, 4), "d": (1, 10, 5, 1),
        "e": (0, 6, 1, 4), "f": (0, 1, 1, 4), "g": (1, 5, 5, 1),
    }
    digits = ["abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc",
              "abc", "abcdefg", "abcdfg", "", "g"]
    n = Img(108, 13, L.bg)
    for i, lit in enumerate(digits):
        for name, (x, y, w, h) in segs.items():
            n.fill(9 * i + 1 + x, 1 + y, w, h, L.fg if name in lit else L.ghost)
    return n


def text_bmp(L):
    t = Img(155, 18, L.bg)
    for ch, cx, cy in TEXT_CELLS:
        t.pattern(cx * 5, cy * 6, FONT[ch], L.fg)
    return t


def playpaus_bmp(L):
    p = Img(42, 9, L.bg)
    tri_right(p, 2, 1, 7, L.fg)                 # play (1,0) 8x9
    p.fill(11, 1, 2, 7, L.fg)                   # pause (9,0) 9x9
    p.fill(15, 1, 2, 7, L.fg)
    p.fill(20, 2, 5, 5, L.fg)                   # stop (18,0) 9x9
    p.fill(36, 1, 2, 7, L.focus)                # "playing" light (36,0) 3x9
    return p


def monoster_bmp(L):
    m = Img(58, 24, L.bg)
    for y, ink in ((0, L.fg), (12, L.ghost)):
        m.text(0, y + 4, "STEREO", ink)
        m.text_center(29, y + 4, 27, "MONO", ink)
    return m


def slider_frames(L, img, x0, w, balance):
    for i in range(28):
        y = 15 * i
        img.rect(x0, y + 4, w, 5, L.dim)
        if balance:
            img.vline(x0 + w // 2, y + 2, 9, L.dim)
        else:
            img.fill(x0 + 1, y + 5, round(6 + i * 51 / 27), 3, L.fg)


def volume_bmp(L, balance=False):
    v = Img(68, 433, L.bg)
    slider_frames(L, v, *((9, 38) if balance else (0, 68)), balance)
    # Knobs, 14x11, drawn 1px below the frame's top: pressed, normal.
    L.knob_marker(v, 0, 422, 14, 11, 3, True, not balance)
    L.knob_marker(v, 15, 422, 14, 11, 3, False, not balance)
    return v


def posbar_bmp(L):
    p = Img(307, 10, L.bg)
    p.rect(0, 2, 248, 5, L.dim)
    for k in range(1, 10):
        p.vline(round(k * 247 / 10), 0, 2, L.dim)
        p.vline(round(k * 247 / 10), 7, 2, L.dim)
    L.knob_marker(p, 248, 0, 29, 10, 2, False)
    L.knob_marker(p, 278, 0, 29, 10, 2, True)
    return p


def pledit_bmp(L):
    p = Img(280, 186, L.bg)
    # Title bar, focused (y 0) and not (y 21): left corner, title,
    # tile and right corner (with the shade and close buttons).
    for y, focused in ((0, True), (21, False)):
        ink = L.fg if focused else L.dim
        for x, w in ((0, 25), (26, 100), (127, 25), (153, 25)):
            p.hline(x, y, w, L.dim)
            p.hline(x, y + 19, w, L.dim)
        p.vline(0, y, 20, L.dim)
        p.vline(153 + 24, y, 20, L.dim)
        p.text_center(26, y + 8, 100, "PLAYLIST", ink)
        L.title_button(p, 157, y + 3, "shade", False)
        L.title_button(p, 167, y + 3, "close", False)
    L.title_button(p, 52, 42, "close", True)
    L.title_button(p, 62, 42, "shade", True)
    # Sides: left (0,42) 12x29; right (32,42) 19x29, with the scroll bar's
    # track 4px in (36,42) and its knob (52,53) / pressed (61,53), 8x18.
    p.vline(0, 42, 29, L.dim)
    p.vline(32 + 18, 42, 29, L.dim)
    p.vline(36 + 3, 42, 29, L.ghost)
    p.vline(36 + 4, 42, 29, L.ghost)
    p.fill(52 + 1, 53, 6, 18, L.dim)
    p.fill(61 + 1, 53, 6, 18, L.fg)
    # Shaded: left (72,42), tile (72,57) 25x14; right 50x14, focused
    # (99,42) and not (99,57), with the unshade and close buttons.
    for x, y, w in ((72, 42, 25), (72, 57, 25), (99, 42, 50), (99, 57, 50)):
        p.hline(x, y, w, L.dim)
        p.hline(x, y + 13, w, L.dim)
    p.vline(72, 42, 14, L.dim)
    for y in (42, 57):
        p.vline(99 + 49, y, 14, L.dim)
        L.title_button(p, 99 + 29, y + 3, "unshade", False)
        L.title_button(p, 99 + 39, y + 3, "close", False)
    L.title_button(p, 150, 42, "unshade", True)
    # Bottom: left corner (0,72) 125x38 with ADD/REM/SEL/MISC, right corner
    # (126,72) 150x38 with the info, mini transport, time and LIST; the
    # visualizer slot (205,0) 75x38 and the tile (179,0) 25x38.
    for x, y, w in ((0, 72, 125), (126, 72, 150), (205, 0, 75), (179, 0, 25)):
        p.hline(x, y, w, L.dim)
        p.hline(x, y + 37, w, L.dim)
    p.vline(0, 72, 38, L.dim)
    p.vline(126 + 149, 72, 38, L.dim)
    for x, label in ((12, "ADD"), (40, "REM"), (68, "SEL"), (100, "MISC")):
        L.chip(p, x, 72 + 9, 25, 18, label)
    r = 126
    L.chip(p, r + 104, 72 + 9, 23, 18, "LIST")
    p.rect(r + 4, 72 + 7, 96, 12, L.dim)
    for kind, x, w in (("prev", 6, 8), ("play", 12, 10), ("pause", 22, 10),
                       ("stop", 32, 9), ("next", 41, 8), ("eject", 50, 9)):
        transport(p, r + x + (w - transport_width(kind, 5)) // 2, 72 + 23, kind, L.fg, 5)
    p.fill(r + 84, 72 + 24, 1, 1, L.fg)
    p.fill(r + 84, 72 + 27, 1, 1, L.fg)
    tri_up(p, r + 137, 72 + 4, 5, L.fg)
    for k in range(3):
        p.hline(r + 137 + k, 72 + 9 + k, 5 - 2 * k, L.fg)
    # The resize grip, a triangle of dots in the corner.
    for d in range(0, 7, 2):
        for e in range(0, 7 - d, 2):
            p.set(r + 147 - d, 72 + 35 - e, L.dim)
    return p


def pledit_txt(L):
    h = lambda c: "#%02X%02X%02X" % c[:3]
    return ("[Text]\nNormal=%s\nCurrent=%s\nNormalBG=%s\nSelectedBG=%s\n"
            "mbFG=%s\nmbBG=%s\n") % (h(L.fg), h(L.focus), h(L.bg), h(L.sel), h(L.fg), h(L.bg))


def eqmain_bmp(L):
    e = Img(275, 315, L.bg)
    # The window: title (overlaid from y 134/149), the sliders' labels.
    e.rect(0, 0, 275, 116, L.dim)
    e.text_center(21, 104, 14, "PRE", L.muted)
    for i, label in enumerate(("31", "63", "125", "250", "500",
                               "1K", "2K", "4K", "8K", "16K")):
        e.text_center(78 + 18 * i, 104, 14, label, L.muted)
    for y, label in ((39, "+12"), (66, "0"), (94, "-12")):
        e.text(72 - text_width(label), y, label, L.muted)
    # Close button (0,116) / pressed (0,125).
    L.title_button(e, 0, 116, "close", False)
    L.title_button(e, 0, 125, "close", True)
    # ON (25x12) and AUTO (33x12): off, on, off pressed, on pressed.
    for x, on, pressed in ((10, False, False), (69, True, False),
                           (128, False, True), (187, True, True)):
        L.chip(e, x, 119, 24, 12, "ON", on, pressed)
        L.chip(e, x + 25, 119, 32, 12, "AUTO", on, pressed)
    # Title bars, focused (0,134) and not (0,149).
    for y, focused in ((134, True), (149, False)):
        e.fill(0, y, 275, 14, L.bg)
        e.hline(0, y, 275, L.dim)
        e.vline(0, y, 14, L.dim)
        e.vline(274, y, 14, L.dim)
        e.hline(0, y + 13, 275, L.dim)
        e.text(20, y + 4, "EQUALIZER", L.fg if focused else L.dim)
        L.title_button(e, 254, y + 3, "shade", False)
        L.title_button(e, 264, y + 3, "close", False)
    # Slider frames, 14x63: frame i (0..27) is the level from -12 dB to
    # +12 dB, filled from 0 dB to the knob. Knob (0,164) / pressed (0,176).
    for i in range(28):
        x = 13 + 15 * (i % 14)
        y = 164 if i < 14 else 229
        e.fill(x, y, 14, 63, L.bg)
        e.fill(x + 6, y, 2, 63, L.ghost)
        mid = 30
        knob = round(50 * (27 - i) / 27) + 5
        top, bottom = min(mid, knob), max(mid, knob)
        e.fill(x + 5, y + top, 4, bottom - top + 1, L.fg)
    # Knobs are opaque: a fader cap, with the slider's center line
    # showing on the rows above and below it.
    for y, pressed in ((164, False), (176, True)):
        e.fill(0, y, 11, 11 if pressed else 12, L.bg)
        e.fill(5, y, 2, 11, L.ghost)
        if pressed:
            e.fill(0, y + 2, 11, 7, L.focus)
        else:
            e.fill(0, y + 2, 11, 7, L.bg)
            e.rect(0, y + 2, 11, 7, L.fg)
            e.hline(2, y + 5, 7, L.fg)
    # PRESETS (224,164) / pressed (224,176), 44x12.
    L.chip(e, 224, 164, 44, 12, "PRESETS")
    L.chip(e, 224, 176, 44, 12, "PRESETS", pressed=True)
    # The curve's box (0,294) 113x19, the preamp line (0,314) and the
    # curve's colors from top to bottom (115,294).
    e.rect(0, 294, 113, 19, L.dim)
    for x in range(2, 112, 2):
        e.set(x, 294 + 9, L.ghost)
    e.hline(0, 314, 113, L.dim)
    for i in range(19):
        t = abs(i - 9) / 9
        e.set(115, 294 + i, mix(L.fg, L.focus if i < 9 else L.muted, t))
    return e


def eq_ex_bmp(L):
    e = Img(275, 82, L.bg)
    for y, focused in ((0, True), (15, False)):
        ink = L.fg if focused else L.dim
        e.rect(0, y, 275, 14, L.dim)
        e.text(6, y + 4, "EQUALIZER", ink)
        # Volume (61,4) 97x8 and balance (164,4) 42x8 tracks.
        e.hline(61, y + 7, 97, L.dim)
        e.vline(61, y + 5, 5, L.dim)
        e.vline(157, y + 5, 5, L.dim)
        e.hline(164, y + 7, 42, L.dim)
        e.vline(164 + 21, y + 5, 5, L.dim)
        L.title_button(e, 254, y + 3, "unshade", False)
        L.title_button(e, 264, y + 3, "close", False)
    for x in (1, 4, 7, 11, 14, 17):
        e.fill(x, 30, 3, 7, L.fg)
    L.title_button(e, 1, 38, "shade", True)
    L.title_button(e, 11, 38, "close", False)
    L.title_button(e, 11, 47, "close", True)
    L.title_button(e, 1, 47, "unshade", True)
    return e


def viscolor_txt(L):
    # 0-1: background (1: its grid dots), 2-17: analyzer top to bottom,
    # 18-22: oscilloscope, 23: analyzer peaks.
    rows = [L.bg, L.ghost]
    for i in range(16):
        t = i / 15
        rows.append(mix(L.focus, L.fg, t * 2) if t < 0.5 else mix(L.fg, L.dim, (t - 0.5) * 2))
    for i in range(5):
        rows.append(mix(L.dim, L.fg, i / 4))
    rows.append(L.focus)
    return "".join("%d,%d,%d\n" % c[:3] for c in rows)


HINTS = "[skin]\nmainwinMenurowVisible=0\n"

# ------------------------------------------------------------------ main


def write(path, data):
    mode = "b" if isinstance(data, bytes) else ""
    try:
        with open(path, "r" + mode) as f:
            if f.read() == data:
                return
    except OSError:
        pass
    with open(path + ".tmp", "w" + mode) as f:
        f.write(data)
    os.replace(path + ".tmp", path)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    theme = json.loads(sys.argv[1])
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(data_home, "audacious", "Skins", "muthur")
    os.makedirs(out, exist_ok=True)

    L = Look(theme)
    images = {
        "main": main_bmp(L), "titlebar": titlebar_bmp(L), "cbuttons": cbuttons_bmp(L),
        "shufrep": shufrep_bmp(L), "nums_ex": numbers_bmp(L), "text": text_bmp(L),
        "playpaus": playpaus_bmp(L), "monoster": monoster_bmp(L),
        "volume": volume_bmp(L), "balance": volume_bmp(L, balance=True),
        "posbar": posbar_bmp(L), "pledit": pledit_bmp(L), "eqmain": eqmain_bmp(L),
        "eq_ex": eq_ex_bmp(L),
    }
    for name, img in images.items():
        write(os.path.join(out, name + ".png"), img.png())
    write(os.path.join(out, "pledit.txt"), pledit_txt(L))
    write(os.path.join(out, "viscolor.txt"), viscolor_txt(L))
    write(os.path.join(out, "skin.hints"), HINTS)


if __name__ == "__main__":
    main()
