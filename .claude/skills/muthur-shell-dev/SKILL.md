---
name: muthur-shell-dev
description: Use when testing changes to the muthur-shell quickshell config (the MU/TH/UR-themed bar/panel under dotfiles/quickshell/muthur) — launching it, restarting it safely, driving it with temporary hooks, and visually verifying results with screenshots.
---

# muthur-shell dev/test loop

## Launch / restart

The shell runs via `quickshell -c muthur`, which resolves to
`~/.config/quickshell/muthur/shell.qml` — a symlink into
`dotfiles/quickshell/muthur/` created by `./install.sh`. The compositor is labwc
(`XDG_CURRENT_DESKTOP=labwc:wlroots`) or Hyprland (`XDG_CURRENT_DESKTOP=Hyprland`,
`HYPRLAND_INSTANCE_SIGNATURE` set — `Workspaces.qml` then reads
`HyprlandWorkspaces.qml` instead of ext-workspace-v1) or niri
(`XDG_CURRENT_DESKTOP=niri`, `NIRI_SOCKET` set; niri ≥ 26.04 implements
ext-workspace-v1 too, so the `Niri.qml` IPC bridge is only a fallback).

**Quickshell hot-reloads QML files on save.** Most edits need no restart at
all — just save and re-check. Write files in place (Edit, python
`open(p, "w")`, `cp` over them): `sed -i` replaces the inode and silently
kills the watch on that file — no reload from then on until a restart. Restart for structural issues (a new file, a
file that fails to load, a change that doesn't seem to take effect).

To restart, kill the exact process by name — do **not** use
`pgrep -f "quickshell -c muthur" | head -1`. `pgrep -f`/`pkill -f` also
match the *wrapping shell command line* of the tool call, which contains
that same string as text. Two ways this bites:
- `head -1` kills the wrapper instead of the real binary, leaving the old
  instance running — a visibly duplicated bar (two copies of every widget).
- `pkill -f "<anything that appears in your own command>"` kills the tool
  call itself (exit code 144, nothing after it runs). Put such commands in
  a script file and invoke the file, or use `pkill -x <name>`.

```sh
pkill -x quickshell   # exact process-name match, kills the real thing
(cd /tmp && quickshell -c muthur > "$S/qs.log" 2>&1 &)   # background, log to scratchpad
sleep 3; grep -iE "warn|error" "$S/qs.log" | grep -vi "settings type"
```

The one warning that is always there and can be ignored: `The Settings type
from Qt.labs.settings is deprecated` (ThemeStore.qml). Anything else —
`WARN`, `TypeError`, `ReferenceError`, `Grid contains more visible items` —
means a binding silently failed to render; fix it before calling a change
verified.

## Driving the shell without clicks

There's no way to click or type into the shell here, so exercise code paths
with a **temporary hook**, screenshot, then restore the file from a backup
copy (`cp Bar.qml "$S/Bar.qml.bak"` first; restoring triggers a hot reload
that closes any popups, so take the screenshot *before* restoring):

- Open a popup / pick a tab (in `Bar.qml`, after `Theme { id: theme }`):
  `Timer { running: root.screen.name === "eDP-1"; interval: 1500; onTriggered: { controlPanel.currentTab = "look"; controlPanel.visible = true; } }`
  — gate on the screen name, or every output's Bar runs the hook.
  Panels: `controlPanel` (tabs `wifi`/`bluetooth`/`sound`/`display`/`look`),
  `aiPanel` (`claude`/`codex`), `calendarPanel`, `batteryPanel`. The drawer
  needs its placement: `drawer.placement = root.popupPlacement(plusButton); drawer.visible = true`.
- Change persisted settings (in `shell.qml`, `ShellRoot { Component.onCompleted: ... }`):
  `ThemeStore.applyPreset("tron")`, `setBarPosition("top")`,
  `setSizeMultiplier(2)`, `setGridUnit(5)`, `setDefaultAgent("claude")`,
  `setWallpaper("/path.png")` / `clearWallpaper()`, `setTerminalOpacity(80)`.
  **Always put things back** — these persist in `theme.ini` and the user
  keeps their own choices there (check `grep -E "^preset|^barPosition|^gridUnit" theme.ini` first).
- Give a widget an `id`/`property alias` temporarily when the hook needs
  to reach inside another file (e.g. arming a `ConfirmButton`); never
  actually fire `SUSPEND`/`POWER OFF`/`LOGOUT`.
- Wait ~1.5 s before touching layout-dependent things: at
  `Component.onCompleted` the windows have no size yet.

Reusable scratch scripts from past sessions live only in the session
scratchpad; recreate them, don't assume they exist.

## Visual verification

`grim` and `magick` are installed. Capture a single output —
`grim -o eDP-1 file.png` — rather than a combined shot: outputs have
different scales (eDP-1 at 1.25) and a combined image is rendered at the
highest one, so logical coordinates don't map 1:1. Outputs come and go
(the external DP-1 may be unplugged; `grim -o DP-1` then errors) — plain
`grim file.png` captures whatever is there. eDP-1 physical size is
1920x1080 for 1536x864 logical.

Crop before reading: `magick in.png -crop WxH+X+Y +repage out.png` (add
`+repage`, and compute offsets explicitly from the image size — ImageMagick's
`-gravity East -crop` gives wrong regions). Downscale full screens
(`-resize 50%`) to keep PNGs small in context. Two captures ~0.7 s apart
catch animation states (the launcher's breathing cursor, blinking labels).

Before believing a stale-looking frame, re-capture: a hot reload or a
1.5 s hook may still be in flight.

## Testing generated configs

`ThemeStore` regenerates on every preset change:
- `~/.config/alacritty/colors.toml` — `[window] opacity`, `[colors.*]`;
  open terminals reload live. A fresh preview:
  `alacritty --class preview -e sh -c '<cmd>; sleep 3'` (kill with
  `pkill -f "alacritty --class preview"` **from a script file**, see above).
- `~/.config/nvim/colors/muthur.lua` — validate with
  `nvim --headless -u NONE -c 'set rtp+=~/.config/nvim' -c 'colorscheme muthur' -c q`.
- `~/.config/fuzzel/colors.ini` (colors + `font=...:pixelsize=N`),
  `~/.config/labwc/themerc-override`,
  `~/.config/hypr/colors.lua` (require()d by `dotfiles/hypr/hyprland.lua`;
  the writer runs `hyprctl reload` — check with
  `hyprctl getoption general:col.active_border` and `hyprctl configerrors`).
- Validate a Hyprland config without running it:
  `Hyprland --verify-config -c dotfiles/hypr/hyprland.lua`; the Lua API is
  in `/usr/share/hypr/stubs/hl.meta.lua`. `~/.config/hypr` is a symlink to
  `dotfiles/hypr`, so edits there reload the live compositor at once.
- `scripts/wallpaper-palette.py <img>` and `scripts/ai-usage-stats.py claude|codex`
  are plain Python and can be run directly to inspect their JSON.
- An MPRIS player for the drawer: generate a WAV with Python's `wave`
  module and `audacious -H tone.wav` (headless); `pkill -x audacious` after.
- Hyprland with a Lua config (`~/.config/hypr/hyprland.lua`) rejects the
  classic `hyprctl dispatch workspace 3` (exit 7, "`)` expected"); use
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`,
  `'hl.dsp.window.move({ workspace = 3 })'` (moves the *focused* window —
  don't run it from the terminal you're working in). To populate a
  workspace, focus it, launch `alacritty --class preview -e sh -c 'sleep 600' &`
  and wait ~2 s before switching away, or the window maps on the
  workspace you moved to. A bell (`printf '\a'`) from an unfocused
  alacritty marks its workspace urgent. Workspaces vanish when emptied.
- Brightness: `busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight amdgpu_bl1 <raw>`
  works without root; restore to `max_brightness` (65535) afterwards.

## QML / Quickshell gotchas learned here

- **Self-shadowing id/property assignment**: `Bar { niri: niri }` where
  `Bar` itself declares `property var niri` binds the property to *itself*
  — silently `undefined` forever. Give the outer instance a distinct id.
- **No `anchors` on a direct child of `Row`/`Column`/`Grid`/`Flow`** — use
  `width`/`height`; anchors are fine again inside a plain child `Item`.
- **Conditional anchors leave stale sizes.** Switching e.g.
  `anchors.bottom: cond ? parent.bottom : undefined` together with
  `anchors.verticalCenter` passes through a transient state with both set;
  Qt writes an explicit `height` that survives after the anchor is
  cleared. Position orientation-dependent items with `x`/`y` bindings
  instead (see `Bar.qml`'s `BarGroup` and hairline).
- **Two bound `Grid` dimensions re-evaluate one at a time** — a transient
  1x1 grid logs `Grid contains more visible items than rows*columns` on
  every orientation switch. `AxisGrid.qml` assigns `rows`/`columns`
  imperatively and calls `forceLayout()`; use it for anything laid out
  along the bar.
- **Required properties disable context properties**: a delegate with
  `required property var modelData` no longer sees `index` — declare
  `required property int index` too.
- **`PanelWindow` popups need `focusable: true`** or a `TextInput` inside
  looks focused but eats no keystrokes.
- **`exclusionMode: ExclusionMode.Ignore` ignores *other* surfaces'
  reserved space too** — use `exclusiveZone: 0` alone for a popup flush
  against the bar. A PanelWindow anchored on three edges takes its
  thickness from the implicit size of the unanchored axis; set both
  `implicitWidth` and `implicitHeight` and let the anchors win.
- **Quickshell list types differ**: `Networking.devices`,
  `WifiDevice.networks`, `ToplevelManager.toplevels` are
  `UntypedObjectModel` (fine as a `model:`, need `.values` for JS array
  methods); `WindowManager.windowsets` (ext-workspace-v1) is a plain JS
  array, and the manager binds lazily — a one-shot read right after
  startup sees `[]`, bindings pick it up.
- **`Qt.labs.settings` round-trips `real` as a string** — persist ints
  (percent) and strings only; it also never deletes keys, and writes
  lazily, so a hook-driven change followed by a hot reload can race
  (the reload re-reads the ini before the write lands). Restart cleanly
  after settings-changing hooks.
- **sysfs emits no inotify events** — `FileView.watchChanges` won't fire
  for `/sys/class/backlight/*`; poll with a `Timer` + `reload()`. amdgpu's
  `actual_brightness` is a non-linear readback; show `brightness`.
- `pragma Singleton` files (`ThemeStore`, `ClaudeUsage`, `CodexUsage`) need
  no qmldir here; a `Singleton { }` root can hold `Process`/`Timer`
  children, a `QtObject` root needs them as `readonly property X: X {}`.
- Python one-liners that rewrite a file must **read before opening for
  write** — `open(p,"w").write(f(open(p).read()))` truncates first.
- **`SystemTrayItem.icon` is already an image URL** (`image://icon/…` or
  `image://qspixmap/…` for pixmap-only items like Discord) — use it as
  `source` directly; `Quickshell.iconPath()` treats it as a name and
  yields the black/pink missing-image glyph.
- **Tray menus (`item.display(window, x, y)`) are platform menus** and need
  `//@ pragma UseQApplication` at the top of `shell.qml` (pragmas only
  apply on restart, not hot reload). Without it the log says
  `Cannot display PlatformMenuEntry`.
- **Tray menus can't be tested from a hook**: Wayland only grants a popup
  grab after real input (`Failed to create grabbing popup … has received
  input`), so a hook-driven `display()` shows nothing — ask the user to
  right-click.
- **`item.activate()` doesn't raise the app's window on Wayland** (apps
  can't self-focus). `Drawer.qml`'s `windowFor()` matches the tray id
  (`discord_status_icon_1`) against `ToplevelManager` app ids by prefix
  and calls `activate()` on the toplevel. Inspect an item's D-Bus side
  with `busctl --user get-property <bus> /StatusNotifierItem
  org.kde.StatusNotifierItem Id|IconName|IconPixmap|Menu` (bus names from
  `RegisteredStatusNotifierItems` on `org.kde.StatusNotifierWatcher`).
