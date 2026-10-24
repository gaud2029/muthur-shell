import QtQuick
import Quickshell

// Opened by clicking [UPD]: the pending updates (Updates.qml), the
// important ones first, and the buttons to check again or upgrade
// (`sudo pacman -Syu` in a terminal). Not built on PopupPanel: no tabs.
BarPopup {
    id: root

    requestedWidth: theme.gridUnit * 110
    requestedHeight: theme.gridUnit * 130

    Theme { id: theme }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 4
        spacing: theme.gridUnit * 3

        Text {
            text: "SYSTEM UPDATES"
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: !Updates.hasData ? (Updates.fetching ? "[ CHECKING... ]" : "[ NOT CHECKED YET ]")
                : Updates.packages.length === 0 ? "[ SYSTEM UP TO DATE ]"
                : Updates.packages.length + " PACKAGES"
                    + (Updates.importantCount > 0 ? " · " + Updates.importantCount + " IMPORTANT" : "")
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            visible: Updates.rebootRequired
            width: parent.width
            wrapMode: Text.Wrap
            text: "REBOOT REQUIRED — THE RUNNING KERNEL WAS REPLACED"
            color: theme.colorFocus
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Item {
            width: parent.width
            // Whatever the lines above and the buttons below leave.
            height: Math.max(0, parent.height - y - footer.height - parent.spacing)

            ListView {
                id: list
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width - (scroll.needed ? theme.scrollBarWidth + theme.gridUnit : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: Updates.packages }

                FastScroll { flickable: list }

                delegate: Item {
                    id: row

                    required property var modelData

                    width: ListView.view.width
                    height: theme.gridUnit * 4

                    // Marks the important ones, whatever the preset's
                    // focus color.
                    Text {
                        id: mark
                        width: theme.gridUnit * 3
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.important ? "!" : ""
                        color: theme.colorFocus
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                    }

                    Text {
                        id: name
                        anchors.left: mark.right
                        width: Math.min(implicitWidth, row.width * 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: row.modelData.important ? theme.colorFocus : theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                    }

                    Text {
                        anchors.left: name.right
                        anchors.leftMargin: theme.gridUnit * 2
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: row.modelData.from + " → " + row.modelData.to
                        color: theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(10)
                    }
                }
            }

            TerminalScrollBar {
                id: scroll
                flickable: list
            }
        }

        Column {
            id: footer
            width: parent.width
            spacing: theme.gridUnit * 2

            UsageAge {
                usage: Updates
            }

            Text {
                visible: Updates.error.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                text: Updates.error
                color: theme.colorFocus
                font.family: theme.fontFamily
                font.pixelSize: theme.px(10)
            }

            Row {
                spacing: theme.gridUnit * 2

                TerminalButton {
                    label: Updates.fetching ? "CHECKING..." : "RECHECK"
                    onClicked: Updates.check()
                }

                TerminalButton {
                    label: "UPGRADE"
                    visible: Updates.packages.length > 0
                    onClicked: {
                        Updates.upgrade();
                        root.visible = false;
                    }
                }
            }
        }
    }
}
