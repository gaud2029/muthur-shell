#!/usr/bin/env python3
"""Installs the shell's generated Firefox chrome colors.

Usage: firefox-theme.py CSS [PROFILE_DIR...]

Writes CSS to chrome/muthur.css in each profile Firefox actually starts
(the Default= of every install in installs.ini, else the profiles.ini
default), or in the PROFILE_DIRs given. userChrome.css is only touched to
@import that file, so rules written there by hand survive, and user.js
gets the pref that makes Firefox load userChrome.css at all. Firefox reads
both at startup only, so a running browser picks changes up on restart.
"""

import configparser
import os
import sys

PREF = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
IMPORT = '@import "muthur.css";'


def profile_dirs():
    home = os.path.expanduser("~")
    # Firefox 147+ uses the XDG location for new setups; older ones ~/.mozilla.
    for base in (os.path.join(home, ".config/mozilla/firefox"),
                 os.path.join(home, ".mozilla/firefox")):
        profiles = configparser.ConfigParser(interpolation=None)
        profiles.optionxform = str
        if not profiles.read(os.path.join(base, "profiles.ini")):
            continue
        installs = configparser.ConfigParser(interpolation=None)
        installs.read(os.path.join(base, "installs.ini"))
        paths = {s["Default"] for s in installs.values() if "Default" in s}
        if not paths:
            paths = {s["Path"] for s in profiles.values()
                     if s.get("Default") == "1" and "Path" in s}
        for section in profiles.values():
            path = section.get("Path")
            if path in paths:
                relative = section.get("IsRelative", "1") == "1"
                yield os.path.join(base, path) if relative else path
                paths.discard(path)
        # Install defaults missing from profiles.ini are relative paths.
        yield from (os.path.join(base, p) for p in paths)


def install(profile, css):
    if not os.path.isdir(profile):
        return
    chrome = os.path.join(profile, "chrome")
    os.makedirs(chrome, exist_ok=True)
    with open(os.path.join(chrome, "muthur.css"), "w") as f:
        f.write(css)

    # @import has to come before any other rule, so it goes first.
    user_chrome = os.path.join(chrome, "userChrome.css")
    existing = open(user_chrome).read() if os.path.exists(user_chrome) else ""
    if IMPORT not in existing:
        with open(user_chrome, "w") as f:
            f.write(IMPORT + "\n" + existing)

    user_js = os.path.join(profile, "user.js")
    existing = open(user_js).read() if os.path.exists(user_js) else ""
    if PREF not in existing:
        with open(user_js, "a") as f:
            f.write(("\n" if existing and not existing.endswith("\n") else "") + PREF + "\n")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    css = sys.argv[1]
    for profile in sys.argv[2:] or profile_dirs():
        install(profile, css)


if __name__ == "__main__":
    main()
