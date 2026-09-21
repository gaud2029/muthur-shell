import QtQuick
import Quickshell
import Quickshell.Wayland

// Open-window list fed by wlr-foreign-toplevel-management, so it works on
// any wlroots compositor without an IPC bridge. Lays out along the bar's
// axis. On a horizontal bar entries stretch to show their title, sharing
// `lengthBudget` equally and shrinking to a 2-letter app-id tile when
// there isn't room; a vertical bar always shows the tiles.
AxisGrid {
    id: root

    property var hovered: null
    // Total length along the bar the entries may occupy, set by Bar.
    property real lengthBudget: 0
    readonly property int maxTitleChars: 75

    spacing: theme.gridUnit

    Theme { id: theme }

    readonly property real share: entries.count > 0
        ? (lengthBudget - spacing * (entries.count - 1)) / entries.count
        : 0

    function abbreviate(appId) {
        const leaf = (appId || "?").split(".").pop();
        return leaf.substring(0, 2).toUpperCase();
    }

    Repeater {
        id: entries
        model: ToplevelManager.toplevels

        Rectangle {
            id: entry
            required property Toplevel modelData

            readonly property bool focused: modelData.activated
            readonly property bool filled: focused || mouseArea.pressed
            readonly property color fg: filled ? theme.colorBg
                                      : modelData.minimized ? theme.colorDim : theme.colorFg

            readonly property string title: (modelData.title || "").substring(0, root.maxTitleChars)
            readonly property real wanted: titleText.implicitWidth + theme.gridUnit * 2
            readonly property real length: root.vertical ? theme.tile : Math.max(theme.tile, Math.min(wanted, root.share))
            readonly property bool showTitle: !root.vertical && length >= theme.tile * 2

            width: length
            height: theme.tile
            color: filled ? theme.colorFg : "transparent"
            border.color: modelData.minimized ? theme.colorDim : theme.colorFg
            border.width: 1

            Text {
                id: titleText
                anchors.centerIn: parent
                width: entry.length - theme.gridUnit * 2
                visible: entry.showTitle
                text: entry.title
                elide: Text.ElideRight
                color: entry.fg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
            }

            Text {
                anchors.centerIn: parent
                visible: !entry.showTitle
                text: root.abbreviate(entry.modelData.appId)
                color: entry.fg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(10)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onEntered: root.hovered = entry
                onExited: if (root.hovered === entry) root.hovered = null
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton)
                        entry.modelData.close();
                    else
                        entry.modelData.activate();
                }
            }
        }
    }

    PopupWindow {
        visible: root.hovered !== null
        color: "transparent"
        implicitWidth: tooltip.implicitWidth
        implicitHeight: tooltip.implicitHeight

        // Opens on the side of the entry that faces the desktop.
        readonly property int side: {
            switch (theme.barPosition) {
            case "left": return Edges.Right;
            case "right": return Edges.Left;
            case "top": return Edges.Bottom;
            default: return Edges.Top;
            }
        }

        anchor {
            item: root.hovered
            edges: side
            gravity: side
            margins.left: side === Edges.Right ? theme.gridUnit * 2 : 0
            margins.right: side === Edges.Left ? theme.gridUnit * 2 : 0
            margins.top: side === Edges.Bottom ? theme.gridUnit * 2 : 0
            margins.bottom: side === Edges.Top ? theme.gridUnit * 2 : 0
        }

        Rectangle {
            id: tooltip
            implicitWidth: tooltipText.implicitWidth + theme.gridUnit * 4
            implicitHeight: tooltipText.implicitHeight + theme.gridUnit * 2
            color: theme.colorBg
            border.color: theme.colorFg
            border.width: 1

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: root.hovered ? root.hovered.modelData.title : ""
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
        }
    }
}
