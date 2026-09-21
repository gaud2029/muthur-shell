import QtQuick

// Drop into any PanelWindow (which must also set `focusable: true`) to
// close it on Escape. Grabs focus on hover so Escape works without an
// extra click first; the panel itself should also grab focus as soon as
// it becomes visible (onVisibleChanged) for the common case of opening
// it and immediately pressing Escape.
Item {
    id: root

    property var targetWindow

    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: if (root.targetWindow) root.targetWindow.visible = false

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.forceActiveFocus()
    }
}
