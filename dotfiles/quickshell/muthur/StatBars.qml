import QtQuick

// A titled list of labeled bars scaled to the largest value, for the
// token statistics in the AI panel: [{ label, value }].
Column {
    id: root

    property string title: ""
    property var rows: []
    property string emptyText: "[ NO DATA ]"

    Theme { id: theme }

    readonly property real maxValue: rows.reduce((m, r) => Math.max(m, r.value), 0)

    function format(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B";
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "K";
        return String(n);
    }

    spacing: theme.gridUnit * 2

    Text {
        text: root.title
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }

    Text {
        visible: root.rows.length === 0
        text: root.emptyText
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
    }

    Repeater {
        model: root.rows

        Item {
            required property var modelData
            width: parent.width
            height: theme.gridUnit * 3

            Text {
                id: label
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: theme.gridUnit * 24
                elide: Text.ElideRight
                text: modelData.label
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                id: value
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.format(modelData.value)
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
            }

            Rectangle {
                anchors.left: label.right
                anchors.right: value.left
                anchors.rightMargin: theme.gridUnit * 2
                anchors.verticalCenter: parent.verticalCenter
                height: theme.gridUnit
                color: "transparent"
                border.color: theme.colorDim
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.maxValue > 0 ? parent.width * modelData.value / root.maxValue : 0
                    color: theme.colorBlue
                }
            }
        }
    }
}
