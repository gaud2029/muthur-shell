pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine mode (GitHub issue #27): keeps the screens on and the session
// unlocked for presentations, videos, long builds. Every Bar holds an
// IdleInhibitor enabled by `active`; while one is up, labwc reports no
// idleness, so swayidle (labwc's autostart) neither turns the screens off
// nor locks. Not saved: a restart of the shell gives idling back, and so
// does locking (LockScreen.engage()), which means leaving.
// Toggled from the drawer's AWAKE button, or from outside with
//   quickshell ipc -c muthur call caffeine toggle
Singleton {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active;
    }

    IpcHandler {
        target: "caffeine"

        function toggle(): void {
            root.toggle();
        }

        function isActive(): bool {
            return root.active;
        }
    }
}
