#!/usr/bin/env bash
# Loads the shell on a headless labwc, opens every popup and panel tab
# (`muthur ui open` targets) and fails on any QML error in the log.
#
# Everything runs in a throwaway directory with its own HOME, runtime dir
# and D-Bus session: the shell writes its .ini files next to its QML and
# regenerates configs under HOME, so it never runs on the repo's copy or
# near the live session. Safe to run from inside a desktop session.
#
#   ci/load-test.sh            # exit 1 and the offending lines on failure
#   KEEP=1 ci/load-test.sh     # keep the temp dir (log: $T/shell.log)
#   SHELL_DIR=dir ci/load-test.sh   # test another copy of the config
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
shell_dir=${SHELL_DIR:-$repo/dotfiles/quickshell/muthur}
# Short path: the Wayland and IPC sockets live under it.
T=$(mktemp -d /tmp/muthur-ci.XXXXXX)
cleanup() {
    [[ -n ${wm_pid:-} ]] && kill "$wm_pid" 2>/dev/null || true
    wait 2>/dev/null || true
    if [[ -n ${KEEP:-} ]]; then echo "kept $T"; else rm -rf "$T"; fi
}
trap cleanup EXIT

mkdir -p "$T/home" "$T/run" "$T/labwc" "$T/shell" "$T/bin"
chmod 700 "$T/run"
cp -r "$shell_dir/." "$T/shell/"
rm -f "$T/shell/"*.ini "$T/shell/.qmlls.ini"
printf '<?xml version="1.0"?>\n<labwc_config/>\n' > "$T/labwc/rc.xml"
: > "$T/labwc/autostart"

# The AI tabs run `claude -p /usage` and `codex app-server`: stand-ins
# that answer at once, so no real CLI runs (or needs to be installed).
cat > "$T/bin/claude" <<'STUB'
#!/bin/sh
echo "Current session: 40% used · resets 1am (UTC)"
echo "Current week (all models): 20% used · resets Oct 12, 1am (UTC)"
STUB
printf '#!/bin/sh\nexit 1\n' > "$T/bin/codex"
chmod +x "$T/bin/claude" "$T/bin/codex"

# A clean environment: nothing from the caller's session leaks in
# (LABWC_PID would let the shell reconfigure the real labwc). Software
# GL, as on a CI runner with no GPU.
clean=(env -i PATH="$T/bin:$PATH" HOME="$T/home" XDG_RUNTIME_DIR="$T/run" LANG=C.UTF-8
    LIBGL_ALWAYS_SOFTWARE=1)

"${clean[@]}" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_HEADLESS_OUTPUTS=1 labwc -C "$T/labwc" > "$T/labwc.log" 2>&1 &
wm_pid=$!
for _ in $(seq 50); do
    [[ -S $T/run/wayland-0 ]] && break
    sleep 0.2
done
[[ -S $T/run/wayland-0 ]] || { cat "$T/labwc.log"; echo "labwc didn't start"; exit 1; }

# One D-Bus session for the shell and the ipc calls.
cat > "$T/drive.sh" <<'EOF'
#!/usr/bin/env bash
shell=$1
quickshell -p "$shell" > "$(dirname "$shell")/shell.log" 2>&1 &
qs=$!
trap 'kill "$qs" 2>/dev/null' EXIT
ipc() { quickshell ipc -p "$shell" call muthur "$@"; }
for _ in $(seq 100); do
    kill -0 "$qs" 2>/dev/null || { echo "quickshell exited"; exit 1; }
    ipc list > /dev/null 2>&1 && break
    sleep 0.2
done
targets=$(ipc list 2>/dev/null | python3 -c 'import json, sys; print(" ".join(json.load(sys.stdin)["ui"]))' 2>/dev/null) \
    || { echo "the shell never answered over IPC"; exit 1; }
for target in $targets; do
    err=$(ipc uiOpen "$target" "")
    [[ -z $err ]] || { echo "ui open $target: $err"; exit 1; }
    sleep 0.7
    ipc uiClose > /dev/null
done
sleep 0.5
kill -0 "$qs" 2>/dev/null || { echo "quickshell exited"; exit 1; }
echo "opened: $targets"
EOF
chmod +x "$T/drive.sh"

# QML errors only: the headless box has no PipeWire, UPower, BlueZ or
# NetworkManager, and the warnings about those are expected.
pattern='Failed to load configuration|TypeError|ReferenceError|SyntaxError|is not a type|is not defined|Cannot assign|Unable to assign|Cannot read property|not a function|Type error|Binding loop'
if ! "${clean[@]}" WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland \
    dbus-run-session -- "$T/drive.sh" "$T/shell" 2> "$T/dbus.log"; then
    grep -E "$pattern" "$T/shell.log" || tail -n 30 "$T/shell.log"
    exit 1
fi
if grep -E "$pattern" "$T/shell.log"; then
    echo "QML errors in the shell log (above)"
    exit 1
fi
echo "load test passed"
