import QtQuick

// [MSG] with the number of unread Matrix messages under it (Relay.qml);
// in the focus color while there are some. Hidden while relay's daemon
// isn't running.
Rectangle {
    id: root

    property bool selected: false
    signal clicked()

    Theme { id: theme }

    readonly property int count: Relay.unread
    readonly property bool urgent: count > 0
    readonly property bool filled: selected || mouseArea.pressed
    readonly property color ink: filled ? theme.colorBg : urgent ? theme.colorFocus : theme.colorFg

    visible: Relay.available
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
            text: "MSG"
            color: root.ink
            font.family: theme.fontFamily
            font.pixelSize: theme.px(9)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.count > 0
            text: root.count > 99 ? "99+" : String(root.count)
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
