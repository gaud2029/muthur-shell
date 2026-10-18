#!/usr/bin/env bash
# Installs the MU/TH/UR Plymouth boot screen (GitHub issue #24). Opt-in
# (install.sh offers it): it needs root and rebuilds the initramfs.
#
#   install-plymouth.sh            install, make it the default theme and
#                                  rebuild the initramfs (next boot shows it)
#   install-plymouth.sh --files    install the theme files only
#   install-plymouth.sh --preview  install the files and play the boot and
#                                  shutdown screens in a window (x11
#                                  renderer, needs $DISPLAY), no reboot
#   install-plymouth.sh --revert   back to the theme it replaced, rebuilt
#
# Where Plymouth isn't set up yet (a plain Arch install; CachyOS comes
# with it), installing also adds the plymouth hook to mkinitcpio.conf and
# "quiet splash" to the kernel command line (GRUB, Limine or
# systemd-boot), backing each file up as *.muthur-bak; --revert takes
# out what it added.
#
# The files are copied, not symlinked: the theme is read from the
# initramfs, where /home (encrypted) doesn't exist.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/muthur"
DEST=/usr/share/plymouth/themes/muthur
# The default theme before muthur's, for --revert. Outside $DEST, which
# a plymouth package update could clear.
PREVIOUS=/var/lib/muthur/plymouth-previous-theme
# What setup_boot added, for --revert: "hook", or "cmdline FILE WORD...".
ADDED=/var/lib/muthur/plymouth-added

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

backup() { [[ -e $1.muthur-bak ]] || cp -a "$1" "$1.muthur-bak"; }

limine_conf() {
  local e c
  for e in /boot /efi /boot/efi; do
    for c in "$e/limine.conf" "$e/limine/limine.conf" "$e/EFI/BOOT/limine.conf" "$e/EFI/limine/limine.conf"; do
      [[ -f $c ]] && { echo "$c"; return 0; }
    done
  done
  return 1
}

# Appends quiet and splash to the lines of $1 matching the ERE $2, where
# they're missing; GRUB's line ends in a quote, the others don't.
add_words() {
  local file=$1 re=$2 word added=()
  for word in quiet splash; do
    if grep -E "$re" "$file" | grep -vqE "[[:space:]\"=]$word([[:space:]\"]|\$)"; then
      backup "$file"
      sed -i -E "/$re/{/[[:space:]\"=]$word([[:space:]\"]|\$)/!{s/\"\$/ $word\"/;t;s/\$/ $word/}}" "$file"
      added+=("$word")
    fi
  done
  if [[ ${#added[@]} -gt 0 ]]; then
    echo "cmdline $file ${added[*]}" >> "$ADDED"
    echo "Added ${added[*]} to the kernel command line in $file"
  fi
}

# Hook and kernel command line, where they're missing.
setup_boot() {
  install -d "$(dirname "$ADDED")"
  if command -v mkinitcpio >/dev/null &&
    ! grep -hsE '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf | grep -qw plymouth; then
    if ! grep -qE '^HOOKS=.*\b(systemd|udev)\b' /etc/mkinitcpio.conf; then
      echo "Can't place the plymouth hook: HOOKS in /etc/mkinitcpio.conf has neither systemd nor udev." >&2
      return 1
    fi
    backup /etc/mkinitcpio.conf
    # Right after systemd/udev, so before sd-encrypt/encrypt: the
    # passphrase prompt is Plymouth's.
    sed -i -E '/^HOOKS=/ s/\b(systemd|udev)\b/& plymouth/' /etc/mkinitcpio.conf
    echo hook >> "$ADDED"
    echo "Added the plymouth hook to /etc/mkinitcpio.conf"
  fi

  local conf entries
  if [[ -f /etc/default/limine ]]; then
    # CachyOS: limine-entry-tool writes the entries from its own
    # KERNEL_CMDLINE, which has splash already.
    grep -qw splash /etc/default/limine ||
      echo "note: add splash to KERNEL_CMDLINE in /etc/default/limine" >&2
  elif [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]]; then
    add_words /etc/default/grub '^GRUB_CMDLINE_LINUX_DEFAULT='
    if grep -q "^cmdline /etc/default/grub" "$ADDED" 2>/dev/null; then
      grub-mkconfig -o /boot/grub/grub.cfg
    fi
  elif conf=$(limine_conf); then
    add_words "$conf" '^[[:space:]]*(kernel_)?cmdline:'
  elif entries=$(ls -d /boot/loader/entries /efi/loader/entries 2>/dev/null | head -1) && [[ -n $entries ]]; then
    for conf in "$entries"/*.conf; do
      add_words "$conf" '^options[[:space:]]'
    done
  else
    echo "note: add quiet splash to the kernel command line in your boot loader" >&2
  fi
}

# Takes out what setup_boot added.
undo_boot() {
  [[ -f $ADDED ]] || return 0
  local kind file words word
  while read -r kind file words; do
    case "$kind" in
    hook)
      sed -i -E '/^HOOKS=/ s/ plymouth\b//' /etc/mkinitcpio.conf
      echo "Removed the plymouth hook from /etc/mkinitcpio.conf"
      ;;
    cmdline)
      for word in $words; do
        sed -i -E "s/ $word([\" ]|\$)/\1/" "$file"
      done
      [[ $file == /etc/default/grub ]] && grub-mkconfig -o /boot/grub/grub.cfg
      echo "Removed $words from $file"
      ;;
    esac
  done < "$ADDED"
  rm -f "$ADDED"
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
    theme=$(cat "$PREVIOUS" 2>/dev/null || true)
    if [[ -z $theme || ! -d /usr/share/plymouth/themes/$theme ]]; then
      # Installed before the previous theme was kept: CachyOS's, or
      # Arch's default.
      for theme in cachyos bgrt spinner text; do
        [[ -d /usr/share/plymouth/themes/$theme ]] && break
      done
    fi
    undo_boot
    plymouth-set-default-theme -R "$theme"
    rm -f "$PREVIOUS"
    echo "Default theme: $theme."
    ;;
  "")
    setup_boot
    install_files
    current=$(plymouth-set-default-theme 2>/dev/null || true)
    if [[ -n $current && $current != muthur ]]; then
      install -Dm644 /dev/null "$PREVIOUS"
      echo "$current" > "$PREVIOUS"
    fi
    plymouth-set-default-theme -R muthur
    echo "Default theme: $(plymouth-set-default-theme). Reboot to see it."
    grep -qw splash /proc/cmdline || [[ -f $ADDED ]] ||
      echo "note: the kernel command line has no splash: Plymouth won't show until it has." >&2
    ;;
  *)
    sed -n '2,19p' "$0"
    exit 1
    ;;
esac
