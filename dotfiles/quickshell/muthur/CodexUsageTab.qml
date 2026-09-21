import QtQuick

Item {
    id: root

    property bool active: false

    Theme { id: theme }

    Binding {
        target: CodexUsage
        property: "active"
        value: root.active
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
            spacing: theme.gridUnit * 4

            Item {
                width: parent.width
                height: theme.buttonSize

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CODEX"
                    color: theme.colorFg
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSize
                    font.letterSpacing: theme.letterSpacing
                }

                // Makes this the agent whose session bar the [AI] button shows.
                TerminalButton {
                    anchors.right: parent.right
                    label: "DEFAULT"
                    selected: ThemeStore.defaultAgent === "codex"
                    onClicked: ThemeStore.setDefaultAgent(selected ? "" : "codex")
                }
            }

            Text {
                visible: !CodexUsage.loaded
                text: "[ LOADING... ]"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
            }

            Text {
                visible: CodexUsage.loaded && !CodexUsage.installed
                text: "[ CODEX NOT INSTALLED ]"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
            }

            Text {
                visible: CodexUsage.loaded && CodexUsage.installed && CodexUsage.fallbackMessage.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                text: CodexUsage.fallbackMessage
                color: theme.colorFocus
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
            }

            UsageBar {
                width: parent.width
                visible: CodexUsage.loaded && CodexUsage.installed && CodexUsage.fallbackMessage.length === 0 && CodexUsage.sessionAvailable
                label: "SESSION (5H)"
                remainingPercent: CodexUsage.sessionRemaining
                subtitle: CodexUsage.sessionReset
            }

            UsageBar {
                width: parent.width
                visible: CodexUsage.loaded && CodexUsage.installed && CodexUsage.fallbackMessage.length === 0 && CodexUsage.weekAvailable
                label: "WEEK"
                remainingPercent: CodexUsage.weekRemaining
                subtitle: CodexUsage.weekReset
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.colorDim
            }

            StatBars {
                width: parent.width
                title: "TOKENS BY DAY"
                rows: CodexUsage.statsDays
                emptyText: CodexUsage.statsLoaded ? "[ NO SESSIONS IN THE LAST 7 DAYS ]" : "[ LOADING... ]"
            }

            StatBars {
                width: parent.width
                title: "TOKENS BY MODEL"
                rows: CodexUsage.statsModels
                emptyText: CodexUsage.statsLoaded ? "[ NO SESSIONS IN THE LAST 7 DAYS ]" : "[ LOADING... ]"
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
