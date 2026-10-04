#!/usr/bin/env bash
# Draws the Limine menu's backdrop (muthur/wallpaper.png): the lock
# screen's tube as a still — near-black phosphor, the wireframe descent
# under the horizon, scanlines and a vignette — with the Weyland-Yutani
# line in the bottom margin, outside the menu. Rerun after changing it;
# the PNG is committed so installing doesn't need ImageMagick.
#
#   make-wallpaper.sh [WIDTHxHEIGHT]   default 1920x1080 (stretched to fit)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/muthur"
SIZE=${1:-1920x1080}
W=${SIZE%x*}
H=${SIZE#*x}

BG="#030805"
FG="#33ff66"
FONT=$(fc-match -f '%{file}' 'Noto Sans Mono')

# The ground plane, as in VectorTerrain.qml: rails from the vanishing
# point on the horizon, cross lines at height / depth below it.
HORIZON=$(( H * 62 / 100 ))
DEPTH=$(( H - HORIZON ))
draw=""
RAILS=28
for ((i = 0; i <= RAILS; i++)); do
  xb=$(awk -v i=$i -v n=$RAILS -v w=$W 'BEGIN { printf "%d", w / 2 + (i / n - 0.5) * 3.2 * w }')
  draw+="line $((W / 2)),$HORIZON $xb,$H "
done
for ((d = 1; d <= 18; d++)); do
  y=$(( HORIZON + DEPTH / d ))
  draw+="line 0,$y $W,$y "
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

magick -size "${W}x${H}" xc:"$BG" \
  \( -size "${W}x${H}" xc:none -stroke "$FG" -strokewidth 1 -fill none \
     -draw "$draw" -channel A -evaluate multiply 0.28 +channel \) -composite \
  \( -size "${W}x$(( DEPTH * 35 / 100 ))" gradient:"${BG}-${BG}00" \) \
     -geometry +0+$HORIZON -composite \
  -stroke "$FG" -strokewidth 1 -draw "line 0,$HORIZON $W,$HORIZON" \
  "$tmp/ground.png"

# Scanlines and a vignette, as in CrtScreen.qml.
magick "$tmp/ground.png" \
  \( -size 1x3 xc:none -fill "#000000" -draw "point 0,2" -write mpr:scan +delete \
     -size "${W}x${H}" tile:mpr:scan -channel A -evaluate multiply 0.35 +channel \) -composite \
  \( -size "${W}x${H}" radial-gradient:"#00000000-#000000c0" \) -composite \
  -font "$FONT" -pointsize $(( H / 60 )) -fill "${FG}88" -stroke none \
  -gravity SouthWest -annotate +$(( H / 17 ))+$(( H / 40 )) "INTERFACE 2037  //  MU/TH/UR 6000" \
  -gravity SouthEast -annotate +$(( H / 17 ))+$(( H / 40 )) "WEYLAND-YUTANI CORP" \
  -depth 8 PNG24:wallpaper.png

echo "Wrote $(pwd)/wallpaper.png ($SIZE)"
