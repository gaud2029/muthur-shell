import QtQuick

// MU/TH/UR 6000 terminal palette + layout tokens. Everything proxies the
// persisted ThemeStore singleton so every "Theme { id: theme }" instance
// across the shell re-renders when the user changes a preset, the bar
// position or the size in [SYS] > [LOOK], without touching each call site.
QtObject {
    readonly property color colorBg: ThemeStore.colorBg
    readonly property color colorFg: ThemeStore.colorFg
    readonly property color colorDim: ThemeStore.colorDim
    readonly property color colorFocus: ThemeStore.colorFocus
    // The full pywal-shaped palette (special + colors.color0..15), and
    // the muted hue slots by name for the few places the shell colors by
    // meaning rather than by brightness.
    readonly property var palette: ThemeStore.palette
    readonly property color colorRed: palette.colors.color1
    readonly property color colorGreen: palette.colors.color2
    readonly property color colorYellow: palette.colors.color3
    readonly property color colorBlue: palette.colors.color4
    readonly property color colorMagenta: palette.colors.color5
    readonly property color colorCyan: palette.colors.color6

    // Fill for a "how much is left" bar: green while comfortable, yellow
    // under half, red under a fifth.
    function levelColor(percent) {
        return percent > 50 ? colorGreen : percent > 20 ? colorYellow : colorRed;
    }

    readonly property string barPosition: ThemeStore.barPosition
    readonly property bool vertical: barPosition === "left" || barPosition === "right"

    // The one unit every size derives from: the configurable base grid
    // (5px by default) times the size multiplier. Sizes that were designed
    // as multiples of 5 are expressed as gridUnit * k; anything else goes
    // through px() so it scales with the same factor.
    readonly property int gridUnit: ThemeStore.gridUnit * ThemeStore.sizeMultiplier
    readonly property real scale: ThemeStore.scale

    function px(n) {
        return Math.max(1, Math.round(n * scale));
    }

    readonly property string fontFamily: ThemeStore.fontFamily
    readonly property int fontSize: ThemeStore.fontSize
    readonly property real letterSpacing: 1.5 * scale

    readonly property int barThickness: gridUnit * 8
    readonly property int buttonSize: gridUnit * 6
    readonly property int tile: gridUnit * 4
    readonly property int panelWidth: gridUnit * 120
    readonly property int panelHeight: gridUnit * 144
}
