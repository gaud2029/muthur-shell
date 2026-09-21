import QtQuick
import Quickshell.Services.UPower

// A TerminalButton with a live charge-level bar under the label instead
// of just text. Hidden entirely on desktops with no battery.
Rectangle {
    id: root

    property bool selected: false
    signal clicked()

    Theme { id: theme }

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!device && device.isPresent
    // Quickshell normalizes UPower's 0-100 DBus percentage to a 0.0-1.0 float.
    readonly property real percent: present ? device.percentage * 100 : 0
    readonly property bool filled: selected || mouseArea.pressed

    // Slow blink between "POW" and the remaining percentage once charge
    // drops below 80%, as a low-key low-battery cue.
    property bool showPercent: false

    Timer {
        interval: 2000
        running: root.present && root.percent < 80
        repeat: true
        onTriggered: root.showPercent = !root.showPercent
    }

    visible: present
    implicitWidth: theme.buttonSize
    implicitHeight: theme.buttonSize
    color: filled ? theme.colorFg : "transparent"
    border.color: theme.colorFg
    border.width: 1
    radius: 0

    Column {
        anchors.centerIn: parent
        spacing: theme.gridUnit

        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.percent < 80 && root.showPercent) ? Math.round(root.percent) + "%" : "POW"
            color: root.filled ? theme.colorBg : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(9)
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            width: label.implicitWidth
            height: theme.gridUnit
            color: "transparent"
            border.width: 1
            border.color: root.filled ? theme.colorBg : theme.colorFg
            // Below 50% the bar flashes in sync with the label blink above.
            visible: root.percent >= 50 || !root.showPercent

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                color: root.filled ? theme.colorBg : theme.levelColor(root.percent)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
