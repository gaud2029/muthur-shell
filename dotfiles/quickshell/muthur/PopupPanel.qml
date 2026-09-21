import QtQuick
import Quickshell

BarPopup {
    id: root

    property var tabs: []
    property string currentTab: tabs.length > 0 ? tabs[0].key : ""
    default property alias content: contentArea.data

    requestedWidth: theme.panelWidth
    requestedHeight: theme.panelHeight

    Theme { id: theme }

    Column {
        anchors.fill: parent
        anchors.margins: 1

        Item {
            width: parent.width
            height: theme.barThickness

            Row {
                anchors.centerIn: parent
                spacing: theme.gridUnit

                Repeater {
                    model: root.tabs

                    TerminalButton {
                        required property var modelData
                        label: modelData.label
                        selected: root.currentTab === modelData.key
                        onClicked: root.currentTab = modelData.key
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Item {
            id: contentArea
            width: parent.width
            height: parent.height - theme.barThickness - 1
            clip: true
        }
    }
}
