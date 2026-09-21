import QtQuick

// The [AI] button. When a default agent is chosen in the AI panel it
// carries that agent's 5-hour session bar under the label, the way [POW]
// carries the charge level; otherwise it's a plain square button.
Rectangle {
    id: root

    property bool selected: false
    signal clicked()

    Theme { id: theme }

    readonly property string agent: ThemeStore.defaultAgent
    readonly property var usage: agent === "claude" ? ClaudeUsage : agent === "codex" ? CodexUsage : null
    readonly property bool showBar: !!usage && usage.ready
    readonly property real remaining: showBar ? usage.sessionRemaining : 0
    readonly property bool filled: selected || mouseArea.pressed
    readonly property color fg: filled ? theme.colorBg : theme.colorFg

    implicitWidth: theme.buttonSize
    implicitHeight: theme.buttonSize
    color: filled ? theme.colorFg : "transparent"
    border.color: theme.colorFg
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: theme.gridUnit

        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AI"
            color: root.fg
            font.family: theme.fontFamily
            font.pixelSize: root.showBar ? theme.px(9) : theme.px(11)
            font.letterSpacing: root.showBar ? theme.letterSpacing : 0
        }

        Rectangle {
            visible: root.showBar
            width: theme.px(16)
            height: theme.gridUnit
            color: "transparent"
            border.width: 1
            border.color: root.fg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(100, root.remaining)) / 100
                color: root.filled ? theme.colorBg : theme.levelColor(root.remaining)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
