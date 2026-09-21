import QtQuick

Column {
    id: root

    property string label: ""
    property real remainingPercent: 0
    property string subtitle: ""
    // Draw the subtitle in the full foreground colour instead of dim,
    // and/or pulse it, for states that deserve attention (e.g. a
    // discharging battery).
    property bool subtitleHighlight: false
    property bool subtitlePulse: false

    Theme { id: theme }

    spacing: theme.gridUnit

    Item {
        width: parent.width
        height: theme.gridUnit * 3

        Text {
            anchors.left: parent.left
            text: root.label
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(12)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            anchors.right: parent.right
            text: Math.round(root.remainingPercent) + "% LEFT"
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(12)
        }
    }

    Rectangle {
        width: parent.width
        height: theme.gridUnit * 2
        color: "transparent"
        border.color: theme.colorFg
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(100, root.remainingPercent)) / 100
            color: theme.levelColor(root.remainingPercent)
        }
    }

    Text {
        id: subtitleText
        visible: root.subtitle.length > 0
        text: root.subtitle
        color: root.subtitleHighlight ? theme.colorFg : theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(10)

        // Same breathing rhythm as the launcher's cursor in Bar.qml.
        SequentialAnimation on opacity {
            running: root.subtitlePulse
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) subtitleText.opacity = 1
        }
    }
}
