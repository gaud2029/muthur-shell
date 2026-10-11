import QtQuick
import Quickshell

// The OSD itself (Osd.qml holds the state): a terminal box centered along
// the bar, just off it, that fades out a moment after the last key press.
//   VOL [■■■■■■■■■■■■□□□□□□□□] 060%
// Clicks go through it.
PanelWindow {
    id: root

    readonly property int cells: 20

    // Anchored to the bar's edge only: layer shell centers it along it.
    anchors {
        left: theme.barPosition === "left"
        right: theme.barPosition === "right"
        top: theme.barPosition === "top"
        bottom: theme.barPosition === "bottom"
    }
    margins {
        left: theme.gridUnit * 4
        right: theme.gridUnit * 4
        top: theme.gridUnit * 4
        bottom: theme.gridUnit * 4
    }

    // Fixed and wider than any box, with the box centered in it: the
    // window doesn't follow a size change while it's being shown (a
    // longer layout name came out cut off), and clicks go through anyway.
    implicitWidth: theme.gridUnit * 160
    implicitHeight: box.height
    color: "transparent"
    visible: box.opacity > 0
    mask: Region {}

    exclusiveZone: 0
    aboveWindows: true

    Theme { id: theme }

    Rectangle {
        id: box
        // Centered under/over a horizontal bar, against a vertical one.
        x: theme.barPosition === "left" ? 0
            : theme.barPosition === "right" ? parent.width - width
            : Math.round((parent.width - width) / 2)
        width: Math.ceil(row.width) + theme.gridUnit * 6
        height: theme.gridUnit * 10
        color: theme.colorBg
        border.color: Osd.muted ? theme.colorRed : theme.colorFg
        border.width: 1
        opacity: Osd.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Osd.shown ? 100 : 300 }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: theme.gridUnit * 3

            component Label: Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
                color: theme.colorFg
            }

            Label {
                text: ({ volume: "VOL", mic: "MIC", brightness: "BRT", layout: "KBD" })[Osd.kind] || ""
                color: theme.colorDim
            }

            // The level as a row of cells, dimmed while muted.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Osd.kind === "volume" || Osd.kind === "brightness"
                spacing: theme.px(3)

                Repeater {
                    model: root.cells

                    Rectangle {
                        required property int index
                        readonly property bool lit: index < Math.round(Osd.level * root.cells)
                        width: theme.px(8)
                        height: theme.px(16)
                        color: lit ? (Osd.muted ? theme.colorDim : theme.colorFg) : "transparent"
                        border.color: theme.colorDim
                        border.width: lit ? 0 : 1
                    }
                }
            }

            Label {
                // Fixed width so the box doesn't twitch between 5% and 100%.
                width: Osd.kind === "volume" || Osd.kind === "brightness" ? widthProbe.advanceWidth : implicitWidth
                horizontalAlignment: Text.AlignRight
                text: Osd.muted ? "MUTED"
                    : Osd.kind === "mic" ? "LIVE"
                    : Osd.kind === "layout" ? Osd.text
                    : String(Math.round(Osd.level * 100)).padStart(3, "0") + "%"
                color: Osd.muted ? theme.colorRed : theme.colorFg
            }

            TextMetrics {
                id: widthProbe
                text: "MUTED"
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
            }

            Label {
                visible: Osd.kind === "layout"
                text: Keyboard.describe(Keyboard.current).toUpperCase()
                color: theme.colorDim
                font.pixelSize: theme.px(11)
            }
        }
    }
}
