import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Opened by clicking [BAT]. Not built on PopupPanel: no tabs.
BarPopup {
    id: root

    requestedWidth: theme.gridUnit * 96
    requestedHeight: theme.gridUnit * 88

    Theme { id: theme }

    readonly property var device: UPower.displayDevice
    readonly property bool charging: !!device && device.state === UPowerDeviceState.Charging
    readonly property bool discharging: !!device && device.state === UPowerDeviceState.Discharging

    // displayDevice is UPower's virtual aggregate (right for percentage/
    // state/etc, but it has no nativePath); the real physical battery is
    // needed separately to look up its charge-cycle count. UPower.devices
    // populates asynchronously, so an Instantiator (which reacts to model
    // inserts) finds it instead of a one-shot .values.find().
    property var batteryDevice: null

    Instantiator {
        model: UPower.devices

        delegate: QtObject {
            required property var modelData
            Component.onCompleted: {
                if (modelData.isLaptopBattery || modelData.type === UPowerDeviceType.Battery) {
                    root.batteryDevice = modelData;
                    root.refreshCycles();
                }
            }
        }
    }

    readonly property string stateText: {
        if (!device) return "";
        switch (device.state) {
            case UPowerDeviceState.Charging: return "CHARGING";
            case UPowerDeviceState.Discharging: return "DISCHARGING";
            case UPowerDeviceState.FullyCharged: return "FULLY CHARGED";
            case UPowerDeviceState.PendingCharge: return "PENDING CHARGE";
            case UPowerDeviceState.PendingDischarge: return "PENDING DISCHARGE";
            case UPowerDeviceState.Empty: return "EMPTY";
            default: return "UNKNOWN";
        }
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "-";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    // Charge-cycle count isn't exposed by Quickshell's UPower binding, so
    // it's fetched directly from upower(1). Refreshed occasionally since
    // it changes rarely.
    property string chargeCycles: "-"

    Process {
        id: cyclesProcess
        command: root.batteryDevice ? ["upower", "-i", "/org/freedesktop/UPower/devices/battery_" + root.batteryDevice.nativePath] : []
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/charge-cycles:\s*(\d+)/);
                root.chargeCycles = match ? match[1] : "-";
            }
        }
    }

    function refreshCycles() {
        if (!root.batteryDevice || !root.batteryDevice.nativePath) return;
        cyclesProcess.running = false;
        cyclesProcess.running = true;
    }

    // nativePath loads asynchronously over DBus; the periodic Timer's
    // triggeredOnStart can fire before it's populated, so also refresh
    // the moment it actually arrives.
    Connections {
        target: root.batteryDevice
        function onNativePathChanged() { root.refreshCycles(); }
        function onReadyChanged() { root.refreshCycles(); }
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshCycles()
    }

    Column {
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 4
        clip: true
        spacing: theme.gridUnit * 4

        UsageBar {
            width: parent.width
            label: "BATTERY"
            remainingPercent: root.device ? root.device.percentage * 100 : 0
            subtitle: root.stateText
            subtitleHighlight: root.discharging
            subtitlePulse: root.discharging
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: theme.gridUnit * 6
            rowSpacing: theme.gridUnit * 2

            Text {
                text: "BATTERY SIZE"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
            Text {
                text: root.device ? Math.round(root.device.energyCapacity) + "Wh" : "-"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                text: "CHARGE CYCLES"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
            Text {
                text: root.chargeCycles
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                text: root.charging ? "TIME TO FULL" : "TIME TO EMPTY"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
            Text {
                text: root.device ? root.formatDuration(root.charging ? root.device.timeToFull : root.device.timeToEmpty) : "-"
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Text {
            text: "POWER PROFILE"
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Row {
            width: parent.width
            spacing: theme.gridUnit * 2

            TerminalButton {
                label: "POWER-SAVER"
                selected: PowerProfiles.profile === PowerProfile.PowerSaver
                onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
            }
            TerminalButton {
                label: "BALANCED"
                selected: PowerProfiles.profile === PowerProfile.Balanced
                onClicked: PowerProfiles.profile = PowerProfile.Balanced
            }
            TerminalButton {
                label: "PERFORMANCE"
                visible: PowerProfiles.hasPerformanceProfile
                selected: PowerProfiles.profile === PowerProfile.Performance
                onClicked: PowerProfiles.profile = PowerProfile.Performance
            }
        }
    }
}
