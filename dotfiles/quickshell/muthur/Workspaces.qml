import QtQuick
import Quickshell.WindowManager

// Workspace tiles for this bar's output. Sourced from Hyprland's own IPC
// when running there, otherwise from ext-workspace-v1 (labwc, or any
// compositor implementing it) through Quickshell's WindowManager, and
// falls back to the niri IPC bridge when the compositor exposes no
// workspaces that way.
AxisGrid {
    id: root

    property var hyprland
    property var niri
    property string outputName
    property var screen: null

    spacing: theme.gridUnit

    Theme { id: theme }

    function onThisOutput(windowset) {
        const screens = windowset.projection ? windowset.projection.screens : [];
        return screens.length === 0 || screens.some(s => root.screen && s.name === root.screen.name);
    }

    function compareCoordinates(a, b) {
        for (let i = 0; i < Math.min(a.length, b.length); i++) {
            if (a[i] !== b[i])
                return a[i] - b[i];
        }
        return a.length - b.length;
    }

    // Names longer than a tile show their position instead.
    function labelFor(name, i) {
        return name.length <= 2 ? name : String(i + 1);
    }

    // Each entry is { label, state, activate }. `state` is the live source
    // object (with `active`/`urgent`) so the delegate can bind to it
    // directly instead of this list being rebuilt on every focus change;
    // niri's workspaces are plain JSON replaced wholesale, so the list
    // itself is rebuilt there.
    readonly property var entries: {
        if (root.hyprland) {
            return root.hyprland.workspaces
                .filter(ws => ws.monitor && ws.monitor.name === root.outputName)
                .map((ws, i) => ({
                    label: root.labelFor(ws.name, i),
                    state: ws,
                    activate: () => root.hyprland.focusWorkspace(ws)
                }));
        }
        // ext-workspace's coordinates give each workspace its position;
        // niri announces them in no particular order (labwc in order, so
        // protocol order breaks ties).
        const sets = WindowManager.windowsets.filter(ws => ws.shouldDisplay && root.onThisOutput(ws))
            .map((ws, i) => ({ ws, i }))
            .sort((a, b) => root.compareCoordinates(a.ws.coordinates, b.ws.coordinates) || a.i - b.i)
            .map(e => e.ws);
        if (sets.length > 0) {
            return sets.map((ws, i) => ({
                label: root.labelFor(ws.name, i),
                state: ws,
                activate: () => ws.activate()
            }));
        }
        if (!root.niri)
            return [];
        return root.niri.workspaces.filter(ws => ws.output === root.outputName).sort((a, b) => a.idx - b.idx).map(ws => ({
            label: String(ws.idx),
            state: { active: ws.is_focused, urgent: false },
            activate: () => root.niri.focusWorkspace(ws.idx)
        }));
    }

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
