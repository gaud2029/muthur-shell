import QtQuick
import Quickshell

// Opened by clicking [MON] (SysMon.qml has the numbers): CPU with a bar
// per core, memory and swap, temperatures, disks, and the busiest
// processes; BTOP opens the full monitor. Polls fast while open. Not
// built on PopupPanel: no tabs.
BarPopup {
    id: root

    requestedWidth: theme.gridUnit * 110
    requestedHeight: theme.gridUnit * 150

    Theme { id: theme }

    onVisibleChanged: SysMon.watchers += visible ? 1 : -1
    Component.onDestruction: if (visible) SysMon.watchers -= 1

    // A labeled meter: name, value on the right, a bar under them. High is
    // bad here, so the color runs green to red as it fills.
    component Meter: Column {
        id: meter

        property string label: ""
        property string value: ""
        property real percent: 0

        width: parent ? parent.width : 0
        spacing: theme.gridUnit

        Item {
            width: parent.width
            height: theme.gridUnit * 3

            Text {
                text: meter.label
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                anchors.right: parent.right
                text: meter.value
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
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
                width: parent.width * Math.max(0, Math.min(100, meter.percent)) / 100
                color: theme.levelColor(100 - meter.percent)
            }
        }
    }

    // The same on one line, for the lists (temperatures, disks).
    component LineMeter: Item {
        id: gauge

        property string label: ""
        property string value: ""
        property real percent: 0

        width: parent ? parent.width : 0
        height: theme.gridUnit * 3

        Text {
            id: gaugeLabel
            width: theme.gridUnit * 18
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: gauge.label
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            anchors.left: gaugeLabel.right
            anchors.right: gaugeValue.left
            anchors.rightMargin: theme.gridUnit * 2
            anchors.verticalCenter: parent.verticalCenter
            height: theme.gridUnit * 2
            color: "transparent"
            border.color: theme.colorFg
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(100, gauge.percent)) / 100
                color: theme.levelColor(100 - gauge.percent)
            }
        }

        Text {
            id: gaugeValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: theme.gridUnit * 24
            horizontalAlignment: Text.AlignRight
            text: gauge.value
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
        }
    }

    component Heading: Text {
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }

    // name ........ value, for the process lists.
    component Line: Item {
        id: line

        property string name: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: theme.gridUnit * 3

        Text {
            width: parent.width - valueText.implicitWidth - theme.gridUnit * 2
            elide: Text.ElideRight
            text: line.name
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
        }

        Text {
            id: valueText
            anchors.right: parent.right
            text: line.value
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
        }
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 4
        anchors.rightMargin: theme.gridUnit * 4 + (scroll.needed ? theme.scrollBarWidth + theme.gridUnit : 0)
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        FastScroll { flickable: scroller }

        Column {
            id: content
            width: scroller.width
            spacing: theme.gridUnit * 4

            Text {
                text: "SYSTEM MONITOR"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
            }

            // CPU
            Column {
                width: parent.width
                spacing: theme.gridUnit * 2

                Meter {
                    label: "CPU"
                    value: Math.round(SysMon.cpu) + "%"
                        + (SysMon.frequency > 0 ? "  " + (SysMon.frequency / 1000).toFixed(2) + " GHZ" : "")
                    percent: SysMon.cpu
                }

                Heading {
                    text: "LOAD " + SysMon.load.map(l => l.toFixed(2)).join("  ")
                        + "   ·   " + SysMon.cores.length + " CORES"
                }

                // One thin bar per core, filling from the bottom.
                Row {
                    id: coreRow
                    width: parent.width
                    height: theme.gridUnit * 8
                    spacing: theme.gridUnit

                    Repeater {
                        model: SysMon.cores

                        Rectangle {
                            required property real modelData

                            width: (coreRow.width - coreRow.spacing * (SysMon.cores.length - 1)) / Math.max(1, SysMon.cores.length)
                            height: coreRow.height
                            color: "transparent"
                            border.color: theme.colorDim
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * Math.max(0, Math.min(100, modelData)) / 100
                                color: theme.levelColor(100 - modelData)
                            }
                        }
                    }
                }
            }

            // Memory
            Column {
                width: parent.width
                spacing: theme.gridUnit * 2

                Meter {
                    label: "MEMORY"
                    value: SysMon.bytes(SysMon.memUsed) + " / " + SysMon.bytes(SysMon.memTotal)
                    percent: SysMon.memPercent
                }

                Heading {
                    text: "CACHE " + SysMon.bytes(SysMon.memCache)
                }

                Meter {
                    visible: SysMon.swapTotal > 0
                    label: "SWAP"
                    value: SysMon.bytes(SysMon.swapUsed) + " / " + SysMon.bytes(SysMon.swapTotal)
                    percent: SysMon.swapPercent
                }
            }

            // Temperatures, as a 30-100°C scale.
            Column {
                visible: SysMon.temperatures.length > 0
                width: parent.width
                spacing: theme.gridUnit

                Heading { text: "TEMPERATURE" }

                Repeater {
                    model: SysMon.temperatures

                    LineMeter {
                        required property var modelData
                        label: modelData.label
                        value: Math.round(modelData.celsius) + "°C"
                        percent: (modelData.celsius - 30) / 70 * 100
                    }
                }
            }

            // Disks
            Column {
                visible: SysMon.disks.length > 0
                width: parent.width
                spacing: theme.gridUnit

                Heading { text: "DISKS" }

                Repeater {
                    model: SysMon.disks

                    LineMeter {
                        required property var modelData
                        label: modelData.mount
                        value: SysMon.bytes(modelData.used) + " / " + SysMon.bytes(modelData.size)
                        percent: modelData.percent
                    }
                }
            }

            // Processes
            Row {
                width: parent.width
                spacing: theme.gridUnit * 4

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: theme.gridUnit

                    Heading { text: "TOP CPU" }

                    Repeater {
                        model: SysMon.topCpu

                        Line {
                            required property var modelData
                            name: modelData.name
                            value: modelData.value.toFixed(1) + "%"
                        }
                    }
                }

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: theme.gridUnit

                    Heading { text: "TOP MEMORY" }

                    Repeater {
                        model: SysMon.topMem

                        Line {
                            required property var modelData
                            name: modelData.name
                            value: SysMon.bytes(modelData.value)
                        }
                    }
                }
            }

            TerminalButton {
                label: "BTOP"
                onClicked: {
                    Quickshell.execDetached(["alacritty", "-e", "btop"]);
                    root.visible = false;
                }
            }
        }
    }

    TerminalScrollBar {
        id: scroll
        flickable: scroller
    }
}
