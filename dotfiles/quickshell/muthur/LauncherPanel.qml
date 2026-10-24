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
//
// The [?] in the prompt's corner lists the prefix modes (= : !).
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
    property bool helpShown: false
    readonly property var results: Launcher.results
    readonly property int rows: 10

    onResultsChanged: selected = 0

    // Hovering selects, but only once the pointer has moved: the list
    // appearing (or changing) under a still pointer reports a hover too,
    // which would steal the selection from the keyboard.
    property point pointer: Qt.point(-1, -1)

    function hovered(row, mouse) {
        const p = row.mapToItem(null, mouse.x, mouse.y);
        const moved = pointer.x >= 0 && (p.x !== pointer.x || p.y !== pointer.y);
        pointer = p;
        if (moved)
            selected = row.index;
    }

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

    Connections {
        target: Launcher

        function onCompleteRequested(text) {
            input.text = text;
            input.cursorPosition = text.length;
        }
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

                // The help, in the corner.
                Text {
                    id: helpButton
                    anchors.right: parent.right
                    anchors.rightMargin: theme.gridUnit * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "[?]"
                    color: root.helpShown || helpArea.containsMouse ? theme.colorFg : theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(10)

                    MouseArea {
                        id: helpArea
                        anchors.fill: parent
                        anchors.margins: -theme.gridUnit
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.helpShown = !root.helpShown
                    }
                }

                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: theme.gridUnit * 2
                    anchors.right: helpButton.left
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

                    Keys.onEscapePressed: {
                        if (root.helpShown)
                            root.helpShown = false;
                        else
                            Launcher.close();
                    }
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

            // The prefix modes, in place of the list while [?] is on.
            Column {
                visible: root.helpShown
                width: parent.width
                topPadding: theme.gridUnit * 3
                bottomPadding: theme.gridUnit * 3
                spacing: theme.gridUnit * 3

                Repeater {
                    model: [
                        { prefix: "=", title: "CALCULATE", lines: ["= 2^10 / 3      = sqrt(2) * pi      = ln(10)", "+ - * / % ^ ( )  sqrt abs round floor ceil sin cos tan log ln exp min max pi e", "ENTER COPIES THE RESULT"] },
                        { prefix: ":", title: "SETTINGS", lines: [":night            lists the keys and their value", ":look.preset tron   sets one (the muthur set settings)", "ENTER COMPLETES A KEY, OR TOGGLES AN ON/OFF ONE"] },
                        { prefix: "!", title: "SESSION", lines: ["!update   !lock   !logout   !suspend   !reboot   !power", "ENTER TWICE TO CONFIRM (BUT UPDATE AND LOCK)"] }
                    ]

                    Item {
                        id: mode

                        required property var modelData

                        width: parent.width
                        height: lines.implicitHeight

                        Text {
                            x: theme.gridUnit * 3
                            text: mode.modelData.prefix
                            color: theme.colorFg
                            font.family: theme.fontFamily
                            font.pixelSize: theme.px(16)
                        }

                        Column {
                            id: lines
                            x: theme.gridUnit * 10
                            width: parent.width - x - theme.gridUnit * 3
                            spacing: theme.gridUnit

                            Text {
                                text: mode.modelData.title
                                color: theme.colorFg
                                font.family: theme.fontFamily
                                font.pixelSize: theme.px(11)
                                font.letterSpacing: theme.letterSpacing
                            }

                            Repeater {
                                model: mode.modelData.lines

                                Text {
                                    required property string modelData
                                    width: lines.width
                                    wrapMode: Text.Wrap
                                    text: modelData
                                    color: theme.colorDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: theme.px(11)
                                }
                            }
                        }
                    }
                }
            }

            ListView {
                id: list
                visible: !root.helpShown
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
                        onPositionChanged: mouse => root.hovered(row, mouse)
                        onClicked: Launcher.launch(row.modelData, false)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
                visible: root.helpShown || root.results.length > 0
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
                    text: root.helpShown
                        ? "[?] OR ESC CLOSES THE HELP"
                        : Launcher.message
                        ? "ERROR: " + Launcher.message
                        : root.results.length + (root.results.length === 1 ? " MATCH" : " MATCHES") + "   ENTER RUN · SHIFT TERM · CTRL AS CMD"
                    color: Launcher.message ? theme.colorRed : theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(10)
                    font.letterSpacing: theme.letterSpacing
                }
            }
        }
    }
}
