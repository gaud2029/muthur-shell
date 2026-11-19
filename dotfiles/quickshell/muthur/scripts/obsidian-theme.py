#!/usr/bin/env python3
"""Installs the shell's generated Obsidian theme.

Usage: obsidian-theme.py CSS [VAULT_DIR...]

Writes CSS as the "Muthur" community theme (.obsidian/themes/Muthur/
theme.css and its manifest.json) in every vault Obsidian knows (its
obsidian.json, native or Flatpak), or in the VAULT_DIRs given. A vault
with no theme chosen gets Muthur picked in .obsidian/appearance.json; one
where another theme was picked keeps it, Muthur is just offered in
Settings > Appearance. Obsidian reloads the active theme's file live.
"""

import json
import os
import sys

NAME = "Muthur"
MANIFEST = {"name": NAME, "version": "1.0.0", "minAppVersion": "1.0.0",
            "author": "muthur-shell", "authorUrl": ""}


def vault_dirs():
    home = os.path.expanduser("~")
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
    for base in (os.path.join(config, "obsidian"),
                 os.path.join(home, ".var/app/md.obsidian.Obsidian/config/obsidian")):
        try:
            with open(os.path.join(base, "obsidian.json")) as f:
                vaults = json.load(f).get("vaults", {})
        except (OSError, ValueError):
            continue
        for vault in vaults.values():
            if isinstance(vault, dict) and vault.get("path"):
                yield vault["path"]


def write(path, text):
    # Only when it changed: Obsidian reloads the theme on every write.
    try:
        with open(path) as f:
            if f.read() == text:
                return
    except OSError:
        pass
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def install(vault, css):
    config = os.path.join(vault, ".obsidian")
    if not os.path.isdir(config):
        return
    theme = os.path.join(config, "themes", NAME)
    os.makedirs(theme, exist_ok=True)
    write(os.path.join(theme, "manifest.json"), json.dumps(MANIFEST, indent=2) + "\n")
    write(os.path.join(theme, "theme.css"), css)

    appearance = os.path.join(config, "appearance.json")
    try:
        with open(appearance) as f:
            settings = json.load(f)
    except FileNotFoundError:
        settings = {}
    except (OSError, ValueError):
        return  # Unreadable: leave the user's file alone.
    if not isinstance(settings, dict) or settings.get("cssTheme"):
        return
    settings["cssTheme"] = NAME
    write(appearance, json.dumps(settings, indent=2) + "\n")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    css = sys.argv[1]
    for vault in sys.argv[2:] or vault_dirs():
        install(vault, css)


if __name__ == "__main__":
    main()
