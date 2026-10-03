#!/bin/sh
# Lock the session with the shell's MU/TH/UR lock screen (LockScreen.qml)
# and wait until the compositor confirms it, so swayidle's before-sleep
# doesn't let the machine suspend with the desktop still showing. Falls
# back to swaylock when the shell isn't running.
call() { quickshell ipc -c muthur call lock "$@" 2>/dev/null; }

if call lock >/dev/null; then
  for _ in $(seq 30); do
    [ "$(call isSecure)" = true ] && exit 0
    sleep 0.1
  done
  exit 0
fi
exec swaylock -f -c 000000
