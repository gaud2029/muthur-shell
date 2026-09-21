#!/usr/bin/env bash
# Installs the packages the shell and its configs rely on (Arch/CachyOS,
# via pacman — skip with --no-packages), then symlinks this repo's
# dotfiles/ into place under $XDG_CONFIG_HOME. Existing real files/dirs at
# the target are backed up (never deleted).
set -euo pipefail

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
  mako           # notifications (labwc autostart)
  swayidle       # idle timer (labwc autostart)
  swaylock       # locker: idle lock and the drawer's LOCK button
  wlopm          # screen power on idle (labwc autostart)
  neovim         # dotfiles/nvim (LazyVim) + the generated colorscheme
  noto-fonts     # Noto Sans Mono, the shell's face
  networkmanager # [SYS] > NETWORK
  bluez          # [SYS] > BT
  bluez-utils    # bluetoothctl, used by the BT tab
  pipewire       # [SYS] > SOUND
  wireplumber
  upower # [POW]
  polkit # lets systemctl suspend/poweroff run without root
)

install_packages() {
  if ! command -v pacman >/dev/null; then
    echo "skip: no pacman — install these yourself: ${PACKAGES[*]}" >&2
    return
  fi
  echo "Installing packages (sudo pacman -S --needed)..."
  sudo pacman -S --needed "${PACKAGES[@]}"
  echo
}

if [ "${1:-}" != "--no-packages" ]; then
  install_packages
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

# Make "open folder" from other apps land in yazi rather than a GUI one.
if command -v xdg-mime >/dev/null && [ -f /usr/share/applications/yazi.desktop ]; then
  xdg-mime default yazi.desktop inode/directory
  echo "default: inode/directory -> yazi.desktop"
fi

echo
echo "Done. Launch the shell with: quickshell -c muthur"
