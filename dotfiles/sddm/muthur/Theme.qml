import QtQuick

// The greeter's stand-in for the shell's Theme.qml: the same property
// names, so CrtScreen, VectorTerrain and TypedText (copied in from the
// shell by install-sddm.sh) work unchanged, but a fixed palette — the
// greeter runs before any user's preset exists. Matches the Plymouth
// theme: phosphor green on near-black, bone for what the crew types.
QtObject {
    readonly property color colorBg: "#030805"
    readonly property color colorFg: "#33ff66"
    readonly property color colorDim: "#1d6b38"
    readonly property color colorFocus: "#b8ffca"
    readonly property color colorBone: "#dcdfd1"
    readonly property color colorRed: "#ff4d40"
    readonly property color colorGreen: "#33ff66"
    readonly property color colorYellow: "#ffbf33"
    readonly property string fontFamily: "Noto Sans Mono"
}
