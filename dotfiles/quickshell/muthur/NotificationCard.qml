import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification as a terminal box, for the popups and the drawer's
// history. The border and header follow the urgency: dim for low, the
// ink for normal, red for critical. A click opens the sender, a right
// click (or [X]) dismisses; actions and the inline reply sit underneath.
Rectangle {
    id: root

    required property var notification
    // The notification's properties, or blanks while the card outlives a
    // notification that just closed.
    readonly property var n: notification || ({
        urgency: NotificationUrgency.Normal, appName: "", appIcon: "", image: "",
        summary: "", body: "", actions: [], resident: false,
        hasInlineReply: false, inlineReplyPlaceholder: ""
    })
    // Fewer body lines in the history.
    property int bodyLines: 4
    readonly property bool hovered: hover.hovered
    readonly property bool replying: replyRow.visible

    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property bool low: n.urgency === NotificationUrgency.Low
    readonly property color accent: critical ? theme.colorRed : low ? theme.colorDim : theme.colorFg

    readonly property var buttons: n.actions.filter(a => a.identifier !== "default" && a.text)
    readonly property string iconSource: {
        if (n.image)
            return n.image;
        if (!n.appIcon)
            return "";
        if (n.appIcon.startsWith("/"))
            return "file://" + n.appIcon;
        if (n.appIcon.includes("://"))
            return n.appIcon;
        return Quickshell.iconPath(n.appIcon, true);
    }

    implicitHeight: column.implicitHeight + theme.gridUnit * 4
    color: theme.colorBg
    border.color: accent
    border.width: critical ? 2 : 1

    Theme { id: theme }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton
            ? Notifications.dismiss(root.notification)
            : Notifications.open(root.notification)
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: theme.gridUnit * 2
        spacing: theme.gridUnit

        // PRIORITY ONE // DISCORD                    14:32 [X]
        Item {
            width: parent.width
            height: closeButton.height

            Row {
                anchors.left: parent.left
                anchors.right: tail.left
                anchors.rightMargin: theme.gridUnit
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.gridUnit

                IconImage {
                    id: icon
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: theme.px(14)
                    source: root.iconSource
                    visible: root.iconSource !== ""
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (icon.visible ? icon.width + parent.spacing : 0)
                    elide: Text.ElideRight
                    text: (root.critical ? "PRIORITY ONE" : root.low ? "LOG" : "INCOMING")
                        + " // " + (root.n.appName || "UNKNOWN").toUpperCase()
                    color: root.accent
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }
            }

            Row {
                id: tail
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.gridUnit

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var at: Notifications.receivedAt(root.notification)
                    text: at ? Qt.formatTime(at, "HH:mm") : ""
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                }

                Rectangle {
                    id: closeButton
                    width: theme.tile
                    height: theme.tile
                    color: closeArea.pressed ? theme.colorFg : "transparent"
                    border.color: theme.colorDim
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        color: closeArea.pressed ? theme.colorBg : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(10)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.dismiss(root.notification)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.n.summary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            color: root.critical ? theme.colorRed : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.n.body
            wrapMode: Text.Wrap
            maximumLineCount: root.bodyLines
            elide: Text.ElideRight
            textFormat: Text.StyledText
            linkColor: theme.colorFocus
            onLinkActivated: link => Qt.openUrlExternally(link)
            color: root.low ? theme.colorDim : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
        }

        Flow {
            width: parent.width
            spacing: theme.gridUnit
            visible: root.buttons.length > 0 || (root.n.hasInlineReply && !replyRow.visible)
            topPadding: theme.gridUnit

            Repeater {
                model: root.buttons

                TerminalButton {
                    required property var modelData
                    label: modelData.text.toUpperCase()
                    onClicked: Notifications.invoke(modelData, root.notification)
                }
            }

            TerminalButton {
                label: "REPLY"
                visible: root.n.hasInlineReply && !replyRow.visible
                onClicked: {
                    replyRow.visible = true;
                    replyInput.forceActiveFocus();
                }
            }
        }

        // > _                                              [SEND]
        Row {
            id: replyRow
            visible: false
            width: parent.width
            spacing: theme.gridUnit
            topPadding: theme.gridUnit

            function send() {
                if (replyInput.text === "")
                    return;
                // Closes a non-resident notification by itself.
                root.notification.sendInlineReply(replyInput.text);
                replyInput.text = "";
                visible = false;
            }

            Rectangle {
                width: parent.width - sendButton.width - parent.spacing
                height: theme.buttonSize
                color: "transparent"
                border.color: replyInput.activeFocus ? theme.colorFocus : theme.colorDim
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: theme.gridUnit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: replyInput.text === ""
                    text: "> " + (root.n.inlineReplyPlaceholder || "REPLY").toUpperCase()
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                TextInput {
                    id: replyInput
                    anchors.fill: parent
                    anchors.leftMargin: theme.gridUnit
                    anchors.rightMargin: theme.gridUnit
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: theme.colorFg
                    selectionColor: theme.colorFg
                    selectedTextColor: theme.colorBg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    onAccepted: replyRow.send()
                    Keys.onEscapePressed: {
                        text = "";
                        replyRow.visible = false;
                    }
                }
            }

            TerminalButton {
                id: sendButton
                label: "SEND"
                onClicked: replyRow.send()
            }
        }
    }
}
