import QtQuick

// [MON]: CPU load as a bar under the label (SysMon.qml), green to red as
// it climbs. Over 80°C the label alternates with the hottest sensor's
// temperature, in red. Hidden by `muthur set monitor.button off`.
Rectangle {
    id: root

    property bool selected: false
    signal clicked()

    Theme { id: theme }

    readonly property bool hot: SysMon.hottest >= 80
    readonly property bool filled: selected || mouseArea.pressed
    property bool showTemp: false

    Timer {
        interval: 2000
        running: root.hot
        repeat: true
        onTriggered: root.showTemp = !root.showTemp
        onRunningChanged: if (!running) root.showTemp = false
    }

    visible: SysMon.store.button
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
            text: root.showTemp ? Math.round(SysMon.hottest) + "°" : "MON"
            color: root.filled ? theme.colorBg : root.showTemp ? theme.colorRed : theme.colorFg
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

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(100, SysMon.cpu)) / 100
                color: root.filled ? theme.colorBg : theme.levelColor(100 - SysMon.cpu)
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
