import QtQuick

Item {
    id: root

    property string hh: Qt.formatDateTime(new Date(), "HH")
    property string mm: Qt.formatDateTime(new Date(), "mm")
    property bool active: false
    signal clicked()

    implicitWidth: digits.width
    implicitHeight: digits.height

    Theme { id: theme }

    // HH over MM on a vertical bar, side by side on a horizontal one.
    AxisGrid {
        id: digits
        spacing: theme.gridUnit

        Text {
            text: root.hh
            width: theme.px(25)
            horizontalAlignment: Text.AlignHCenter
            color: root.active ? theme.colorFocus : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            text: root.mm
            width: theme.px(25)
            horizontalAlignment: Text.AlignHCenter
            color: root.active ? theme.colorFocus : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.hh = Qt.formatDateTime(new Date(), "HH");
            root.mm = Qt.formatDateTime(new Date(), "mm");
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
