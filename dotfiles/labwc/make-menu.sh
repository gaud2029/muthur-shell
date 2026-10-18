#!/usr/bin/env bash
# Writes labwc's menu.xml from menu.xml.in, keeping the Titlebar entry of
# the window menu only when the running labwc build has SetTitlebarPosition
# (the fork's vertical-titlebar branch, see the README). Stock labwc would
# flag it as a config error on every start. install.sh runs this; rerun it
# after switching between stock and patched labwc.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABWC="$(command -v labwc || true)"

if [[ -n $LABWC ]] && grep -qa SetTitlebarPosition "$LABWC"; then
  sed '/<!-- \/\?muthur:titlebar -->/d' "$DIR/menu.xml.in" > "$DIR/menu.xml"
  echo "menu.xml: with the Titlebar entry (patched labwc)"
else
  sed '/<!-- muthur:titlebar -->/,/<!-- \/muthur:titlebar -->/d' "$DIR/menu.xml.in" > "$DIR/menu.xml"
  echo "menu.xml: without the Titlebar entry (stock labwc)"
fi
# A running labwc picks it up without a restart.
if [[ -n ${LABWC_PID:-} ]]; then
  labwc --reconfigure 2>/dev/null || true
fi
