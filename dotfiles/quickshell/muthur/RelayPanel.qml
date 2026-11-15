import QtQuick
import Quickshell

// Opened by clicking [MSG]: Matrix rooms through relay (Relay.qml), most
// recent first; a click opens the conversation, with a line to answer.
// Escape goes back from a conversation to the rooms, then closes. Not
// built on PopupPanel: no tabs.
BarPopup {
    id: root

    requestedWidth: theme.gridUnit * 120
    requestedHeight: theme.gridUnit * 144

    Theme { id: theme }

    readonly property bool inRoom: Relay.currentRoom !== ""

    onVisibleChanged: {
        Relay.panelOpen = visible;
        if (visible && inRoom)
            focusInput.restart();
    }
    onInRoomChanged: if (inRoom) focusInput.restart()

    // After BarPopup has given the Escape catcher focus on opening.
    Timer {
        id: focusInput
        interval: 50
        onTriggered: answer.input.forceActiveFocus()
    }

    function formatTime(ts) {
        const d = new Date(ts);
        const now = new Date();
        const hm = Qt.formatTime(d, "HH:mm");
        return d.toDateString() === now.toDateString() ? hm : Qt.formatDate(d, "dd/MM") + " " + hm;
    }

    Column {
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 4
        spacing: theme.gridUnit * 3

        // Title row: COMMS, or [<] and the room's name.
        Item {
            id: header
            width: parent.width
            height: theme.buttonSize

            TerminalButton {
                id: back
                visible: root.inRoom
                anchors.verticalCenter: parent.verticalCenter
                label: "<"
                square: true
                onClicked: Relay.closeRoom()
            }

            Text {
                anchors.left: root.inRoom ? back.right : parent.left
                anchors.leftMargin: root.inRoom ? theme.gridUnit * 2 : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.inRoom ? (Relay.currentRoomInfo ? Relay.currentRoomInfo.name.toUpperCase() : "…") : "COMMS"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: {
                const s = Relay.status;
                if (!s)
                    return "[ CONNECTING... ]";
                const state = s.verified ? "SESSION VERIFIED"
                    : "SESSION NOT VERIFIED — RUN `relay verify`";
                return s.user_id + " · " + (s.synced ? state : "SYNCING...");
            }
            color: Relay.status && !Relay.status.verified ? theme.colorFocus : theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Item {
            id: body
            width: parent.width
            // Whatever the lines above and the footer below leave.
            height: Math.max(0, parent.height - y - footer.height - parent.spacing)

            // The rooms.
            ListView {
                id: roomList
                visible: !root.inRoom
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width - (roomScroll.needed ? theme.scrollBarWidth + theme.gridUnit : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: Relay.rooms }

                FastScroll { flickable: roomList }

                delegate: Rectangle {
                    id: roomRow

                    required property var modelData

                    width: ListView.view.width
                    height: theme.gridUnit * 6
                    color: roomMouse.containsMouse ? theme.colorFg : "transparent"

                    readonly property color ink: roomMouse.containsMouse ? theme.colorBg
                        : modelData.unread > 0 ? theme.colorFocus : theme.colorFg

                    // Unread count, or nothing.
                    Text {
                        id: count
                        width: theme.gridUnit * 6
                        anchors.left: parent.left
                        anchors.leftMargin: theme.gridUnit
                        anchors.verticalCenter: parent.verticalCenter
                        text: roomRow.modelData.unread > 99 ? "99+" : roomRow.modelData.unread > 0 ? String(roomRow.modelData.unread) : ""
                        color: roomRow.ink
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                    }

                    Text {
                        anchors.left: count.right
                        anchors.right: time.left
                        anchors.rightMargin: theme.gridUnit * 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: roomRow.modelData.name
                        color: roomRow.ink
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                    }

                    Text {
                        id: time
                        anchors.right: parent.right
                        anchors.rightMargin: theme.gridUnit
                        anchors.verticalCenter: parent.verticalCenter
                        text: (roomRow.modelData.encrypted ? "E2E  " : "")
                            + (roomRow.modelData.last_ts > 0 ? root.formatTime(roomRow.modelData.last_ts) : "")
                        color: roomMouse.containsMouse ? theme.colorBg : theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(10)
                    }

                    MouseArea {
                        id: roomMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Relay.openRoom(roomRow.modelData.id)
                    }
                }
            }

            TerminalScrollBar {
                id: roomScroll
                visible: needed && !root.inRoom
                flickable: roomList
            }

            // The open conversation, newest at the bottom.
            ListView {
                id: messageList
                visible: root.inRoom
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width - (messageScroll.needed ? theme.scrollBarWidth + theme.gridUnit : 0)
                clip: true
                spacing: theme.gridUnit * 2
                boundsBehavior: Flickable.StopAtBounds
                verticalLayoutDirection: ListView.TopToBottom
                model: ScriptModel {
                    values: Relay.messages
                    objectProp: "id"
                }

                // Follow new messages unless scrolled up to read.
                property bool pinned: true
                onMovementEnded: pinned = atYEnd
                onCountChanged: if (pinned) Qt.callLater(positionViewAtEnd)
                Connections {
                    target: Relay
                    function onCurrentRoomChanged() { messageList.pinned = true; }
                }

                FastScroll { flickable: messageList }

                delegate: Column {
                    id: msg

                    required property var modelData

                    width: ListView.view.width
                    spacing: theme.gridUnit / 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.formatTime(msg.modelData.ts) + "  "
                            + (msg.modelData.own ? "YOU" : msg.modelData.sender_name.toUpperCase())
                        color: msg.modelData.own ? theme.colorDim : theme.colorFocus
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(10)
                        font.letterSpacing: theme.letterSpacing
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: msg.modelData.undecryptable ? "[ UNABLE TO DECRYPT — KEYS MISSING ]"
                            : (msg.modelData.msgtype === "m.emote" ? "* " + msg.modelData.sender_name + " " : "")
                              + msg.modelData.body + (msg.modelData.edit ? "  (edited)" : "")
                        color: msg.modelData.undecryptable ? theme.colorDim : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: messageList.count === 0
                    text: Relay.loading ? "[ RECEIVING... ]" : "[ NO MESSAGES ]"
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }
            }

            TerminalScrollBar {
                id: messageScroll
                visible: needed && root.inRoom
                flickable: messageList
            }
        }

        Column {
            id: footer
            width: parent.width
            spacing: theme.gridUnit * 2

            Text {
                visible: Relay.error.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                text: Relay.error
                color: theme.colorFocus
                font.family: theme.fontFamily
                font.pixelSize: theme.px(10)
            }

            Field {
                id: answer
                visible: root.inRoom
                width: parent.width
                placeholder: "TRANSMIT..."

                onEscapePressed: event => {
                    event.accepted = true;
                    Relay.closeRoom();
                }

                Connections {
                    target: answer.input
                    function onAccepted() {
                        Relay.send(answer.input.text);
                        answer.input.text = "";
                    }
                }
            }
        }
    }
}
