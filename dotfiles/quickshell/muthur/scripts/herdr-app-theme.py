#!/usr/bin/env python3
"""Installs the shell's generated look for the Herdr desktop app.

Usage: herdr-app-theme.py THEME_JSON FONT

In herdr-app's home ($HERDR_APP_HOME, else ~/.config/herdr-app; nothing
happens if it doesn't exist), writes:

- themes/muthur.json: THEME_JSON, the palette in herdr-app's theme format.
- layouts/muthur.json: Herdr's own shipped main layout, re-read every time
  so it keeps up with app updates, with that theme, FONT for terminals and
  panels, square pane frames and labwc's window frame.
- layouts/muthur-6000.json and mods/muthur-*/: the MU/TH/UR 6000 layout
  from dotfiles/herdr-app in this repo, with FONT filled in, and the mods it
  draws with. The mods are copied, not symlinked: herdr-app neither
  hot-reloads nor loads assets through a symlink that leads out of its home.

A file is only rewritten when its content changes; herdr-app picks changes
up live, open windows included.
"""

import json
import os
import sys

# dotfiles/quickshell/muthur/scripts/ -> dotfiles/herdr-app/
SOURCE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "herdr-app")


def write(path, data):
    mode = "b" if isinstance(data, bytes) else ""
    try:
        with open(path, "r" + mode) as f:
            if f.read() == data:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Written in place: herdr-app's file watch doesn't survive a file
    # renamed over the old one (it would stop hot-reloading that file),
    # and a half-written file it does catch only keeps the last good one.
    with open(path, "w" + mode) as f:
        f.write(data)


def square(node):
    pane = node.get("content", {}).get("pane")
    if pane is not None:
        pane["radius"] = 0
    for child in node.get("children", []):
        square(child)


def plain_layout(home, font):
    # main.json is written by herdr-app on every start; without it (not
    # started yet) there's nothing to build the layout from.
    try:
        with open(os.path.join(home, "layouts", "main.json")) as f:
            layout = json.load(f)
    except (OSError, ValueError):
        return
    layout.update(theme="muthur", font=font, ui_font=font)
    # main draws its own title bar ("titlebar": "none"), which also opts
    # out of labwc's frame; without it the window gets labwc's title bar
    # and border like every other app (herdr then hides its own buttons).
    layout.pop("titlebar", None)
    square(layout)
    write(os.path.join(home, "layouts", "muthur.json"), json.dumps(layout, indent=2) + "\n")


def own_layouts(home, font):
    mods = os.path.join(SOURCE, "mods")
    for name in sorted(os.listdir(mods)) if os.path.isdir(mods) else []:
        target = os.path.join(home, "mods", name)
        if os.path.islink(target):
            os.remove(target)
        for root, _dirs, files in os.walk(os.path.join(mods, name)):
            for file in files:
                src = os.path.join(root, file)
                with open(src, "rb") as f:
                    write(os.path.join(target, os.path.relpath(src, os.path.join(mods, name))), f.read())
    layouts = os.path.join(SOURCE, "layouts")
    for file in sorted(os.listdir(layouts)) if os.path.isdir(layouts) else []:
        with open(os.path.join(layouts, file)) as f:
            layout = json.load(f)
        layout.update(font=font, ui_font=font)
        write(os.path.join(home, "layouts", file), json.dumps(layout, indent=2) + "\n")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    theme, font = sys.argv[1], sys.argv[2]
    home = os.environ.get("HERDR_APP_HOME") or os.path.expanduser("~/.config/herdr-app")
    if not os.path.isdir(home):
        return
    write(os.path.join(home, "themes", "muthur.json"), theme)
    plain_layout(home, font)
    # Mods first, so the layout never shows before what it draws with.
    own_layouts(home, font)


if __name__ == "__main__":
    main()
