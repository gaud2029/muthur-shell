import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: root

    property bool active: false
    readonly property var adapter: Bluetooth.defaultAdapter

    Theme { id: theme }

    function applyDiscovery() {
        if (root.adapter) root.adapter.discovering = root.active && root.adapter.enabled;
    }

    onActiveChanged: applyDiscovery()
    onAdapterChanged: applyDiscovery()

    Connections {
        target: root.adapter
        function onEnabledChanged() { root.applyDiscovery(); }
    }

    // BlueZ needs a pairing agent registered to authorize a new pairing —
    // without one, pair() just hangs or fails, which is why this used to
    // require a manual `bluetoothctl agent on; default-agent` first.
    // bluetoothctl's own NoInputNoOutput ("just works") agent covers the
    // common case, kept running for as long as this tab exists.
    Process {
        id: agentProcess
        command: ["bluetoothctl"]
        stdinEnabled: true
        running: true
        onStarted: {
            write("agent NoInputNoOutput\n");
            write("default-agent\n");
        }
    }

    // Address of the device this tab just called pair() on, so the
    // moment it actually becomes paired we can also trust + connect it —
    // matching the rest of the manual `pair; trust; connect` sequence —
    // without doing that to devices that were already paired elsewhere.
    property string pendingPairAddress: ""

    Timer {
        id: pairTimeout
        interval: 15000
        onTriggered: root.pendingPairAddress = ""
    }

    // Repeater.count only reflects total model size, not a filtered
    // subset, and a plain .values.filter() snapshot misses devices that
    // change bucket later (pair/connect) — so each device's membership is
    // tracked live via its own connectedChanged/pairedChanged signals.
    property int connectedCount: 0
    property int pairedOnlyCount: 0
    property int availableCount: 0

    Instantiator {
        model: root.adapter ? root.adapter.devices : []

        delegate: Item {
            id: tracker
            required property var modelData
            property string bucket: ""

            function currentBucket() {
                if (modelData.connected) return "connected";
                if (modelData.paired) return "paired";
                return "available";
            }

            function sync() {
                const next = tracker.currentBucket();
                if (next === tracker.bucket) return;
                tracker.release(tracker.bucket);
                tracker.bucket = next;
                tracker.claim(next);
            }

            function claim(b) {
                if (b === "connected") root.connectedCount++;
                else if (b === "paired") root.pairedOnlyCount++;
                else if (b === "available") root.availableCount++;
            }

            function release(b) {
                if (b === "connected") root.connectedCount--;
                else if (b === "paired") root.pairedOnlyCount--;
                else if (b === "available") root.availableCount--;
            }

            Component.onCompleted: {
                tracker.bucket = tracker.currentBucket();
                tracker.claim(tracker.bucket);
            }
            Component.onDestruction: tracker.release(tracker.bucket)

            Connections {
                target: tracker.modelData
                function onConnectedChanged() { tracker.sync(); }
                function onPairedChanged() {
                    tracker.sync();
                    if (tracker.modelData.paired && tracker.modelData.address === root.pendingPairAddress) {
                        root.pendingPairAddress = "";
                        pairTimeout.stop();
                        tracker.modelData.trusted = true;
                        tracker.modelData.connect();
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }

    component DeviceRow: Rectangle {
        id: deviceRow
        required property var modelData
        width: parent ? parent.width : 0
        height: theme.gridUnit * 6
        color: deviceRow.modelData.connected ? theme.colorFg : "transparent"
        border.color: theme.colorFg
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.right: statusText.left
            anchors.leftMargin: theme.gridUnit * 2
            anchors.rightMargin: theme.gridUnit * 2
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: deviceRow.modelData.name || deviceRow.modelData.deviceName
            color: deviceRow.modelData.connected ? theme.colorBg : theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(12)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            id: statusText
            anchors.right: parent.right
            anchors.rightMargin: theme.gridUnit * 2
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.modelData.pairing ? "PAIRING..." : (deviceRow.modelData.connected ? "CONNECTED" : "")
            color: deviceRow.modelData.connected ? theme.colorBg : theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(10)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const dev = deviceRow.modelData;
                if (dev.connected) {
                    dev.disconnect();
                } else if (dev.paired) {
                    dev.connect();
                } else {
                    root.pendingPairAddress = dev.address;
                    pairTimeout.restart();
                    dev.pair();
                }
            }
        }
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

            Item {
                width: parent.width
                height: theme.buttonSize

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BLUETOOTH"
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSize
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: root.adapter && root.adapter.enabled ? "ON" : "OFF"
                    onClicked: {
                        if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
                    }
                }
            }

            Text {
                visible: !root.adapter
                text: "[ NO BLUETOOTH ADAPTER ]"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Column {
                width: parent.width
                spacing: theme.gridUnit * 3
                visible: root.adapter && root.adapter.enabled

                Column {
                    width: parent.width
                    spacing: theme.gridUnit
                    visible: root.connectedCount > 0

                    SectionLabel { text: "CONNECTED" }

                    Repeater {
                        model: root.adapter ? root.adapter.devices : []
                        DeviceRow {
                            visible: modelData.connected
                            height: visible ? theme.gridUnit * 6 : 0
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: theme.gridUnit
                    visible: root.pairedOnlyCount > 0

                    SectionLabel { text: "PAIRED" }

                    Repeater {
                        model: root.adapter ? root.adapter.devices : []
                        DeviceRow {
                            visible: modelData.paired && !modelData.connected
                            height: visible ? theme.gridUnit * 6 : 0
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: theme.gridUnit

                    SectionLabel { text: "AVAILABLE" }

                    Repeater {
                        model: root.adapter ? root.adapter.devices : []
                        DeviceRow {
                            visible: !modelData.paired && !modelData.connected
                            height: visible ? theme.gridUnit * 6 : 0
                        }
                    }

                    SectionLabel {
                        visible: root.availableCount === 0
                        text: "[ NO DEVICES FOUND ]"
                    }
                }
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
