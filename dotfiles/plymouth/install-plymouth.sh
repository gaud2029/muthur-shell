#!/usr/bin/env bash
# Installs the MU/TH/UR Plymouth boot screen (GitHub issue #24). Opt-in,
# not run by install.sh: it needs root and rebuilds the initramfs.
#
#   install-plymouth.sh            install, make it the default theme and
#                                  rebuild the initramfs (next boot shows it)
#   install-plymouth.sh --files    install the theme files only
#   install-plymouth.sh --preview  install the files and play the boot and
#                                  shutdown screens in a window (x11
#                                  renderer, needs $DISPLAY), no reboot
#   install-plymouth.sh --revert   back to the cachyos theme, rebuilt
#
# The files are copied, not symlinked: the theme is read from the
# initramfs, where /home (encrypted) doesn't exist.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/muthur"
DEST=/usr/share/plymouth/themes/muthur
FALLBACK_THEME=cachyos

if [[ $EUID -ne 0 ]]; then
  if [[ ${1:-} == --preview ]]; then
    # Xwayland only lets the user's own clients in; let root's plymouthd
    # in for the preview (this also starts Xwayland, which forgets the
    # grant once it exits after its last client).
    command -v xhost >/dev/null || { echo "--preview needs xhost (xorg-xhost)" >&2; exit 1; }
    xhost +SI:localuser:root >/dev/null
    trap 'xhost -SI:localuser:root >/dev/null' EXIT
    sudo DISPLAY="${DISPLAY:-}" "$0" "$@"
    exit
  fi
  exec sudo "$0" "$@"
fi

install_files() {
  install -d "$DEST"
  install -m644 "$SRC"/muthur.plymouth "$SRC"/muthur.script "$SRC"/*.png "$DEST"/
  echo "Installed $DEST"
}

ply() { plymouth "$@" || true; }

# One run of plymouthd in a window, fed a few statuses and prompts.
# plymouth.ignore-udev keeps it off the DRM devices (the compositor owns
# them) so it falls back to its renderer list, x11 first.
preview_mode() {
  local mode=$1
  plymouthd --no-daemon --no-boot-log --mode="$mode" \
    --debug --debug-file="/tmp/muthur-plymouth-$mode.log" \
    --kernel-command-line="quiet splash plymouth.splash=muthur plymouth.ignore-udev" &
  local pid=$!
  sleep 1
  ply show-splash
  echo "[$mode] header and power-on"; sleep 4
  for unit in "Journal Service" "Load Kernel Modules" "Coldplug All udev Devices" \
              "Network Manager" "Bluetooth service" "User Login Management" \
              "Power Profiles daemon" "Permit User Sessions"; do
    ply update --status="$unit"; sleep 0.6
  done
  if [[ $mode == boot ]]; then
    echo "[boot] passphrase prompt (type in the window to see the stars)"
    plymouth ask-for-password --prompt="Please enter passphrase for disk Samsung SSD 990 PRO (luks-cbf2eacf)" \
      >/dev/null 2>&1 &
    sleep 6
    ply display-message --text="Too many failed attempts. Wait before trying again."
    sleep 4
    ply hide-message --text="Too many failed attempts. Wait before trying again."
    sleep 1
  else
    sleep 4
  fi
  ply quit
  wait "$pid" 2>/dev/null || true
}

case "${1:-}" in
  --files)
    install_files
    ;;
  --preview)
    [[ -n "${DISPLAY:-}" ]] || { echo "--preview needs \$DISPLAY (an X server or Xwayland)" >&2; exit 1; }
    install_files
    preview_mode boot
    preview_mode shutdown
    chmod a+r /tmp/muthur-plymouth-*.log
    echo "Logs: /tmp/muthur-plymouth-boot.log /tmp/muthur-plymouth-shutdown.log"
    ;;
  --revert)
    plymouth-set-default-theme -R "$FALLBACK_THEME"
    ;;
  "")
    install_files
    plymouth-set-default-theme -R muthur
    echo "Default theme: $(plymouth-set-default-theme). Reboot to see it."
    ;;
  *)
    sed -n '2,13p' "$0"
    exit 1
    ;;
esac
