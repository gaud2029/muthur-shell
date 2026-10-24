import QtQuick
import Quickshell
import Quickshell.Wayland

// The launcher's window (Launcher.qml has the state): a `>_` prompt over
// the matching entries, in the bar's start corner by the focus-mode
// cursor. It covers the screen beside the bar, see-through, so a click
// anywhere outside the box closes it; it takes the keyboard while open.
//
//   Enter          launch the selected entry
//   Shift+Enter    the same, in a terminal that stays open
//   Ctrl+Enter     run the typed text as a command, whatever matched
//   Up/Down, Ctrl+P/N, Tab    move;  Escape  close
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === (Launcher.screenName || ThemeStore.mainScreen)) || Quickshell.screens[0]

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    // Not Ignore: that would cover the bar too.
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "muthur-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Theme { id: theme }

    property int selected: 0
    readonly property var results: Launcher.results
    readonly property int rows: 10

    onResultsChanged: selected = 0

    function move(delta) {
        if (results.length === 0)
            return;
        selected = (selected + delta + results.length) % results.length;
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.close()
    }

    Rectangle {
        id: box

        width: Math.min(theme.gridUnit * 110, root.width)
        height: Math.min(column.implicitHeight + 2, root.height)
        // Flush against the bar, at its start (where the cursor is).
        x: theme.barPosition === "right" ? root.width - width : 0
        y: theme.barPosition === "bottom" ? root.height - height : 0
        color: theme.colorBg
        border.color: theme.colorFg
        border.width: 1

        // Clicks inside stay inside.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2

            // The prompt.
            Item {
                width: parent.width
                height: theme.barThickness

                Text {
                    id: prompt
                    x: theme.gridUnit * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">_"
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(13)
                }

                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: theme.gridUnit * 2
                    anchors.right: parent.right
                    anchors.rightMargin: theme.gridUnit * 3
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: theme.colorFg
                    selectionColor: theme.colorDim
                    selectedTextColor: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(13)
                    focus: true
                    onTextChanged: Launcher.query = text

                    Text {
                        anchors.fill: parent
                        visible: !input.text
                        verticalAlignment: Text.AlignVCenter
                        text: "ENTER INQUIRY"
                        color: theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(13)
                        font.letterSpacing: theme.letterSpacing
                    }

                    Keys.onEscapePressed: Launcher.close()
                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onTabPressed: root.move(1)
                    Keys.onBacktabPressed: root.move(-1)
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        const shift = event.modifiers & Qt.ShiftModifier;
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (ctrl)
                                Launcher.runQuery(shift);
                            else
                                Launcher.launch(root.results[root.selected], shift);
                            event.accepted = true;
                        } else if (ctrl && event.key === Qt.Key_N) {
                            root.move(1);
                            event.accepted = true;
                        } else if (ctrl && event.key === Qt.Key_P) {
                            root.move(-1);
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(root.results.length, root.rows) * theme.buttonSize
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.results

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected

                    width: ListView.view.width
                    height: theme.buttonSize
                    color: current ? theme.colorFg : "transparent"

                    Text {
                        id: tag
                        x: theme.gridUnit * 3
                        width: theme.gridUnit * 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.tag
                        color: row.current ? theme.colorBg : theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                        font.letterSpacing: theme.letterSpacing
                    }

                    Text {
                        id: label
                        anchors.left: tag.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, row.width - tag.x - tag.width - theme.gridUnit * 3)
                        elide: Text.ElideRight
                        text: row.modelData.label
                        color: row.current ? theme.colorBg : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                    }

                    Text {
                        anchors.left: label.right
                        anchors.leftMargin: theme.gridUnit * 3
                        anchors.right: parent.right
                        anchors.rightMargin: theme.gridUnit * 3
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.detail || ""
                        color: row.current ? theme.colorBg : theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: Launcher.launch(row.modelData, false)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
                visible: root.results.length > 0
            }

            // Status line.
            Item {
                width: parent.width
                height: theme.buttonSize

                Text {
                    x: theme.gridUnit * 3
                    width: parent.width - theme.gridUnit * 6
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.results.length + (root.results.length === 1 ? " MATCH" : " MATCHES") + "   ENTER RUN · SHIFT TERM · CTRL AS CMD"
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(10)
                    font.letterSpacing: theme.letterSpacing
                }
            }
        }
    }
}
