import QtQuick
import Quickshell
import Quickshell.Io

// Bridges niri's JSON IPC (no native Quickshell module exists for niri)
// into a simple reactive workspace list.
Item {
    id: root

    // Only talk to niri when it is the running compositor; elsewhere the
    // `niri msg` processes would just fail and log parse errors.
    readonly property bool available: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase().includes("niri")
    property var workspaces: []

    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    Process {
        id: initialFetch
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(this.text);
                } catch (e) {
                    console.warn("Niri: failed to parse initial workspaces:", e);
                }
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "-j", "event-stream"]
        running: root.available

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line.trim())
                    return;

                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return;
                }

                if (event.WorkspacesChanged) {
                    root.workspaces = event.WorkspacesChanged.workspaces;
                } else if (event.WorkspaceActivated) {
                    const { id, focused } = event.WorkspaceActivated;
                    // Find the activated workspace to learn its output, then
                    // clear focus on siblings of that output and set the new one.
                    const activatedWs = root.workspaces.find(ws => ws.id === id);
                    const output = activatedWs ? activatedWs.output : undefined;
                    root.workspaces = root.workspaces.map(ws => {
                        if (ws.id === id) {
                            return Object.assign({}, ws, { is_focused: true, is_active: true });
                        } else if (focused && ws.output === output) {
                            return Object.assign({}, ws, { is_focused: false });
                        }
                        return ws;
                    });
                }
            }
        }
    }

    Component.onCompleted: initialFetch.running = root.available
}
