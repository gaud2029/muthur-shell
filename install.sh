#!/usr/bin/env bash
# Installs the packages the shell and its configs rely on (Arch Linux or
# CachyOS, via pacman — skip with --no-packages), enables the services the
# panels talk to, then symlinks this repo's dotfiles/ into place under
# $XDG_CONFIG_HOME. Existing real files/dirs at the target are backed up
# (never deleted). --yes skips the confirmation.
#
# Then come the optional extras (GitHub issue #32), each one also its own
# installer with a --revert: asked one by one, or picked up front with
# --extras all|none|NAME,NAME (wallpapers, keysound, sddm, plymouth,
# limine). With --yes and no --extras, only the wallpapers are made.
set -euo pipefail

NO_PACKAGES=0
ASSUME_YES=0
EXTRAS_ARG=""
usage() {
  echo "usage: $0 [--no-packages] [--yes] [--extras all|none|wallpapers,keysound,sddm,plymouth,limine]" >&2
  exit 2
}
while [ $# -gt 0 ]; do
  case "$1" in
  --no-packages) NO_PACKAGES=1 ;;
  --yes | -y) ASSUME_YES=1 ;;
  --extras=*) EXTRAS_ARG="${1#--extras=}" ;;
  --extras)
    [ $# -ge 2 ] || usage
    EXTRAS_ARG="$2"
    shift
    ;;
  *) usage ;;
  esac
  shift
done

# The package names are Arch's; CachyOS (Arch plus its own repos) has
# them all too, as do other Arch derivatives, untested.
OS_ID="$(. /etc/os-release 2>/dev/null && echo "${ID:-}")"
OS_LIKE="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}")"
case " $OS_ID $OS_LIKE " in
*" arch "* | *" cachyos "*) ;;
*)
  echo "This install script only supports Arch Linux and CachyOS (found: ${OS_ID:-unknown})." >&2
  exit 1
  ;;
esac

EXTRAS=(wallpapers keysound sddm plymouth limine)
if [ -n "$EXTRAS_ARG" ]; then
  case "$EXTRAS_ARG" in
  all | none) ;;
  *)
    for name in ${EXTRAS_ARG//,/ }; do
      case " ${EXTRAS[*]} " in
      *" $name "*) ;;
      *)
        echo "unknown extra: $name (known: ${EXTRAS[*]})" >&2
        exit 2
        ;;
      esac
    done
    ;;
  esac
fi

cat <<'EOF'
muthur-shell replaces your desktop configuration.

  Back up your dotfiles before going on. Existing configs for bash,
  starship, fuzzel, quickshell, labwc, alacritty, herdr, Neovim, yazi
  and btop are moved aside to *.bak.<date> and replaced by
  symlinks into this repo, and once running the shell rewrites generated
  files on every theme switch (GTK's gtk.css, Firefox's userChrome.css
  import and user.js pref, the color-scheme and GTK theme settings).

  NetworkManager and Bluetooth are enabled if they aren't yet. The
  optional extras (boot menu, boot screen, login screen, typing sounds,
  themed wallpapers) are offered one by one at the end.

EOF
if [ "$ASSUME_YES" -ne 1 ]; then
  read -r -p "Continue? [y/N] " answer
  case "$answer" in
  [yY] | [yY][eE][sS]) ;;
  *)
    echo "Aborted."
    exit 1
    ;;
  esac
  echo
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Everything the configs invoke or the panels talk to. herdr (the terminal
# workspace manager config in dotfiles/herdr) isn't packaged and is
# installed separately.
PACKAGES=(
  labwc          # compositor (dotfiles/labwc)
  quickshell     # the shell itself
  fuzzel         # launcher ([>_], Super+Space)
  alacritty      # terminal (themed; Super+Return and the labwc menu)
  starship       # prompt (dotfiles/starship, themed via ANSI colors)
  yazi           # file manager (dotfiles/yazi, themed via ANSI colors; Super+E)
  btop           # system monitor (dotfiles/btop + the generated theme)
  swaybg         # wallpaper (labwc autostart)
  kanshi         # output profiles (labwc autostart)
  wdisplays      # output layout GUI ([SYS] > DISPLAY > ARRANGE)
  swayidle       # idle timer (labwc autostart)
  swaylock       # fallback locker when the shell isn't running (scripts/lock.sh)
  wlopm          # screen power on idle (labwc autostart)
  wlsunset       # night light, run by the shell ([SYS] > DISPLAY)
  grim           # screenshots (Super+Shift+3/4)
  slurp          # region picker for the Super+Shift+4 screenshots
  wl-clipboard   # wl-copy, for Ctrl+Super+Shift+4 to the clipboard
  neovim         # dotfiles/nvim (LazyVim) + the generated colorscheme
  noto-fonts     # Noto Sans Mono, the shell's face
  networkmanager # [SYS] > NETWORK
  bluez          # [SYS] > BT
  bluez-utils    # bluetoothctl, used by the BT tab
  pipewire       # [SYS] > AUDIO
  wireplumber
  upower # [POW]
  polkit # lets systemctl suspend/poweroff run without root
  xdg-desktop-portal-gtk # serves the light/dark color-scheme to apps
  xdg-utils      # xdg-mime, to make yazi the folder handler (below)
  python         # the muthur command and the shell's helper scripts
  imagemagick    # the palette drawn from a wallpaper ([SYS] > [LOOK])
  git            # LazyVim fetches its plugins with it on Neovim's first start
)

install_packages() {
  echo "Installing packages (sudo pacman -S --needed)..."
  sudo pacman -S --needed "$@"
  echo
}

# CachyOS enables these; a plain Arch install leaves them off. Another
# network manager already running is left alone: two would fight over
# the interfaces.
enable_services() {
  local other
  if ! systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
    other=""
    for unit in iwd systemd-networkd dhcpcd netctl connman; do
      systemctl is-active --quiet "$unit.service" 2>/dev/null && other="$other $unit"
    done
    if [ -n "$other" ]; then
      echo "note: NetworkManager not enabled, since$other is running ([SYS] > NETWORK needs NetworkManager)."
      echo "      To switch: sudo systemctl disable --now$other && sudo systemctl enable --now NetworkManager"
    else
      echo "Enabling NetworkManager..."
      sudo systemctl enable --now NetworkManager.service
    fi
  fi
  if ! systemctl is-enabled --quiet bluetooth.service 2>/dev/null; then
    echo "Enabling Bluetooth..."
    sudo systemctl enable --now bluetooth.service
  fi
}

if [ "$NO_PACKAGES" -ne 1 ]; then
  install_packages "${PACKAGES[@]}"
  enable_services
fi

# "source relative to dotfiles/" -> "target relative to \$CONFIG_HOME",
# or to \$HOME when the target starts with "~/".
LINKS=(
  "bash/bashrc:~/.bashrc"
  "starship/starship.toml:starship.toml"
  "fuzzel:fuzzel"
  "quickshell/muthur:quickshell/muthur"
  "labwc:labwc"
  "alacritty:alacritty"
  "herdr/config.toml:herdr/config.toml"
  "nvim:nvim"
  "yazi:yazi"
  "btop:btop"
  "bin/muthur:~/.local/bin/muthur"
  "bash/completions/muthur:~/.local/share/bash-completion/completions/muthur"
)

link_one() {
  local src="$DOTFILES_DIR/$1"
  local dest
  case "$2" in
  "~/"*) dest="$HOME/${2#\~/}" ;;
  *) dest="$CONFIG_HOME/$2" ;;
  esac

  if [ ! -e "$src" ]; then
    echo "skip: source missing: $src" >&2
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ]; then
    if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
      echo "ok:      $dest already linked"
      return
    fi
    echo "replacing stale symlink: $dest"
    rm "$dest"
  elif [ -e "$dest" ]; then
    local backup
    backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    echo "backing up existing $dest -> $backup"
    mv "$dest" "$backup"
  fi

  ln -s "$src" "$dest"
  echo "linked:  $dest -> $src"
}

for pair in "${LINKS[@]}"; do
  link_one "${pair%%:*}" "${pair#*:}"
done

# The shell writes GTK's user gtk.css on every theme switch; keep a copy of
# one it didn't write itself before that happens.
for gtk_css in "$CONFIG_HOME/gtk-3.0/gtk.css" "$CONFIG_HOME/gtk-4.0/gtk.css"; do
  if [ -f "$gtk_css" ] && ! grep -q "Generated by ThemeStore.qml" "$gtk_css"; then
    backup="${gtk_css}.bak.$(date +%Y%m%d%H%M%S)"
    echo "backing up existing $gtk_css -> $backup"
    mv "$gtk_css" "$backup"
  fi
done

# Hyprland and niri used to be supported too. Their configs are gone from
# the repo, but an older checkout keeps the gitignored colors file the shell
# generated there, and ~/.config still links to the directory: clear both.
for name in hypr niri; do
  rm -f "$DOTFILES_DIR/$name/colors.lua" "$DOTFILES_DIR/$name/colors.kdl"
  rmdir "$DOTFILES_DIR/$name" 2>/dev/null || true
  link="$CONFIG_HOME/$name"
  if [ -L "$link" ] && [ ! -e "$link" ] && [ "$(readlink "$link")" = "$DOTFILES_DIR/$name" ]; then
    rm "$link"
    echo "removed: $link (Hyprland/niri support was dropped)"
  fi
done

# The shell used to generate alacritty's colors in alacritty/colors.toml;
# it now writes alacritty/theme/muthur.toml, so drop the stale copy.
rm -f "$DOTFILES_DIR/alacritty/colors.toml"

# Make "open folder" from other apps land in yazi rather than a GUI one.
if command -v xdg-mime >/dev/null && [ -f /usr/share/applications/yazi.desktop ]; then
  xdg-mime default yazi.desktop inode/directory
  echo "default: inode/directory -> yazi.desktop"
fi

# --- Optional extras --------------------------------------------------------
# Each one runs its own installer (the root ones ask for sudo themselves),
# and a failed one doesn't stop the others.

extra_title() {
  case "$1" in
  wallpapers) echo "Themed wallpapers" ;;
  keysound) echo "Typing sounds" ;;
  sddm) echo "Login screen (SDDM)" ;;
  plymouth) echo "Boot screen (Plymouth)" ;;
  limine) echo "Boot menu (Limine)" ;;
  esac
}

extra_about() {
  case "$1" in
  wallpapers) echo "Draws four wallpapers per color preset, offered in [SYS] > [LOOK].
Writes ~/.local/share/muthur-shell/wallpapers. No root, a minute or more." ;;
  keysound) echo "Keypress sounds and ambient sound, picked in [SYS] > KEYBOARD and AUDIO.
Root: builds a player into /usr/local/bin, adds a system service that
reads the keyboards (only \"a key was pressed\" leaves it)." ;;
  sddm) echo "The MU/TH/UR login screen.
Root: /usr/share/sddm/themes/muthur and /etc/sddm.conf.d/muthur.conf.
Installs SDDM and enables it at boot if no display manager is." ;;
  plymouth) echo "The MU/TH/UR boot and shutdown screen (and disk passphrase prompt).
Root: /usr/share/plymouth/themes/muthur, sets it as default and
rebuilds the initramfs." ;;
  limine) echo "The MU/TH/UR Limine boot menu.
Root: writes to the boot partition (a wallpaper, a block in limine.conf,
backed up first)." ;;
  esac
}

extra_revert() {
  case "$1" in
  wallpapers) echo "rm -rf ~/.local/share/muthur-shell/wallpapers" ;;
  keysound) echo "dotfiles/keysound/install-keysound.sh --revert" ;;
  sddm) echo "dotfiles/sddm/install-sddm.sh --revert" ;;
  plymouth) echo "dotfiles/plymouth/install-plymouth.sh --revert" ;;
  limine) echo "dotfiles/limine/install-limine.sh --revert" ;;
  esac
}

# Prints why an extra can't be installed here, or nothing.
extra_unavailable() {
  case "$1" in
  plymouth)
    # Plymouth runs from the initramfs: mkinitcpio needs its hook, and
    # the kernel needs `splash` to show it. CachyOS sets both up.
    if command -v mkinitcpio >/dev/null && ! command -v dracut >/dev/null &&
      ! grep -hsE '^[[:space:]]*HOOKS=' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf | grep -qw plymouth; then
      echo "mkinitcpio has no plymouth hook. Add plymouth to HOOKS in /etc/mkinitcpio.conf
(after systemd or udev, before sd-encrypt or encrypt) and splash to the kernel
command line, then rerun with --extras plymouth."
    fi
    ;;
  limine)
    if ! pacman -Q limine >/dev/null 2>&1; then
      echo "Limine isn't installed: the theme is for the Limine boot menu only."
    fi
    ;;
  esac
}

extra_packages() {
  case "$1" in
  wallpapers) echo "python librsvg" ;;
  keysound) echo "gcc pkgconf pipewire python" ;;
  sddm) echo "sddm" ;;
  plymouth) echo "plymouth" ;;
  esac
}

# Called in an `if`, where set -e is off: each step checks for itself.
extra_run() {
  case "$1" in
  wallpapers) python3 "$REPO_DIR/wallpapers/themed.py" ;;
  keysound) "$DOTFILES_DIR/keysound/install-keysound.sh" ;;
  sddm)
    "$DOTFILES_DIR/sddm/install-sddm.sh" || return
    if ! systemctl is-enabled --quiet display-manager.service 2>/dev/null; then
      # Enabled, not started: starting it now would take over the screen.
      sudo systemctl enable sddm.service || return
      echo "SDDM enabled: the login screen comes up from the next boot."
    elif [ "$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")" != sddm.service ]; then
      echo "note: another display manager is enabled; the theme shows once SDDM is"
      echo "      (sudo systemctl disable <it> && sudo systemctl enable sddm)."
    fi
    ;;
  plymouth)
    "$DOTFILES_DIR/plymouth/install-plymouth.sh" || return
    grep -qw splash /proc/cmdline ||
      echo "note: the kernel command line has no splash: add it in your boot loader's entries to see the theme."
    ;;
  limine) "$DOTFILES_DIR/limine/install-limine.sh" ;;
  esac
}

wanted() {
  case "$EXTRAS_ARG" in
  all) return 0 ;;
  none) return 1 ;;
  "") ;;
  *)
    case ",$EXTRAS_ARG," in *",$1,"*) return 0 ;; *) return 1 ;; esac
    ;;
  esac
  # No --extras: the wallpapers by default, the rest only when asked for.
  local default=n hint="[y/N]" answer
  [ "$1" = wallpapers ] && default=y hint="[Y/n]"
  if [ "$ASSUME_YES" -eq 1 ]; then
    [ "$default" = y ]
    return
  fi
  read -r -p "Install it? $hint " answer
  answer="${answer:-$default}"
  case "$answer" in [yY] | [yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

DONE=() SKIPPED=() FAILED=()
if [ "$EXTRAS_ARG" != none ]; then
  echo
  echo "Optional extras (each can be installed or reverted on its own later)."
fi
for extra in "${EXTRAS[@]}"; do
  [ "$EXTRAS_ARG" = none ] && break
  echo
  echo "== $(extra_title "$extra")"
  extra_about "$extra" | sed 's/^/   /'
  reason="$(extra_unavailable "$extra")"
  if [ -n "$reason" ]; then
    echo "   Not available here."
    echo "$reason" | sed 's/^/   /'
    SKIPPED+=("$extra")
    continue
  fi
  if ! wanted "$extra"; then
    SKIPPED+=("$extra")
    continue
  fi
  pkgs="$(extra_packages "$extra")"
  if [ "$NO_PACKAGES" -ne 1 ] && [ -n "$pkgs" ]; then
    # shellcheck disable=SC2086
    install_packages $pkgs || { FAILED+=("$extra"); continue; }
  fi
  if extra_run "$extra"; then
    DONE+=("$extra")
  else
    echo "!! $(extra_title "$extra") failed; the rest goes on."
    FAILED+=("$extra")
  fi
done

echo
echo "Done. Launch the shell with: quickshell -c muthur"
echo "(labwc's autostart does it: log in to the labwc session, or run labwc from a tty.)"
if [ ${#DONE[@]} -gt 0 ]; then
  echo
  echo "Extras installed, and how to undo each:"
  for extra in "${DONE[@]}"; do
    printf '  %-24s %s\n' "$(extra_title "$extra")" "$(extra_revert "$extra")"
  done
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo
  echo "Extras that failed (see above), to retry: $0 --no-packages --extras $(
    IFS=,
    echo "${FAILED[*]}"
  )"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo
  echo "Not installed: $(for e in "${SKIPPED[@]}"; do printf '%s, ' "$e"; done | sed 's/, $//')."
  echo "Later: $0 --extras NAME (or run its installer in dotfiles/)."
fi
