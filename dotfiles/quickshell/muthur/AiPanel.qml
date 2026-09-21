import QtQuick

PopupPanel {
    id: root

    tabs: [
        { key: "claude", label: "CLAUDE" },
        { key: "codex", label: "CODEX" }
    ]

    ClaudeUsageTab {
        anchors.fill: parent
        visible: root.currentTab === "claude"
        active: root.visible && root.currentTab === "claude"
    }

    CodexUsageTab {
        anchors.fill: parent
        visible: root.currentTab === "codex"
        active: root.visible && root.currentTab === "codex"
    }
}
