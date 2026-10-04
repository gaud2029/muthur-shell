pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Focus mode (GitHub issue #21): the bar folds away to just its
// breathing cursor in the corner, on every screen. Its space stays
// reserved, so windows don't move or grow when it folds and unfolds.
// Toggled by clicking that cursor, or from outside with
//   quickshell ipc -c muthur call focus toggle
Singleton {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active;
    }

    IpcHandler {
        target: "focus"

        function toggle(): void {
            root.toggle();
        }

        function isActive(): bool {
            return root.active;
        }
    }
}
