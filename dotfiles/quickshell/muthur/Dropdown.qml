import QtQuick

// A closed field showing the current choice; clicking it unfolds the
// options inline below it (pushing the rest of the tab down) rather than
// in a popup layer the panel's Flickable would clip. Past `maxRows`
// options the list scrolls.
Column {
    id: root
    // Overlap neighbouring borders so rows share a 1px line.
    spacing: -1

    property var current: null
    // The options, as a JS array.
    property var options: []
    property var labelFor: v => v ? String(v) : "-"
    // The face each option is drawn in; a font picker previews them.
    property var fontFor: v => theme.fontFamily
    property int maxRows: 8
    property bool open: false
    signal picked(var value)

    readonly property int rowHeight: theme.gridUnit * 6

    Theme { id: theme }

    Rectangle {
        width: root.width
        height: root.rowHeight
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
            text: root.labelFor(root.current)
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

    Item {
        visible: root.open
        width: root.width
        height: visible ? list.height : 0

        ListView {
            id: list
            readonly property bool scrolls: root.options.length > root.maxRows

            width: scrolls ? parent.width - theme.gridUnit * 2 : parent.width
            // Rows overlap by 1px, like the Column above.
            height: Math.min(root.options.length, root.maxRows) * (root.rowHeight - 1) + 1
            spacing: -1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.options

            // Scroll the current option into view on opening, and again
            // when the options are replaced while open (a model reset
            // scrolls back to the top).
            function showCurrent() {
                if (visible)
                    positionViewAtIndex(Math.max(0, root.options.indexOf(root.current)), ListView.Center);
            }
            onVisibleChanged: showCurrent()
            onCountChanged: showCurrent()
            onModelChanged: showCurrent()

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool isCurrent: modelData === root.current
                width: list.width
                height: root.rowHeight
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
                    text: (row.isCurrent ? "> " : "  ") + root.labelFor(row.modelData)
                    color: row.isCurrent ? theme.colorFocus : theme.colorFg
                    font.family: root.fontFor(row.modelData)
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

        TerminalScrollBar { flickable: list }
    }
}
