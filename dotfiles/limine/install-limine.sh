#!/usr/bin/env bash
# Themes the Limine boot menu as MU/TH/UR 6000 (GitHub issue #24): the
# wallpaper from make-wallpaper.sh, the menu in phosphor green, the
# branding line. Opt-in, not run by install.sh: it writes to the ESP.
#
#   install-limine.sh            install (or update) the theme
#   install-limine.sh --show     print the theme options limine.conf has now
#   install-limine.sh --revert   remove it, restoring any options it disabled
#
# limine.conf belongs to CachyOS's limine-entry-tool, which rewrites the
# boot entries on every kernel or snapshot update but keeps the global
# options at the top. The theme goes in there as one marked block; any
# other theme option (CachyOS ships its own) is commented out with a
# "#muthur# " prefix rather than deleted, since for most options the first
# one wins and several wallpapers would be picked from at random.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/muthur"
BEGIN="# >>> muthur theme (dotfiles/limine/install-limine.sh)"
END="# <<< muthur theme"
DISABLED="#muthur# "
THEME_KEYS='wallpaper|wallpaper_style|backdrop|interface_branding|interface_branding_colou?r|interface_help_hidden|interface_help_colou?r|interface_help_colou?r_bright|term_[a-z_]+'

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

ESP=$(sed -n 's/^ESP_PATH="\?\([^"]*\)"\?$/\1/p' /etc/default/limine 2>/dev/null | tail -1)
ESP=${ESP:-/boot}
CONF=""
for c in "$ESP/limine.conf" "$ESP/limine/limine.conf" "$ESP/EFI/BOOT/limine.conf" "$ESP/EFI/limine/limine.conf"; do
  [[ -f $c ]] && { CONF=$c; break; }
done
[[ -n $CONF ]] || { echo "No limine.conf found under $ESP" >&2; exit 1; }

# Drops the block and re-enables what installing disabled.
strip() {
  sed -e "/^$(printf '%s' "$BEGIN" | sed 's/[][\/.*^$]/\\&/g')\$/,/^$END\$/d" \
      -e "s/^$DISABLED//" "$1"
}

block() {
  cat <<EOF
$BEGIN
wallpaper: boot():/muthur/wallpaper.png
wallpaper_style: stretched
backdrop: 030805
interface_branding: MU/TH/UR 6000  //  SELECT BOOT SEQUENCE
interface_branding_colour: 33ff66
interface_help_colour: 1d6b38
interface_help_colour_bright: 33ff66
term_background: 60030805
term_foreground: 33ff66
term_background_bright: 1d6b38
term_foreground_bright: dcdfd1
term_palette: 030805;ff4d40;33ff66;ffbf33;1d6b38;b8ffca;33ff66;9aa89c
term_palette_bright: 1d6b38;ff7a6e;7dffa0;ffd57a;33ff66;dcffe6;b8ffca;dcdfd1
term_margin: 96
term_margin_gradient: 0
$END
EOF
}

# limine-entry-tool re-enrolls the config's checksum when that's enabled
# (ENABLE_ENROLL_LIMINE_CONFIG); an edit without it would refuse to boot.
reenroll() {
  if command -v limine-enroll-config >/dev/null; then
    limine-enroll-config
  fi
}

case "${1:-}" in
  --show)
    echo "$CONF:"
    grep -nE "^(${DISABLED})?($THEME_KEYS)[[:space:]]*:|^# (>>>|<<<) muthur" "$CONF" || echo "(no theme options)"
    ;;
  --revert)
    cp -a "$CONF" "$CONF.muthur-bak"
    strip "$CONF.muthur-bak" > "$CONF"
    rm -rf "$ESP/muthur"
    reenroll
    echo "Removed the muthur theme from $CONF (backup: $CONF.muthur-bak)."
    ;;
  "")
    install -d "$ESP/muthur"
    install -m644 "$SRC/wallpaper.png" "$ESP/muthur/wallpaper.png"
    cp -a "$CONF" "$CONF.muthur-bak"
    {
      block
      strip "$CONF.muthur-bak" | sed -E "s/^(($THEME_KEYS)[[:space:]]*:)/$DISABLED\1/"
    } > "$CONF"
    reenroll
    echo "Themed $CONF (backup: $CONF.muthur-bak). The next boot menu shows it."
    "$0" --show
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
