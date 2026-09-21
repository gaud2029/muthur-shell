import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool selected: false
    // Bar buttons are all the same theme.buttonSize square; panel buttons
    // grow with their label.
    property bool square: false
    signal clicked()

    Theme { id: theme }

    readonly property bool filled: selected || mouseArea.pressed

    implicitWidth: square ? theme.buttonSize : Math.max(theme.buttonSize, label_.implicitWidth + theme.gridUnit * 2)
    implicitHeight: theme.buttonSize
    color: filled ? theme.colorFg : "transparent"
    border.color: theme.colorFg
    border.width: 1
    radius: 0

    Text {
        id: label_
        anchors.centerIn: parent
        text: root.label
        color: root.filled ? theme.colorBg : theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: root.square ? 0 : theme.letterSpacing
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
