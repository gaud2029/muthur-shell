import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    Theme { id: theme }

    function deviceLabel(n) {
        return n.description || n.nickname || n.name;
    }

    function isAudioSink(n) {
        return !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink;
    }

    function isAudioSource(n) {
        return !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource;
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Quickshell only hydrates a node's live audio data (volume, mute)
    // for nodes something has expressed interest in — the sliders need
    // the two current defaults tracked, or .audio.volume stays 0.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => !!o)
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 3
        anchors.rightMargin: theme.gridUnit * 5
        contentWidth: width
        contentHeight: column.height
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: theme.gridUnit * 3

            Text {
                text: "AUDIO"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
            }

            Item {
                width: parent.width
                height: theme.gridUnit * 3

                Text {
                    anchors.left: parent.left
                    text: "OUTPUT"
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    anchors.right: parent.right
                    label: root.sink && root.sink.audio && root.sink.audio.muted ? "MUTED" : "MUTE"
                    selected: !!(root.sink && root.sink.audio && root.sink.audio.muted)
                    onClicked: {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                    }
                }
            }

            VolumeSlider {
                width: parent.width
                label: root.sink ? root.deviceLabel(root.sink) : "-"
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                onMoved: v => {
                    if (root.sink && root.sink.audio) root.sink.audio.volume = v;
                }
            }

            Repeater {
                model: Pipewire.nodes

                Rectangle {
                    id: sinkRow
                    required property var modelData
                    visible: root.isAudioSink(modelData)
                    width: parent ? parent.width : 0
                    height: visible ? theme.gridUnit * 6 : 0
                    color: "transparent"
                    border.width: modelData === root.sink ? 1 : 0
                    border.color: theme.colorFocus

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: theme.gridUnit * 2
                        anchors.rightMargin: theme.gridUnit * 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: root.deviceLabel(sinkRow.modelData)
                        color: sinkRow.modelData === root.sink ? theme.colorFocus : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                        font.letterSpacing: theme.letterSpacing
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
            }

            Item {
                width: parent.width
                height: theme.gridUnit * 3

                Text {
                    anchors.left: parent.left
                    text: "INPUT"
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    anchors.right: parent.right
                    label: root.source && root.source.audio && root.source.audio.muted ? "MUTED" : "MUTE"
                    selected: !!(root.source && root.source.audio && root.source.audio.muted)
                    onClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                    }
                }
            }

            VolumeSlider {
                width: parent.width
                label: root.source ? root.deviceLabel(root.source) : "-"
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                onMoved: v => {
                    if (root.source && root.source.audio) root.source.audio.volume = v;
                }
            }

            Repeater {
                model: Pipewire.nodes

                Rectangle {
                    id: sourceRow
                    required property var modelData
                    visible: root.isAudioSource(modelData)
                    width: parent ? parent.width : 0
                    height: visible ? theme.gridUnit * 6 : 0
                    color: "transparent"
                    border.width: modelData === root.source ? 1 : 0
                    border.color: theme.colorFocus

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: theme.gridUnit * 2
                        anchors.rightMargin: theme.gridUnit * 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: root.deviceLabel(sourceRow.modelData)
                        color: sourceRow.modelData === root.source ? theme.colorFocus : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                        font.letterSpacing: theme.letterSpacing
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Pipewire.preferredDefaultAudioSource = sourceRow.modelData
                    }
                }
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
