import QtQuick

PopupPanel {
    id: root

    tabs: [
        { key: "wifi", label: "NETWORK" },
        { key: "bluetooth", label: "BT" },
        { key: "audio", label: "AUDIO" },
        { key: "display", label: "DISPLAY" },
        { key: "look", label: "LOOK" }
    ]

    Theme { id: theme }

    WifiTab {
        anchors.fill: parent
        visible: root.currentTab === "wifi"
        active: root.visible && root.currentTab === "wifi"
    }

    LookTab {
        anchors.fill: parent
        visible: root.currentTab === "look"
    }

    AudioTab {
        anchors.fill: parent
        visible: root.currentTab === "audio"
    }

    DisplayTab {
        anchors.fill: parent
        visible: root.currentTab === "display"
        active: root.visible && root.currentTab === "display"
    }

    BluetoothTab {
        anchors.fill: parent
        visible: root.currentTab === "bluetooth"
        active: root.visible && root.currentTab === "bluetooth"
    }

    Text {
        anchors.centerIn: parent
        visible: !["wifi", "look", "audio", "display", "bluetooth"].includes(root.currentTab)
        text: "[ NOT YET IMPLEMENTED ]"
        color: theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSize
        font.letterSpacing: theme.letterSpacing
    }
}
