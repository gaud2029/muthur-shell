import QtQuick
import Quickshell.WindowManager

// Workspace tiles for this bar's output, from ext-workspace-v1 through
// Quickshell's WindowManager (labwc announces them in order).
AxisGrid {
    id: root

    property var screen: null

    spacing: theme.gridUnit

    Theme { id: theme }

    function onThisOutput(windowset) {
        const screens = windowset.projection ? windowset.projection.screens : [];
        return screens.length === 0 || screens.some(s => root.screen && s.name === root.screen.name);
    }

    // Names longer than a tile show their position instead.
    function labelFor(name, i) {
        return name.length <= 2 ? name : String(i + 1);
    }

    // Each entry is { label, state, activate }. `state` is the live source
    // object (with `active`/`urgent`) so the delegate can bind to it
    // directly instead of this list being rebuilt on every focus change.
    readonly property var entries: WindowManager.windowsets
        .filter(ws => ws.shouldDisplay && root.onThisOutput(ws))
        .map((ws, i) => ({
            label: root.labelFor(ws.name, i),
            state: ws,
            activate: () => ws.activate()
        }))

    Repeater {
        model: root.entries

        Rectangle {
            id: tile
            required property var modelData

            readonly property bool active: modelData.state.active
            readonly property bool urgent: modelData.state.urgent

            width: theme.tile
            height: theme.tile
            color: active ? theme.colorFg : "transparent"
            border.color: urgent ? theme.colorFocus : theme.colorFg
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: tile.modelData.label
                color: tile.active ? theme.colorBg : (tile.urgent ? theme.colorFocus : theme.colorFg)
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.modelData.activate()
            }
        }
    }
}
