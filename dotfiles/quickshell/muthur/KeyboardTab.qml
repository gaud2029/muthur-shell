import QtQuick

// [SYS] KEYBOARD: the configured layouts (click one to make it active,
// the bar button cycles through them), a search over every layout xkb
// knows to add more, and key repeat. See Keyboard.qml.
Item {
    id: root

    Theme { id: theme }

    component SectionHeader: Text {
        color: theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSize
        font.letterSpacing: theme.letterSpacing
    }

    component Hint: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }

    // A bordered one-line input with a dim placeholder.
    component Field: Rectangle {
        property alias input: input_
        property string placeholder: ""

        height: theme.buttonSize
        color: "transparent"
        border.color: input_.activeFocus ? theme.colorFocus : theme.colorDim
        border.width: 1

        TextInput {
            id: input_
            anchors.fill: parent
            anchors.margins: theme.gridUnit * 2
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: theme.colorFg
            selectionColor: theme.colorDim
            selectedTextColor: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(12)

            Text {
                anchors.fill: parent
                visible: !input_.text && !input_.activeFocus
                verticalAlignment: Text.AlignVCenter
                text: parent.parent.placeholder
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
                font.letterSpacing: theme.letterSpacing
            }
        }
    }

    // Matches for the search, minus the layouts already configured.
    readonly property string query: search.input.text.trim().toLowerCase()
    readonly property var matches: query.length === 0 ? []
        : Keyboard.catalog.filter(e => !Keyboard.layouts.includes(e.key)
            && (e.name.toLowerCase().includes(query) || e.key.toLowerCase().includes(query)))

    // Adding a match, or clearing the search, rebuilds the matches and
    // destroys the clicked row mid-handler, so the row hands off to here.
    // Clearing the search closes the list.
    function pick(key) {
        search.input.text = "";
        search.input.focus = false;
        Keyboard.add(key);
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 3
        anchors.rightMargin: theme.gridUnit * 5
        contentWidth: width
        contentHeight: column.height
        clip: true

        FastScroll { flickable: scroller }

        Column {
            id: column
            width: parent.width
            spacing: theme.gridUnit * 2

            SectionHeader { text: "LAYOUTS" }

            Hint {
                text: Keyboard.layouts.length > 1
                    ? "CLICK ONE TO SWITCH TO IT. THE BAR BUTTON CYCLES THROUGH THEM."
                    : "ADD A SECOND LAYOUT BELOW TO SWITCH BETWEEN THEM FROM THE BAR."
            }

            Repeater {
                model: Keyboard.layouts

                Rectangle {
                    id: layoutRow
                    required property string modelData
                    required property int index
                    readonly property bool active: index === Keyboard.active

                    width: parent ? parent.width : 0
                    height: theme.gridUnit * 8
                    color: rowMouse.containsMouse && !active ? Qt.alpha(theme.colorFg, 0.15) : "transparent"
                    border.color: active ? theme.colorFocus : theme.colorDim
                    border.width: 1

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: layoutRow.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: Keyboard.select(layoutRow.index)
                    }

                    Text {
                        id: code
                        anchors.left: parent.left
                        anchors.leftMargin: theme.gridUnit * 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: theme.gridUnit * 12
                        text: (layoutRow.active ? "> " : "  ") + Keyboard.shortLabel(layoutRow.modelData)
                        color: layoutRow.active ? theme.colorFocus : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                        font.letterSpacing: theme.letterSpacing
                    }

                    Text {
                        anchors.left: code.right
                        anchors.right: removeButton.left
                        anchors.rightMargin: theme.gridUnit * 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: Keyboard.describe(layoutRow.modelData)
                        color: layoutRow.active ? theme.colorFocus : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                    }

                    TerminalButton {
                        id: removeButton
                        anchors.right: parent.right
                        anchors.rightMargin: theme.gridUnit
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Keyboard.layouts.length > 1
                        label: "REMOVE"
                        onClicked: Keyboard.remove(layoutRow.index)
                    }
                }
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "ADD LAYOUT" }

            Field {
                id: search
                width: parent.width
                placeholder: "SEARCH: FRENCH, CANADA, DVORAK, DE..."
            }

            Hint {
                visible: root.query.length > 0 && root.matches.length === 0
                text: "[ NO MATCHING LAYOUT ]"
            }

            // Click a match to add it; the search clears for the next one.
            Item {
                visible: results.count > 0
                width: parent.width
                height: visible ? results.height : 0

                ListView {
                    id: results
                    readonly property int rowHeight: theme.gridUnit * 6
                    readonly property int maxRows: 8
                    readonly property bool scrolls: count > maxRows

                    width: scrolls ? parent.width - theme.gridUnit - theme.px(8) : parent.width
                    // Rows overlap by 1px so neighbours share a border.
                    height: Math.min(count, maxRows) * (rowHeight - 1) + 1
                    spacing: -1
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.matches

                    FastScroll { flickable: results; notch: 90 }

                    delegate: Rectangle {
                        id: match
                        required property var modelData
                        width: results.width
                        height: results.rowHeight
                        color: matchMouse.containsMouse ? Qt.alpha(theme.colorFg, 0.15) : "transparent"
                        border.color: theme.colorFg
                        border.width: 1

                        Text {
                            id: matchKey
                            anchors.right: parent.right
                            anchors.rightMargin: theme.gridUnit * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: match.modelData.key
                            color: theme.colorDim
                            font.family: theme.fontFamily
                            font.pixelSize: theme.px(11)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: matchKey.left
                            anchors.leftMargin: theme.gridUnit * 2
                            anchors.rightMargin: theme.gridUnit * 2
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: "+ " + match.modelData.name
                            color: theme.colorFg
                            font.family: theme.fontFamily
                            font.pixelSize: theme.px(11)
                            font.letterSpacing: theme.letterSpacing
                        }

                        MouseArea {
                            id: matchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(match.modelData.key)
                        }
                    }
                }

                TerminalScrollBar { flickable: results }
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "KEY REPEAT" }

            VolumeSlider {
                width: parent.width
                label: "RATE"
                readout: Keyboard.repeatRate + " /S"
                value: (Keyboard.repeatRate - Keyboard.minRepeatRate) / (Keyboard.maxRepeatRate - Keyboard.minRepeatRate)
                onMoved: v => Keyboard.setRepeat(
                    Keyboard.minRepeatRate + v * (Keyboard.maxRepeatRate - Keyboard.minRepeatRate),
                    Keyboard.repeatDelay)
            }

            VolumeSlider {
                width: parent.width
                label: "DELAY"
                readout: Keyboard.repeatDelay + " MS"
                value: (Keyboard.repeatDelay - Keyboard.minRepeatDelay) / (Keyboard.maxRepeatDelay - Keyboard.minRepeatDelay)
                onMoved: v => Keyboard.setRepeat(
                    Keyboard.repeatRate,
                    Keyboard.minRepeatDelay + v * (Keyboard.maxRepeatDelay - Keyboard.minRepeatDelay))
            }

            Field {
                width: parent.width
                placeholder: "TEST: HOLD A KEY HERE"
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "TYPING SOUND" }

            Hint {
                text: "AN AMBIENCE WHILE YOU TYPE: EACH KEY SOUNDS WHERE IT IS, LEFT TO RIGHT, OVER AN AMBIENCE THAT SWELLS AS YOU GO. BEST ON HEADPHONES."
            }

            Flow {
                width: parent.width
                spacing: theme.gridUnit * 2

                Repeater {
                    model: Keyboard.soundThemes

                    TerminalButton {
                        required property var modelData
                        label: modelData.label
                        selected: Keyboard.soundTheme === modelData.key
                        onClicked: Keyboard.setSoundTheme(modelData.key)
                    }
                }
            }

            Hint {
                visible: text.length > 0
                color: theme.colorFg
                text: (Keyboard.soundThemes.find(t => t.key === Keyboard.soundTheme) || {}).about || ""
            }

            Text {
                visible: Keyboard.soundTheme !== "off"
                text: "AMBIENCE"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Flow {
                visible: Keyboard.soundTheme !== "off"
                width: parent.width
                spacing: theme.gridUnit * 2

                Repeater {
                    model: Keyboard.soundAmbiences

                    TerminalButton {
                        required property var modelData
                        label: modelData.label
                        selected: Keyboard.soundAmbienceType === modelData.key
                        onClicked: Keyboard.setSoundAmbienceType(modelData.key)
                    }
                }
            }

            Hint {
                visible: Keyboard.soundTheme !== "off"
                color: theme.colorFg
                text: (Keyboard.soundAmbiences.find(a => a.key === Keyboard.soundAmbienceType) || {}).about || ""
            }

            VolumeSlider {
                visible: Keyboard.soundTheme !== "off"
                width: parent.width
                label: "VOLUME"
                value: Keyboard.soundVolume / 100
                onMoved: v => Keyboard.setSoundVolume(v * 100)
            }

            VolumeSlider {
                visible: Keyboard.soundTheme !== "off"
                width: parent.width
                label: "AMBIENCE LEVEL"
                value: Keyboard.soundAmbience / 100
                onMoved: v => Keyboard.setSoundAmbience(v * 100)
            }

            // Whether the player and the keypress feed are there.
            Row {
                visible: Keyboard.soundTheme !== "off"
                width: parent.width
                spacing: theme.gridUnit * 2

                TerminalButton {
                    id: testButton
                    label: "TEST"
                    visible: Keyboard.soundStatus === "connected" || Keyboard.soundStatus === "waiting"
                    onClicked: Keyboard.testSound()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (testButton.visible ? testButton.width + theme.gridUnit * 2 : 0)
                    wrapMode: Text.WordWrap
                    text: ({
                        starting: "STARTING PLAYER...",
                        connected: "INPUT LINK ACTIVE.",
                        waiting: "NO INPUT LINK: THE KEYPRESS SERVICE ISN'T RUNNING. RUN dotfiles/keysound/install-keysound.sh",
                        missing: "PLAYER NOT INSTALLED. RUN dotfiles/keysound/install-keysound.sh"
                    })[Keyboard.soundStatus] || ""
                    color: Keyboard.soundStatus === "connected" ? theme.colorGreen
                         : Keyboard.soundStatus === "starting" ? theme.colorDim : theme.colorYellow
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
