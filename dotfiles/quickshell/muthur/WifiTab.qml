import QtQuick
import Quickshell.Networking

Item {
    id: root

    property bool active: false
    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property string expandedNetwork: ""
    property string passwordDraft: ""
    property string errorText: ""
    property string pendingConnectName: ""

    Theme { id: theme }

    function showError(text) {
        root.errorText = text;
        errorDismiss.restart();
    }

    Timer {
        id: errorDismiss
        interval: 5000
        onTriggered: root.errorText = ""
    }

    Timer {
        id: connectTimeout
        interval: 4000
        onTriggered: {
            const net = root.wifiDevice ? root.wifiDevice.networks.values.find(n => n.name === root.pendingConnectName) : null;
            if (net && !net.connected) {
                root.showError("[ COULDN'T RECONNECT - enter password ]");
                root.expandedNetwork = net.name;
                root.passwordDraft = "";
            }
            root.pendingConnectName = "";
        }
    }

    function applyScannerState() {
        if (wifiDevice)
            wifiDevice.scannerEnabled = active;
    }

    onActiveChanged: applyScannerState()
    onWifiDeviceChanged: applyScannerState()

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
                    text: "WIFI"
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSize
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: Networking.wifiEnabled ? "ON" : "OFF"
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }

            Text {
                visible: root.errorText.length > 0
                text: root.errorText
                color: theme.colorFocus
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        errorDismiss.stop();
                        root.errorText = "";
                    }
                }
            }

            Column {
                width: parent.width
                spacing: theme.gridUnit
                visible: Networking.wifiEnabled

                Repeater {
                    model: root.wifiDevice ? root.wifiDevice.networks : []

                    Column {
                        id: delegateRoot
                        required property var modelData
                        width: parent.width
                        spacing: theme.gridUnit

                        Connections {
                            target: delegateRoot.modelData
                            function onConnectionFailed(reason) {
                                root.showError("[ CONNECT FAILED: " + ConnectionFailReason.toString(reason) + " - enter password ]");
                                root.expandedNetwork = delegateRoot.modelData.name;
                                root.passwordDraft = "";
                                if (root.pendingConnectName === delegateRoot.modelData.name) {
                                    connectTimeout.stop();
                                    root.pendingConnectName = "";
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: theme.px(25)
                            color: delegateRoot.modelData.connected ? theme.colorFg : "transparent"
                            border.color: theme.colorFg
                            border.width: 1

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: theme.gridUnit * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: (delegateRoot.modelData.security !== WifiSecurityType.Open ? "#" : " ")
                                      + " " + delegateRoot.modelData.name
                                color: delegateRoot.modelData.connected ? theme.colorBg : theme.colorFg
                                font.family: theme.fontFamily
                                font.pixelSize: theme.px(12)
                                elide: Text.ElideRight
                                width: parent.width - theme.gridUnit * 12
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: theme.gridUnit * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(delegateRoot.modelData.signalStrength * 100) + "%"
                                color: delegateRoot.modelData.connected ? theme.colorBg : theme.colorDim
                                font.family: theme.fontFamily
                                font.pixelSize: theme.px(10)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    errorDismiss.stop();
                                    root.errorText = "";
                                    const net = delegateRoot.modelData;
                                    if (net.connected) {
                                        net.disconnect();
                                    } else if (net.known || net.security === WifiSecurityType.Open) {
                                        net.connect();
                                        if (net.security !== WifiSecurityType.Open) {
                                            root.pendingConnectName = net.name;
                                            connectTimeout.restart();
                                        }
                                    } else {
                                        root.expandedNetwork = (root.expandedNetwork === net.name) ? "" : net.name;
                                        root.passwordDraft = "";
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: root.expandedNetwork === delegateRoot.modelData.name ? theme.px(25) : 0
                            visible: height > 0
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: passwordConnect.left
                                anchors.rightMargin: theme.gridUnit
                                height: theme.px(25)
                                color: "transparent"
                                border.color: theme.colorDim
                                border.width: 1

                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: theme.gridUnit
                                    text: root.passwordDraft
                                    onTextChanged: root.passwordDraft = text
                                    echoMode: TextInput.Password
                                    color: theme.colorFg
                                    font.family: theme.fontFamily
                                    font.pixelSize: theme.px(11)
                                    focus: root.expandedNetwork === delegateRoot.modelData.name
                                }
                            }

                            TerminalButton {
                                id: passwordConnect
                                anchors.right: parent.right
                                label: "OK"
                                onClicked: {
                                    delegateRoot.modelData.connectWithPsk(root.passwordDraft);
                                    root.expandedNetwork = "";
                                    root.passwordDraft = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
