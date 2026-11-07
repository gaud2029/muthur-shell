#!/usr/bin/env python3
"""Installs the shell's generated look for the Herdr desktop app.

Usage: herdr-app-theme.py THEME_JSON FONT

Writes THEME_JSON (the palette, in herdr-app's themes/<name>.json format)
to themes/muthur.json, and a "muthur" layout to layouts/muthur.json: Herdr's
own shipped main layout, re-read every time so it keeps up with app updates,
with that theme, FONT for terminals and panels, and square pane frames. Does
nothing if herdr-app isn't set up ($HERDR_APP_HOME, else ~/.config/herdr-app).
A file is only rewritten when its content changes; herdr-app picks changes up
live, open windows included. A pick in herdr-app's theme menu overrides a
layout's theme for good (in light or dark), so while that layout shows, the
muthur theme is picked again after every write.
"""

import json
import os
import shutil
import subprocess
import sys
import time

# herdr-app links itself into ~/.local/bin, which the session (and so the
# shell running this) may not have on its PATH.
HERDR = shutil.which("herdr-app", path=os.pathsep.join(
    [os.environ.get("PATH", ""), os.path.expanduser("~/.local/bin")]))


def write(path, text):
    try:
        with open(path) as f:
            if f.read() == text:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Replaced in one step so herdr-app never reads a half-written file.
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def square(node):
    pane = node.get("content", {}).get("pane")
    if pane is not None:
        pane["radius"] = 0
    for child in node.get("children", []):
        square(child)


def herdr(*args):
    try:
        return subprocess.run([HERDR, *args], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def pick_theme(names):
    # The theme menu's pick is stored per layout, one for light and one for
    # dark, and wins over the layout file. app.theme sets the half matching
    # the theme's lightness, so it's asked after herdr has re-read the file:
    # that takes it a moment, so once soon and once more to be sure (picking
    # the same theme again changes nothing).
    if not HERDR:
        return
    try:
        shown = json.loads(herdr("status")).get("layout")
    except ValueError:
        return
    if shown in names:
        for wait in (1.5, 2.5):
            time.sleep(wait)
            herdr("do", "app.theme", json.dumps({"name": "muthur"}))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    theme, font = sys.argv[1], sys.argv[2]
    home = os.environ.get("HERDR_APP_HOME") or os.path.expanduser("~/.config/herdr-app")
    if not os.path.isdir(home):
        return
    write(os.path.join(home, "themes", "muthur.json"), theme)

    # main.json is written by herdr-app on every start; without it (not
    # started yet) there's nothing to build the layout from.
    try:
        with open(os.path.join(home, "layouts", "main.json")) as f:
            layout = json.load(f)
    except (OSError, ValueError):
        return
    layout.update(theme="muthur", font=font, ui_font=font)
    square(layout)
    write(os.path.join(home, "layouts", "muthur.json"), json.dumps(layout, indent=2) + "\n")
    pick_theme(["muthur"])


if __name__ == "__main__":
    main()
