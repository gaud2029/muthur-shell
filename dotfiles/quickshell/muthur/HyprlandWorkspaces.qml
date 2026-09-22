import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace list from Quickshell's native Hyprland IPC module. shell.qml
// only instantiates this under Hyprland (behind a Loader), so the plugin
// never tries — and warns — to reach a Hyprland socket on other
// compositors.
Item {
    id: root

    // Named workspaces get large negative ids from Hyprland; keep them
    // after the numbered ones, in creation order.
    function rank(ws) {
        return ws.id > 0 ? ws.id : 1e9 - ws.id;
    }

    // Regular workspaces only: the special (scratchpad) ones are never
    // shown, and named ones follow the numbered ones.
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(ws => !ws.name.startsWith("special"))
        .sort((a, b) => root.rank(a) - root.rank(b))

    // Hyprland with a Lua config only takes Lua dispatch expressions, while
    // the classic config only takes the classic `workspace N` form (which
    // Quickshell's own HyprlandWorkspace.activate() sends). hyprctl exits
    // non-zero on either mismatch, so try the Lua form first and fall back.
    function focusWorkspace(ws) {
        const target = ws.id > 0 ? String(ws.id) : "name:" + ws.name;
        const lua = `hl.dsp.focus({ workspace = "${target}" })`;
        Quickshell.execDetached(["sh", "-c",
            `hyprctl dispatch "$1" >/dev/null 2>&1 || hyprctl dispatch workspace "$2"`,
            "sh", lua, target]);
    }
}
