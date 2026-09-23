import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    Theme { id: theme }

    function isAudioSink(n) {
        return !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink;
    }

    function isAudioSource(n) {
        return !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource;
    }

    // Wide enough for "MUTED", so the slider doesn't shift on toggle.
    TextMetrics {
        id: mutedText
        text: "MUTED"
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }
    readonly property real muteWidth: Math.max(theme.buttonSize, mutedText.advanceWidth + theme.gridUnit * 2)

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

            Text {
                text: "OUTPUT"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            DeviceDropdown {
                width: parent.width
                current: root.sink
                accepts: n => root.isAudioSink(n)
                onPicked: node => Pipewire.preferredDefaultAudioSink = node
            }

            // Volume with its mute toggle at the far right, level with the track.
            Item {
                width: parent.width
                height: sinkSlider.implicitHeight

                VolumeSlider {
                    id: sinkSlider
                    anchors.left: parent.left
                    anchors.right: sinkMute.left
                    anchors.rightMargin: theme.gridUnit * 2
                    label: "VOLUME"
                    value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                    onMoved: v => {
                        if (root.sink && root.sink.audio) root.sink.audio.volume = v;
                    }
                }

                TerminalButton {
                    id: sinkMute
                    anchors.right: parent.right
                    // Centered on the slider's track, below its label row.
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: theme.gridUnit * 5
                    width: root.muteWidth
                    label: root.sink && root.sink.audio && root.sink.audio.muted ? "MUTED" : "MUTE"
                    selected: !!(root.sink && root.sink.audio && root.sink.audio.muted)
                    onClicked: {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
            }

            Text {
                text: "INPUT"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            DeviceDropdown {
                width: parent.width
                current: root.source
                accepts: n => root.isAudioSource(n)
                onPicked: node => Pipewire.preferredDefaultAudioSource = node
            }

            // Volume with its mute toggle at the far right, level with the track.
            Item {
                width: parent.width
                height: sourceSlider.implicitHeight

                VolumeSlider {
                    id: sourceSlider
                    anchors.left: parent.left
                    anchors.right: sourceMute.left
                    anchors.rightMargin: theme.gridUnit * 2
                    label: "VOLUME"
                    value: root.source && root.source.audio ? root.source.audio.volume : 0
                    onMoved: v => {
                        if (root.source && root.source.audio) root.source.audio.volume = v;
                    }
                }

                TerminalButton {
                    id: sourceMute
                    anchors.right: parent.right
                    // Centered on the slider's track, below its label row.
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: theme.gridUnit * 5
                    width: root.muteWidth
                    label: root.source && root.source.audio && root.source.audio.muted ? "MUTED" : "MUTE"
                    selected: !!(root.source && root.source.audio && root.source.audio.muted)
                    onClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                    }
                }
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
