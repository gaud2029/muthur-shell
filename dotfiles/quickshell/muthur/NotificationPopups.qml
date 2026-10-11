import QtQuick
import Quickshell

// Notification popups (Notifications.popups), stacked in the corner where
// the bar's end group and its popups live, the newest nearest the bar.
// Each one times out on its own, paused while the pointer is over it.
PanelWindow {
    id: root

    // How many fit on screen at once; the rest wait in the drawer.
    readonly property int maxShown: 4
    // Bar at the bottom (or vertical): the stack grows up from the bottom
    // corner, so the newest goes last.
    readonly property bool fromBottom: theme.barPosition !== "top"
    readonly property var shown: {
        const list = Notifications.popups.slice(0, maxShown);
        return fromBottom ? list.reverse() : list;
    }
    // Cards with their reply field open; the window takes keyboard focus
    // only then, so a popup arriving never steals it from what you type.
    property int replying: 0

    anchors {
        left: theme.barPosition === "left"
        right: theme.barPosition !== "left"
        top: !fromBottom
        bottom: fromBottom
    }
    margins {
        left: theme.gridUnit * 2
        right: theme.gridUnit * 2
        top: theme.gridUnit * 2
        bottom: theme.gridUnit * 2
    }

    implicitWidth: theme.gridUnit * 80
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: shown.length > 0

    exclusiveZone: 0
    aboveWindows: true
    focusable: replying > 0

    Theme { id: theme }

    Column {
        id: stack
        width: parent.width
        spacing: theme.gridUnit * 2

        Repeater {
            // Diffs the list, so cards already up keep their timers.
            model: ScriptModel { values: root.shown }

            NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                width: stack.width

                onReplyingChanged: root.replying += replying ? 1 : -1
                Component.onDestruction: if (replying) root.replying--

                Timer {
                    readonly property int timeout: Notifications.timeout(card.notification)
                    interval: timeout
                    running: timeout > 0 && !card.hovered && !card.replying
                    onTriggered: Notifications.timedOut(card.notification)
                }
            }
        }
    }
}
