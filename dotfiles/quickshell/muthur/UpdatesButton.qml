import QtQuick

// [UPD] with the number of pending updates under it (Updates.qml);
// hidden while there are none and no reboot is pending. In the focus
// color when a kernel, systemd, mesa... update is among them, or a new
// kernel waits for a reboot.
Rectangle {
    id: root

    property bool selected: false
    signal clicked()

    Theme { id: theme }

    readonly property int count: Updates.packages.length
    readonly property bool urgent: Updates.importantCount > 0 || Updates.rebootRequired
    readonly property bool filled: selected || mouseArea.pressed
    readonly property color ink: filled ? theme.colorBg : urgent ? theme.colorFocus : theme.colorFg

    visible: count > 0 || Updates.rebootRequired
    implicitWidth: theme.buttonSize
    implicitHeight: theme.buttonSize
    color: filled ? (urgent ? theme.colorFocus : theme.colorFg) : "transparent"
    border.color: urgent ? theme.colorFocus : theme.colorFg
    border.width: 1
    radius: 0

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "UPD"
            color: root.ink
            font.family: theme.fontFamily
            font.pixelSize: theme.px(9)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.count > 999 ? "999+" : root.count > 0 ? String(root.count) : "RBT"
            color: root.ink
            font.family: theme.fontFamily
            font.pixelSize: theme.px(9)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
