import QtQuick

// A draggable 0.0-1.0 volume bar in the same visual language as
// UsageBar's read-only progress track.
Item {
    id: root

    property string label: ""
    property real value: 0
    signal moved(real value)

    Theme { id: theme }

    implicitHeight: theme.px(35)

    function valueAt(x) {
        return Math.max(0, Math.min(1, x / track.width));
    }

    Column {
        anchors.fill: parent
        spacing: theme.gridUnit

        Item {
            width: parent.width
            height: theme.gridUnit * 3

            Text {
                id: percentText
                anchors.right: parent.right
                text: Math.round(root.value * 100) + "%"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
            }

            Text {
                anchors.left: parent.left
                anchors.right: percentText.left
                anchors.rightMargin: theme.gridUnit * 2
                elide: Text.ElideRight
                text: root.label
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
                font.letterSpacing: theme.letterSpacing
            }
        }

        Rectangle {
            id: track
            width: parent.width
            height: theme.gridUnit * 2
            color: "transparent"
            border.color: theme.colorFg
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, root.value))
                color: theme.colorCyan
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => root.moved(root.valueAt(mouse.x))
                onPositionChanged: mouse => {
                    if (pressed) root.moved(root.valueAt(mouse.x));
                }
            }
        }
    }
}
