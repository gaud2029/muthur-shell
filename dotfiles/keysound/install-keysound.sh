#!/usr/bin/env bash
# Installs the typing sounds (GitHub issue #21): the keypress feed as a
# system service and the player, which the shell starts when a sound
# theme is picked in [SYS] > KEYBOARD. Opt-in, not run by install.sh: it
# needs root (a system service, and /usr/local).
#
#   install-keysound.sh            build the player, install and start the feed
#   install-keysound.sh --status   is it all there and running?
#   install-keysound.sh --revert   stop and remove everything
#
# Building needs gcc and PipeWire's headers (both on CachyOS by default).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYER=/usr/local/bin/muthur-keysound
FEED=/usr/local/lib/muthur/keysound-input.py
UNIT=/etc/systemd/system/muthur-keysound-input.service

status() {
  for f in "$PLAYER" "$FEED" "$UNIT"; do
    [[ -e $f ]] && echo "ok       $f" || echo "missing  $f"
  done
  echo "service  $(systemctl is-active muthur-keysound-input.service 2>/dev/null || true)"
}

case "${1:-}" in
  --status)
    status
    ;;
  --revert)
    [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
    systemctl disable --now muthur-keysound-input.service 2>/dev/null || true
    rm -f "$UNIT" "$FEED" "$PLAYER"
    rmdir --ignore-fail-on-non-empty "$(dirname "$FEED")" 2>/dev/null || true
    systemctl daemon-reload
    echo "Typing sounds removed."
    ;;
  "")
    [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
    command -v gcc >/dev/null || { echo "gcc is needed to build the player" >&2; exit 1; }
    pkg-config --exists libpipewire-0.3 || { echo "PipeWire's headers are needed (pipewire)" >&2; exit 1; }
    # shellcheck disable=SC2046
    gcc -O2 -Wall -o "$PLAYER" "$SRC/muthur-keysound.c" \
      $(pkg-config --cflags --libs libpipewire-0.3) -lm
    install -Dm755 "$SRC/keysound-input.py" "$FEED"
    install -Dm644 "$SRC/muthur-keysound-input.service" "$UNIT"
    systemctl daemon-reload
    systemctl enable --now muthur-keysound-input.service
    systemctl restart muthur-keysound-input.service
    echo "Installed. Pick a sound theme in [SYS] > KEYBOARD."
    status
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac
