import QtQuick
import Quickshell

// Base for the popups opened from the bar's end group (SYS/AI/clock/POW):
// sits flush against the bar in the corner where those buttons live,
// clamped to the screen so a large size multiplier can't push it off.
PanelWindow {
    id: root

    property int requestedWidth
    property int requestedHeight

    anchors {
        left: theme.barPosition === "left"
        right: theme.barPosition === "right" || !theme.vertical
        top: theme.barPosition === "top"
        bottom: theme.barPosition === "bottom" || theme.vertical
    }

    implicitWidth: Math.min(requestedWidth, (screen ? screen.width : requestedWidth) - (theme.vertical ? theme.barThickness : 0))
    implicitHeight: Math.min(requestedHeight, (screen ? screen.height : requestedHeight) - (theme.vertical ? 0 : theme.barThickness))
    color: theme.colorBg
    visible: false
    onVisibleChanged: if (visible) escapeCatcher.forceActiveFocus()

    exclusiveZone: 0
    aboveWindows: true
    focusable: true

    Theme { id: theme }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: theme.colorFg
        border.width: 1
    }

    EscapeToClose { id: escapeCatcher; targetWindow: root }
}
