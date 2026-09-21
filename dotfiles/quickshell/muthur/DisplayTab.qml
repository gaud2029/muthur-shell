import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness. Reads the kernel backlight devices under
// /sys/class/backlight and sets them through logind's SetBrightness,
// which the active session may call without root or a helper like
// brightnessctl. External monitors (DDC/CI) aren't covered.
Item {
    id: root

    property bool active: false

    Theme { id: theme }

    // [{ name, max, output }] — output is the DRM connector the backlight
    // belongs to (eDP-1), so the slider is labeled like the display.
    property var devices: []

    Process {
        id: scan
        command: ["sh", "-c",
            "for d in /sys/class/backlight/*; do [ -e \"$d\" ] || continue; " +
            "echo \"$(basename \"$d\") $(cat \"$d/max_brightness\") " +
            "$(basename \"$(readlink -f \"$d/device\")\" | sed 's/^card[0-9]*-//')\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.devices = this.text.trim().split("\n").filter(l => l).map(line => {
                    const [name, max, output] = line.split(" ");
                    return { name: name, max: parseInt(max), output: output || name };
                });
            }
        }
    }

    onActiveChanged: if (active) scan.running = true

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
                text: "DISPLAY"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSize
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                text: "BRIGHTNESS"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Repeater {
                model: root.devices

                VolumeSlider {
                    id: slider
                    required property var modelData

                    width: parent.width
                    label: modelData.output.toUpperCase()
                    value: current / modelData.max

                    property int current: modelData.max

                    // sysfs doesn't raise inotify events, so poll while the
                    // tab is showing to follow the keyboard brightness keys.
                    // `brightness` is the requested level; amdgpu's
                    // `actual_brightness` is a non-linear hardware readback.
                    FileView {
                        id: reader
                        path: "/sys/class/backlight/" + slider.modelData.name + "/brightness"
                        blockLoading: true
                        onLoaded: slider.current = parseInt(text()) || 0
                    }

                    Timer {
                        running: root.active
                        interval: 1000
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: reader.reload()
                    }

                    // Never fully off: a black screen with no way to see the
                    // slider is a trap.
                    onMoved: v => {
                        const raw = Math.round(Math.max(0.01, v) * modelData.max);
                        slider.current = raw;
                        Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1",
                            "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
                            "SetBrightness", "ssu", "backlight", modelData.name, String(raw)]);
                    }
                }
            }

            Text {
                visible: root.devices.length === 0
                text: "[ NO BACKLIGHT DEVICE ]"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
