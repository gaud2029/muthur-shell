---
name: muthur-vm
description: Use when testing install.sh, the optional extras (patched labwc, SDDM, Plymouth, Limine, typing sounds, wallpapers), archinstall/muthur.json or the shell on a fresh, minimal plain Arch install, in throwaway QEMU/KVM VMs driven with vm/muthur-vm — building them, resetting to a clean snapshot, running the installer, logging in, and screenshotting any stage from the boot menu to the desktop. Not for day-to-day QML changes (that's muthur-shell-dev, on the live shell).
---

# Testing on plain Arch: the muthur VMs

`vm/muthur-vm` runs Arch VMs that stand in for a fresh install on the
ThinkPad T420 (the target machine): SeaBIOS (legacy boot, MBR), a
1600x900 screen like its HD+ panel. No root needed on the host (needs
`qemu-desktop` and KVM access); root happens inside the VMs: user
`muthur`, password `muthur`, passwordless sudo, SSH with a key.

Two VMs, picked with `MUTHUR_VM` (every command works on either; both
can run at once):

| `MUTHUR_VM` | Made by | Boot loader | Network | SSH |
|---|---|---|---|---|
| `cloud` (default) | `setup`: Arch's cloud image + cloud-init | GRUB | systemd-networkd | :2222 |
| `t420` | `archinstall`: the Arch ISO + `archinstall/muthur.json` | Limine | NetworkManager | :2223 |

`t420` is the real T420 path (what the README tells the user to do);
`cloud` exercises the other branches (GRUB, another network manager
running, so install.sh leaves NetworkManager off and says so). State
lives in `~/.cache/muthur-vm/` (disks, ISO, SSH key, QMP sockets,
`archinstall.log`).

## Commands

```sh
vm/muthur-vm setup                    # cloud VM, once (~2 min): snapshot "fresh"
vm/muthur-vm archinstall              # t420 VM (~3 min): ISO, archinstall --silent, snapshot "fresh"
vm/muthur-vm start [--headless]       # boot; waits for SSH. A window the user can watch, unless --headless
vm/muthur-vm push                     # this working tree (uncommitted too) -> ~/muthur-shell
vm/muthur-vm ssh 'CMD'                # run CMD in the VM
vm/muthur-vm shot FILE.png            # screenshot, any stage: Limine/GRUB, Plymouth, SDDM, desktop
vm/muthur-vm type muthur; vm/muthur-vm keys ret     # type at the screen (SDDM, a tty)
vm/muthur-vm stop | reset [SNAP] | snapshot NAME | snapshots | status
```

Prefix with `MUTHUR_VM=t420` (or `export` it) for the t420 VM.
`reset`/`snapshot` stop the VM first. `reset` with no name goes back to
`fresh`: plain Arch, nothing of muthur installed.

## The T420 loop

```sh
export MUTHUR_VM=t420
vm/muthur-vm reset && vm/muthur-vm start --headless && vm/muthur-vm push
vm/muthur-vm ssh 'cd ~/muthur-shell && ./install.sh --yes --extras all > ~/install.log 2>&1; echo rc=$?'
vm/muthur-vm ssh 'sed -n "/^Extras installed/,\$p" ~/install.log'   # the summary
vm/muthur-vm snapshot installed       # optional: skip the ~2 min install next time
# the whole boot, one shot per ~0.6 s: Limine menu (~b03), Plymouth (~b12), SDDM (~b30)
(vm/muthur-vm start >/dev/null &); sleep 1
for i in $(seq -w 1 40); do vm/muthur-vm shot $S/b$i.png >/dev/null 2>&1; sleep 0.6; done
vm/muthur-vm type muthur; vm/muthur-vm keys ret; sleep 25; vm/muthur-vm shot $S/desktop.png
```

`$S`: a directory in the scratchpad; Read the PNGs (file sizes tell the
stages apart: a few KB is a blank or text screen). Run install.sh over
SSH with its output in a file: pacman's output is long, and no TTY means
every prompt must be covered by `--yes` (a prompt that reads stdin gets
EOF and aborts: that's how pacman's own "Proceed?" was caught). To test
the interactive questions, feed answers: `printf 'y\nn\n...' | ./install.sh`.

After logging in, check what broke:

```sh
vm/muthur-vm ssh 'pgrep -a labnag || echo "no labnag"'   # labwc's red "Config errors detected" bar
vm/muthur-vm ssh 'grep ERROR ~/.local/share/sddm/wayland-session.log | grep -v EGL'   # labwc
vm/muthur-vm ssh 'grep -iE "warn|error" /run/user/1000/quickshell/by-id/*/log.log'    # the shell
```

Expected noise, not bugs: EGL/DRI2 errors (no GPU: llvmpipe), RTKit,
org.bluez not activatable (no adapter), the X11-unix socket in use
(SDDM's Xorg holds :0), on `cloud` "Network will not work" (NetworkManager
left off since systemd-networkd runs), and a first start's "Read of
…colors.ini failed" (the shell writes them right after).

## Changing archinstall/muthur.json

`archinstall` reads it straight from the repo, adds what only the VM
needs (the disk layout, the account a person would type, openssh and
the key, passwordless sudo) and runs archinstall `--silent`. The keys
must match the archinstall version on the ISO (4.5 now): check them in
its source (`archinstall/lib/args.py` and `lib/models/`), not in its
`examples/`, which lag behind. A failed run leaves the ISO up (SSH as
root on :2223) and the log in `~/.cache/muthur-vm/archinstall.log`.
`rm ~/.cache/muthur-vm/archlinux.iso` to fetch a newer ISO.

## Gotchas

- The screen is the plain VGA card (bochs-drm) with a 1600x900 EDID:
  virtio-vga takes the GTK window's size as its mode (640x480 at
  first), whatever xres/yres or `video=` say.
- `MUTHUR_VM_GL=1` (virgl) is faster but `shot` fails with "no surface":
  QEMU can't screendump a GL scanout.
- The cloud image puts `console=ttyS0` last on the kernel command line;
  that makes the serial console primary and Plymouth falls back to
  text. `setup` takes it out (`no_serial_console`).
- `type` knows letters, digits, space and `-._/`; anything else goes
  through `keys` with QEMU key names (`shift-1` for `!`).
- llvmpipe on 4 cores says nothing about the T420's HD 3000 frame rate.
- Editing `vm/muthur-vm` while a backgrounded run of it is going: write
  the new version to a temp file and `mv` it over (bash reads a running
  script as it goes).
