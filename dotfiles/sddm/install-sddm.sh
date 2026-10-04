#!/usr/bin/env bash
# Installs the MU/TH/UR SDDM login theme (GitHub issue #24). Opt-in, not
# run by install.sh: it writes to /usr/share and /etc.
#
#   install-sddm.sh            install and make it SDDM's theme
#                              (next login screen shows it)
#   install-sddm.sh --preview  run the greeter for 30 s (PREVIEW_SECONDS)
#                              in test mode: logging in does nothing,
#                              no root needed
#   install-sddm.sh --revert   back to SDDM's default theme
#
# The theme reuses the shell's CrtScreen, VectorTerrain and TypedText,
# copied in next to its own files (Theme.qml stands in for the shell's,
# with a fixed palette). Copied, not symlinked: the greeter runs as the
# sddm user, who can't read /home.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO/dotfiles/sddm/muthur"
SHELL_QML="$REPO/dotfiles/quickshell/muthur"
SHARED=(CrtScreen.qml VectorTerrain.qml TypedText.qml)
DEST=/usr/share/sddm/themes/muthur
CONF=/etc/sddm.conf.d/muthur.conf

# Assembles the theme in $1.
build() {
  install -d "$1"
  install -m644 "$SRC"/* "$1"/
  for f in "${SHARED[@]}"; do
    install -m644 "$SHELL_QML/$f" "$1"/
  done
}

case "${1:-}" in
  --preview)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    build "$tmp/muthur"
    # Test mode covers every screen, can't log in, and has no way out:
    # it closes itself instead.
    echo "Preview: the greeter covers every screen for ${PREVIEW_SECONDS:=30} s, then closes."
    echo "Test mode never logs in; a password only shows the stars and VERIFYING."
    timeout "$PREVIEW_SECONDS" sddm-greeter-qt6 --test-mode --theme "$tmp/muthur" || true
    ;;
  --revert)
    [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
    rm -f "$CONF"
    echo "Removed $CONF; SDDM is back to its default theme."
    ;;
  "")
    [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
    rm -rf "$DEST"
    build "$DEST"
    install -d "$(dirname "$CONF")"
    printf '[Theme]\nCurrent=muthur\n' > "$CONF"
    echo "Installed $DEST and $CONF. The next login screen uses it."
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
