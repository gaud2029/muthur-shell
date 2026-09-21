import QtQuick
import Quickshell.WindowManager

// Workspace tiles for this bar's output. Sourced from ext-workspace-v1
// (labwc, or any compositor implementing it) through Quickshell's
// WindowManager; falls back to the niri IPC bridge when the compositor
// exposes no workspaces that way.
AxisGrid {
    id: root

    property var niri
    property string outputName
    property var screen: null

    spacing: theme.gridUnit

    Theme { id: theme }

    function onThisOutput(windowset) {
        const screens = windowset.projection ? windowset.projection.screens : [];
        return screens.length === 0 || screens.some(s => root.screen && s.name === root.screen.name);
    }

    // Each entry keeps a reference to its live source object so the
    // delegate can bind to `active`/`urgent` directly instead of this
    // list being rebuilt on every focus change.
    readonly property var entries: {
        const sets = WindowManager.windowsets.filter(ws => ws.shouldDisplay && root.onThisOutput(ws));
        if (sets.length > 0) {
            return sets.map((ws, i) => ({
                label: ws.name.length <= 2 ? ws.name : String(i + 1),
                windowset: ws,
                niriWorkspace: null
            }));
        }
        if (!root.niri)
            return [];
        return root.niri.workspaces.filter(ws => ws.output === root.outputName).map(ws => ({
            label: String(ws.idx),
            windowset: null,
            niriWorkspace: ws
        }));
    }

    Repeater {
        model: root.entries

        Rectangle {
            id: tile
            required property var modelData

            readonly property bool active: modelData.windowset ? modelData.windowset.active : modelData.niriWorkspace.is_focused
            readonly property bool urgent: modelData.windowset ? modelData.windowset.urgent : false

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
                onClicked: {
                    if (tile.modelData.windowset)
                        tile.modelData.windowset.activate();
                    else
                        root.niri.focusWorkspace(tile.modelData.niriWorkspace.idx);
                }
            }
        }
    }
}
