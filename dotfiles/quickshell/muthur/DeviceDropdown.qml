import QtQuick
import Quickshell.Services.Pipewire

// A closed field showing the current Pipewire device; clicking it unfolds
// the matching devices inline below it (pushing the rest of the tab down)
// rather than in a popup layer the panel's Flickable would clip.
Column {
    id: root
    // Overlap neighbouring borders so rows share a 1px line.
    spacing: -1

    property var current: null
    // Which Pipewire nodes belong in the list.
    property var accepts: node => false
    property bool open: false
    signal picked(var node)

    function deviceLabel(n) {
        return n ? (n.description || n.nickname || n.name) : "-";
    }

    Theme { id: theme }

    Rectangle {
        width: root.width
        height: theme.gridUnit * 6
        color: root.open ? theme.colorFg : "transparent"
        border.color: theme.colorFg
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: theme.gridUnit * 2
            anchors.rightMargin: theme.gridUnit * 2
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.deviceLabel(root.current)
            color: root.open ? theme.colorBg : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: theme.gridUnit * 2
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "▲" : "▼"
            color: root.open ? theme.colorBg : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(9)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Repeater {
        model: Pipewire.nodes

        Rectangle {
            id: row
            required property var modelData
            readonly property bool isCurrent: modelData === root.current
            visible: root.open && root.accepts(modelData)
            width: root.width
            height: visible ? theme.gridUnit * 6 : 0
            color: rowMouse.containsMouse ? Qt.alpha(theme.colorFg, 0.15) : "transparent"
            border.color: theme.colorFg
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: theme.gridUnit * 2
                anchors.rightMargin: theme.gridUnit * 2
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: (row.isCurrent ? "> " : "  ") + root.deviceLabel(row.modelData)
                color: row.isCurrent ? theme.colorFocus : theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.open = false;
                    if (!row.isCurrent) root.picked(row.modelData);
                }
            }
        }
    }
}
