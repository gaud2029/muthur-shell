import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness and night light (NightLight.qml). Brightness reads
// the kernel backlight devices under /sys/class/backlight and sets them
// through logind's SetBrightness, which the active session may call
// without root or a helper like brightnessctl. External monitors (DDC/CI)
// aren't covered. Output layout (position, mode, scale) is left to
// wdisplays, launched from the header.
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

        FastScroll { flickable: scroller }

        Column {
            id: column
            width: parent.width
            spacing: theme.gridUnit * 3

            Item {
                width: parent.width
                height: theme.gridUnit * 3

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DISPLAY"
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSize
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    anchors.right: parent.right
                    label: "ARRANGE"
                    onClicked: Quickshell.execDetached(["wdisplays"])
                }
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

            Text {
                text: "MAIN DISPLAY"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Dropdown {
                width: parent.width
                current: Quickshell.screens.find(s => s.name === ThemeStore.mainScreen) || null
                options: Quickshell.screens
                // Built-in panels report their model as "Unknown".
                labelFor: s => s ? [s.name, s.model === "Unknown" ? "" : s.model, s.width + "×" + s.height]
                    .filter(x => x).join("  ·  ") : "-"
                onPicked: s => ThemeStore.setMainScreen(s.name)
            }

            Text {
                text: "BAR ON"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Row {
                spacing: theme.gridUnit * 2

                TerminalButton {
                    label: "ALL DISPLAYS"
                    selected: !ThemeStore.barOnMainOnly
                    onClicked: ThemeStore.setBarOnMainOnly(false)
                }

                TerminalButton {
                    label: "MAIN ONLY"
                    selected: ThemeStore.barOnMainOnly
                    onClicked: ThemeStore.setBarOnMainOnly(true)
                }
            }

            // Night light (NightLight.qml): on/off and when, then how warm.
            Text {
                text: "NIGHT LIGHT"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Flow {
                width: parent.width
                spacing: theme.gridUnit * 2

                TerminalButton {
                    label: NightLight.enabled ? "ON" : "OFF"
                    selected: NightLight.enabled
                    onClicked: NightLight.toggle()
                }

                Item { width: theme.gridUnit * 2; height: 1 }

                Repeater {
                    model: [
                        { key: "always", label: "ALWAYS" },
                        { key: "schedule", label: "SCHEDULE" },
                        { key: "sun", label: "SUNSET/SUNRISE" }
                    ]

                    TerminalButton {
                        required property var modelData
                        label: modelData.label
                        selected: NightLight.mode === modelData.key
                        onClicked: NightLight.setMode(modelData.key)
                    }
                }
            }

            // Fixed hours: warm from SUNSET, back to day at SUNRISE (half an
            // hour's fade each way).
            Row {
                visible: NightLight.mode === "schedule"
                spacing: theme.gridUnit * 2

                component TimeField: Field {
                    required property string value
                    signal edited(string text)
                    width: theme.gridUnit * 16
                    border.color: input.activeFocus ? theme.colorFocus
                        : NightLight.validTime(input.text) ? theme.colorDim : theme.colorRed
                    input.text: value
                    input.inputMask: "99:99"
                    input.onEditingFinished: edited(input.text)
                }

                component FieldLabel: Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                FieldLabel { text: "WARM AT" }
                TimeField {
                    value: NightLight.store.sunset
                    onEdited: t => NightLight.setTimes(t, NightLight.store.sunrise)
                }
                FieldLabel { text: "DAY AT" }
                TimeField {
                    value: NightLight.store.sunrise
                    onEdited: t => NightLight.setTimes(NightLight.store.sunset, t)
                }
            }

            // The real sunset and sunrise, from a location (decimal degrees,
            // north and east positive).
            Column {
                visible: NightLight.mode === "sun"
                width: parent.width
                spacing: theme.gridUnit * 2

                Row {
                    spacing: theme.gridUnit * 2

                    Field {
                        id: latField
                        width: theme.gridUnit * 30
                        placeholder: "LATITUDE  45.5"
                        input.text: NightLight.store.latitude
                        input.onEditingFinished: NightLight.setLocation(latField.input.text, lonField.input.text)
                    }
                    Field {
                        id: lonField
                        width: theme.gridUnit * 30
                        placeholder: "LONGITUDE -73.6"
                        input.text: NightLight.store.longitude
                        input.onEditingFinished: NightLight.setLocation(latField.input.text, lonField.input.text)
                    }
                }

                Text {
                    visible: !NightLight.locationSet
                    text: "[ ENTER A LOCATION — DECIMAL DEGREES, NORTH/EAST POSITIVE ]"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }
            }

            // Warmer to the right.
            VolumeSlider {
                width: parent.width
                label: "WARMTH"
                readonly property int span: NightLight.maxTemperature - NightLight.minTemperature
                value: (NightLight.maxTemperature - NightLight.temperature) / span
                readout: NightLight.temperature + " K"
                onMoved: v => NightLight.setTemperature(NightLight.maxTemperature - v * span)
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
