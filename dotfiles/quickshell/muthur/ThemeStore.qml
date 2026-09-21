pragma Singleton
import QtQuick
import Qt.labs.settings
import Quickshell
import Quickshell.Io

// Persisted, switchable color palette (GitHub issue #1). A singleton so
// every file's separate "Theme { id: theme }" instance — see Theme.qml —
// stays in sync and re-renders when the preset changes.
//
// Only the active preset key (and the layout settings) live in the inner
// `Settings` item, so the ini file stays small; `presets` is static data
// and never needs to round-trip through disk. `store.fileName` is set
// explicitly because Qt.labs.settings otherwise needs QCoreApplication's
// organizationName, which Quickshell doesn't set.
QtObject {
    id: root

    // Each preset is a pywal-style palette (special.background/foreground/
    // cursor + colors.color0..15 in ANSI order) plus a key and a name, so a
    // wallpaper-generated colors.json can be loaded the same way later.
    // The shell's own four colors derive from it: bg = background,
    // fg = foreground, dim = color8, focus = cursor. The twelve hue slots
    // are muted and pulled toward each theme's base so terminals and the
    // editor stay on-screen-of-one-phosphor rather than turning rainbow.
    readonly property var builtinPresets: [
        { key: "neoInTheMatrix", name: "NEO IN THE MATRIX",
          special: { background: "#04120a", foreground: "#33ff66", cursor: "#aaffcc" },
          colors: { color0: "#0a1a10", color1: "#b05a50", color2: "#33ff66", color3: "#b8c65a",
                    color4: "#4f9ab0", color5: "#9a6fb0", color6: "#4fd0b0", color7: "#9fd8b0",
                    color8: "#1a7a3a", color9: "#d9776a", color10: "#aaffcc", color11: "#d6e07a",
                    color12: "#7ec0d4", color13: "#bf98d4", color14: "#7ee8cc", color15: "#e0ffe8" } },
        // Tyrell's amber sun over a rain-black city: amber text, deep
        // blue as the secondary slot, warm white for the focus.
        { key: "bladeRunner", name: "BLADE RUNNER",
          special: { background: "#0a0c16", foreground: "#f0a828", cursor: "#ffd890" },
          colors: { color0: "#141828", color1: "#c8503a", color2: "#a0a048", color3: "#f0a828",
                    color4: "#3868c0", color5: "#a070a8", color6: "#48a0c0", color7: "#d0b890",
                    color8: "#6a4c1a", color9: "#e07050", color10: "#c0c068", color11: "#ffd890",
                    color12: "#6890e0", color13: "#c898d0", color14: "#70c0d8", color15: "#fff0d8" } },
        { key: "tron", name: "TRON",
          special: { background: "#04080f", foreground: "#6fc3df", cursor: "#f0a030" },
          colors: { color0: "#0a121c", color1: "#d07040", color2: "#58b8a0", color3: "#e0a850",
                    color4: "#3a8fbf", color5: "#8a90d0", color6: "#6fc3df", color7: "#a8d4e4",
                    color8: "#1f4a5c", color9: "#f08858", color10: "#80d8c0", color11: "#f8c070",
                    color12: "#60b0e8", color13: "#a8b0e8", color14: "#a0e0f8", color15: "#e0f6ff" } },
        // Ares's Grid: scarlet light lines on near-black, a white-hot core
        // as the focus color, chrome-silver for text highlights and a
        // muted Encom blue for the one contrasting slot.
        { key: "tronAres", name: "TRON ARES",
          special: { background: "#070203", foreground: "#ff2e2e", cursor: "#ffd6cc" },
          colors: { color0: "#140608", color1: "#ff2e2e", color2: "#b89a70", color3: "#e89a58",
                    color4: "#6a86b0", color5: "#c86a8c", color6: "#c98c94", color7: "#dcc8c8",
                    color8: "#7a1f1f", color9: "#ff7a6e", color10: "#d0b890", color11: "#ffb878",
                    color12: "#9ab0d8", color13: "#e498b8", color14: "#e8b0b0", color15: "#fff0ee" } },
        // The Gibson: aquamarine data on a violet-black city of towers,
        // hot magenta as the focus color, acid green and electric blue
        // in the hue slots. Hack the planet.
        { key: "hackers1995", name: "HACKERS 1995",
          special: { background: "#0a0616", foreground: "#4cf0c8", cursor: "#ff3fbf" },
          colors: { color0: "#160c28", color1: "#ff4f7a", color2: "#39e07a", color3: "#e8e05a",
                    color4: "#5a7cff", color5: "#c85aff", color6: "#4cf0c8", color7: "#b8c8e8",
                    color8: "#4a3a7a", color9: "#ff80a0", color10: "#80ffb0", color11: "#f8f080",
                    color12: "#8aa8ff", color13: "#e090ff", color14: "#90fce0", color15: "#f0f0ff" } },
        // Section 9: gunmetal greys, cool steel text, and the one red
        // of the title card as the focus color and error slot.
        { key: "ghostInTheShell", name: "GHOST IN THE SHELL",
          special: { background: "#101214", foreground: "#b8bcc0", cursor: "#d0303a" },
          colors: { color0: "#1a1d20", color1: "#d0303a", color2: "#8ea08a", color3: "#b8a888",
                    color4: "#7a8ca0", color5: "#a08aa0", color6: "#88a4a8", color7: "#b8bcc0",
                    color8: "#565c62", color9: "#e85a60", color10: "#a8c0a4", color11: "#d0c0a0",
                    color12: "#98acc0", color13: "#c0a8c0", color14: "#a8c4c8", color15: "#e8eaec" } },
        // Blacklight club: UV pink on black, toxic green as the focus
        // color, and the hue slots glowing like they're under a UV tube.
        { key: "cybergoth", name: "CYBERGOTH",
          special: { background: "#08040c", foreground: "#ff3fd8", cursor: "#b6ff1a" },
          colors: { color0: "#120a18", color1: "#ff3860", color2: "#b6ff1a", color3: "#ffe030",
                    color4: "#7a4fff", color5: "#ff3fd8", color6: "#40e8ff", color7: "#d0b8e0",
                    color8: "#5a2a78", color9: "#ff7090", color10: "#d4ff60", color11: "#fff080",
                    color12: "#a890ff", color13: "#ff80e8", color14: "#88f0ff", color15: "#f8f0ff" } },
        // 2049's Las Vegas: burnt orange through the dust, Wallace gold,
        // Joi's cyan as the one cool slot, dust-white focus.
        { key: "bladeRunner2049", name: "BLADE RUNNER 2049",
          special: { background: "#0e0a08", foreground: "#e0782c", cursor: "#f4e2c4" },
          colors: { color0: "#1a1210", color1: "#c84030", color2: "#a09060", color3: "#d8a050",
                    color4: "#5a7890", color5: "#a87888", color6: "#70a8b0", color7: "#d8c0a0",
                    color8: "#6a4020", color9: "#e86050", color10: "#c0b080", color11: "#f0c070",
                    color12: "#80a0b8", color13: "#c898a8", color14: "#90c8d0", color15: "#f8ecd8" } },
        // The Nostromo's bone-white padded corridors: one of the two light
        // presets. Dark warm text, an amber status light as the focus,
        // and color0 whiter than the background so panel surfaces lift.
        { key: "nostromo", name: "NOSTROMO",
          special: { background: "#e8e4d8", foreground: "#2c2a26", cursor: "#c07a18" },
          colors: { color0: "#f4f1e8", color1: "#a83428", color2: "#3e7a48", color3: "#a07818",
                    color4: "#3c6088", color5: "#7a4a80", color6: "#2e7880", color7: "#5c5850",
                    color8: "#8a8478", color9: "#c04a3c", color10: "#4c9058", color11: "#c09428",
                    color12: "#5078a8", color13: "#98609a", color14: "#3e949c", color15: "#1a1814" } },
        // "The color of television, tuned to a dead channel": static grey
        // background, ice-pale cyan text, Chiba neon pink as the focus.
        { key: "neuromancer", name: "NEUROMANCER",
          special: { background: "#0f1216", foreground: "#8ed4cc", cursor: "#ff5fa8" },
          colors: { color0: "#181c22", color1: "#e05070", color2: "#60c8a0", color3: "#c8b870",
                    color4: "#5a8ad8", color5: "#c070c8", color6: "#8ed4cc", color7: "#a8b8b8",
                    color8: "#465058", color9: "#ff7898", color10: "#88e0c0", color11: "#e0d090",
                    color12: "#88a8f0", color13: "#e098e8", color14: "#b0f0e8", color15: "#e8f4f4" } },
        // Neo-Tokyo: white on black with Kaneda's red as the focus, and the
        // city's neon left saturated in the hue slots.
        { key: "akira", name: "AKIRA",
          special: { background: "#0c0a0a", foreground: "#ece4dc", cursor: "#e8323a" },
          colors: { color0: "#181414", color1: "#e8323a", color2: "#70b070", color3: "#f0c040",
                    color4: "#4878d0", color5: "#9060c0", color6: "#50a8b8", color7: "#a8a09c",
                    color8: "#5a5250", color9: "#ff6060", color10: "#90d090", color11: "#ffd868",
                    color12: "#78a0f0", color13: "#b088e0", color14: "#78c8d8", color15: "#ffffff" } },
        // Human Revolution: gold on black, everything else pulled toward
        // brass.
        { key: "deusEx", name: "DEUS EX",
          special: { background: "#0a0805", foreground: "#d8a848", cursor: "#f8e0a8" },
          colors: { color0: "#161208", color1: "#c05038", color2: "#a0a058", color3: "#d8a848",
                    color4: "#6a8098", color5: "#a88070", color6: "#88a898", color7: "#c0a878",
                    color8: "#6a5020", color9: "#e07058", color10: "#c0c078", color11: "#f8e0a8",
                    color12: "#88a0b8", color13: "#c8a090", color14: "#a8c8b8", color15: "#fff4dc" } },
        // The Wired: the other light preset. Pale grey with white panel
        // surfaces (color0), near-black text and a deep red focus.
        { key: "lain", name: "SERIAL EXPERIMENTS LAIN",
          special: { background: "#d4d4d8", foreground: "#2e2e34", cursor: "#9c1420" },
          colors: { color0: "#ececf0", color1: "#9c1420", color2: "#4a7a5a", color3: "#8a7830",
                    color4: "#405880", color5: "#6c4a80", color6: "#3a7880", color7: "#606068",
                    color8: "#8c8c94", color9: "#c02838", color10: "#5c9070", color11: "#a89040",
                    color12: "#5870a0", color13: "#8860a0", color14: "#4c949c", color15: "#1c1c20" } },
        // Night City: electric yellow on black, cyan focus, magenta and
        // red left neon.
        { key: "cyberpunk2077", name: "CYBERPUNK 2077",
          special: { background: "#0c0c10", foreground: "#fcee09", cursor: "#00f0ff" },
          colors: { color0: "#161618", color1: "#ff003c", color2: "#a0e020", color3: "#fcee09",
                    color4: "#3a80ff", color5: "#ff2aa0", color6: "#00f0ff", color7: "#d0d0c0",
                    color8: "#5a5a30", color9: "#ff4070", color10: "#c0ff60", color11: "#fff860",
                    color12: "#70a8ff", color13: "#ff70c8", color14: "#70f8ff", color15: "#fffff0" } },
        // System Shock: SHODAN's crimson on black with a glitch-green focus.
        { key: "shodan", name: "SHODAN",
          special: { background: "#0a0406", foreground: "#e8305a", cursor: "#50ff80" },
          colors: { color0: "#160a0e", color1: "#e8305a", color2: "#50ff80", color3: "#d0a040",
                    color4: "#6060c0", color5: "#c050b0", color6: "#50c0c0", color7: "#d0a8b0",
                    color8: "#6a1a30", color9: "#ff6080", color10: "#90ffb0", color11: "#f0c060",
                    color12: "#9090e0", color13: "#e080d0", color14: "#80e0e0", color15: "#ffe8ec" } },
        // Orange on a deep blue night, bright blue as the focus: chunky
        // retro-future rather than grime.
        { key: "fifthElement", name: "THE FIFTH ELEMENT",
          special: { background: "#0c1020", foreground: "#ff8c28", cursor: "#40c8ff" },
          colors: { color0: "#161c30", color1: "#e04848", color2: "#68c070", color3: "#ffc040",
                    color4: "#4080f0", color5: "#c068c8", color6: "#40c8ff", color7: "#d8c8b0",
                    color8: "#4a4a70", color9: "#ff7070", color10: "#90e090", color11: "#ffd870",
                    color12: "#78a8ff", color13: "#e098e8", color14: "#80e0ff", color15: "#fff4e8" } },
        // OCP: steel-blue text on gunmetal, HUD cyan as the focus.
        { key: "robocop", name: "ROBOCOP",
          special: { background: "#0a0e14", foreground: "#9cb4c4", cursor: "#50e0f0" },
          colors: { color0: "#141a22", color1: "#c05048", color2: "#68a888", color3: "#b8a868",
                    color4: "#5088b8", color5: "#8878a8", color6: "#50e0f0", color7: "#b8c4cc",
                    color8: "#465868", color9: "#e07068", color10: "#88c8a8", color11: "#d0c088",
                    color12: "#78a8d8", color13: "#a898c8", color14: "#88ecf8", color15: "#ecf2f6" } },
        // PreCrime: icy white text on a dark glass panel, pale blue focus.
        { key: "minorityReport", name: "MINORITY REPORT",
          special: { background: "#0c1418", foreground: "#c8e8f4", cursor: "#60c8f8" },
          colors: { color0: "#182228", color1: "#d06060", color2: "#68b8a0", color3: "#c8c090",
                    color4: "#60a8e8", color5: "#a090d0", color6: "#70d0e8", color7: "#98b8c8",
                    color8: "#3a5868", color9: "#e88080", color10: "#90d8c0", color11: "#e0d8a8",
                    color12: "#88c0f8", color13: "#c0b0e8", color14: "#98e8f8", color15: "#f0fbff" } },
        // 1995 cyberspace: cyan on blue-black with a red focus.
        { key: "johnnyMnemonic", name: "JOHNNY MNEMONIC",
          special: { background: "#060a14", foreground: "#30d8e8", cursor: "#ff3050" },
          colors: { color0: "#101828", color1: "#ff3050", color2: "#40c890", color3: "#d8c050",
                    color4: "#4070e8", color5: "#b060d0", color6: "#30d8e8", color7: "#a8c0d8",
                    color8: "#284868", color9: "#ff6878", color10: "#70e0b0", color11: "#f0d870",
                    color12: "#7098ff", color13: "#d088e8", color14: "#78ecf8", color15: "#e8f8ff" } },
        // Bay City in the rain: hot pink text, cyan focus.
        { key: "alteredCarbon", name: "ALTERED CARBON",
          special: { background: "#0c0810", foreground: "#ff4fa0", cursor: "#40e8f8" },
          colors: { color0: "#181020", color1: "#ff4060", color2: "#50d0a0", color3: "#f0c050",
                    color4: "#5080f0", color5: "#ff4fa0", color6: "#40e8f8", color7: "#c8b8d0",
                    color8: "#503858", color9: "#ff7088", color10: "#80e8c0", color11: "#f8d878",
                    color12: "#80a8ff", color13: "#ff88c0", color14: "#88f0ff", color15: "#f8f0fc" } },
        // Sibyl System: clean cyan-blue with a purple focus.
        { key: "psychoPass", name: "PSYCHO-PASS",
          special: { background: "#0a0c14", foreground: "#78c8e0", cursor: "#a070e8" },
          colors: { color0: "#141826", color1: "#d05868", color2: "#60b8a0", color3: "#c0b070",
                    color4: "#5090e0", color5: "#a070e8", color6: "#78c8e0", color7: "#a8b8d0",
                    color8: "#3c4870", color9: "#e87888", color10: "#88d8c0", color11: "#d8cc90",
                    color12: "#80b0f8", color13: "#c098f8", color14: "#a0e0f0", color15: "#ecf0ff" } },
        // Session title cards: yellow on black with a red focus.
        { key: "cowboyBebop", name: "COWBOY BEBOP",
          special: { background: "#0e0c0a", foreground: "#f0c840", cursor: "#e03838" },
          colors: { color0: "#1a1614", color1: "#e03838", color2: "#90a860", color3: "#f0c840",
                    color4: "#5880a8", color5: "#a878a0", color6: "#68a8a8", color7: "#d8ccb0",
                    color8: "#5a5040", color9: "#ff6058", color10: "#b0c880", color11: "#ffe070",
                    color12: "#80a0c8", color13: "#c898c0", color14: "#88c8c8", color15: "#fff8e8" } },
        // The Nostromo's own screens: yellow-green CRT text with the
        // white-flash of a fresh line as the focus.
        { key: "muthur6000", name: "MU-TH-UR 6000",
          special: { background: "#0a0c06", foreground: "#a8d848", cursor: "#f0f0c0" },
          colors: { color0: "#141a0c", color1: "#c05840", color2: "#a8d848", color3: "#d0c048",
                    color4: "#5890a0", color5: "#9878a8", color6: "#68c0a0", color7: "#c0d0a0",
                    color8: "#4a6820", color9: "#e07858", color10: "#c8f070", color11: "#e8e070",
                    color12: "#80b0c0", color13: "#b898c8", color14: "#90e0c0", color15: "#f4f8e8" } },
        // E-paper: the light twin of Monochrome. Paper grey (not pure
        // white, like a real panel), ink-black text and focus, and the
        // hue slots reduced to greys with the faintest tint.
        { key: "eInk", name: "E-INK",
          special: { background: "#e4e4e0", foreground: "#1c1c1a", cursor: "#000000" },
          colors: { color0: "#f2f2ee", color1: "#6a5050", color2: "#506050", color3: "#605c48",
                    color4: "#4c5060", color5: "#5c5060", color6: "#4c5c5c", color7: "#5a5a58",
                    color8: "#8c8c88", color9: "#584040", color10: "#405040", color11: "#4c4838",
                    color12: "#3c4050", color13: "#4c4050", color14: "#3c4c4c", color15: "#101010" } },
        { key: "monochrome", name: "MONOCHROME",
          special: { background: "#0a0a0a", foreground: "#c8c8c8", cursor: "#ffffff" },
          colors: { color0: "#141414", color1: "#b09090", color2: "#a0b0a0", color3: "#b0b090",
                    color4: "#9090b0", color5: "#b090b0", color6: "#90b0b0", color7: "#c8c8c8",
                    color8: "#5a5a5a", color9: "#d0b0b0", color10: "#b8d0b8", color11: "#d0d0b0",
                    color12: "#b0b0d0", color13: "#d0b0d0", color14: "#b0d0d0", color15: "#ffffff" } }
    ]

    // The wallpaper-derived palette, when a wallpaper is set, appears as
    // one more preset. Its JSON is cached in the ini so a restart doesn't
    // flash a fallback theme while the image is re-analyzed.
    readonly property var wallpaperPalette: {
        if (!root.store.wallpaperColors)
            return null;
        try {
            const p = paletteFromPywal(JSON.parse(root.store.wallpaperColors));
            return p ? Object.assign({ key: "wallpaper", name: "WALLPAPER" }, p) : null;
        } catch (e) {
            return null;
        }
    }
    readonly property var presets: wallpaperPalette ? builtinPresets.concat([wallpaperPalette]) : builtinPresets

    readonly property Settings store: Settings {
        fileName: Quickshell.shellDir + "/theme.ini"
        category: "theme"

        property string preset: "neoInTheMatrix"

        // Layout (GitHub issue #12). int/string only: Qt.labs.settings
        // hands a `real` back as a string after a round-trip.
        property string barPosition: "left"
        property int sizeMultiplier: 1
        property int gridUnit: 5

        // Percent, so it stays an int (see above).
        property int terminalOpacity: 80

        // "claude", "codex" or "" — whose 5h session bar the [AI] button shows.
        property string defaultAgent: ""

        // Wallpaper image path and the palette generated from it (pywal
        // JSON as a string), see setWallpaper(); the directory the LOOK
        // tab's thumbnail grid lists ("" = ~/Pictures/Wallpapers).
        property string wallpaper: ""
        property string wallpaperColors: ""
        property string wallpapersPath: ""
    }

    readonly property var palette: presets.find(p => p.key === root.store.preset) || presets[0]
    readonly property string preset: palette.key
    readonly property color colorBg: palette.special.background
    readonly property color colorFg: palette.special.foreground
    readonly property color colorDim: palette.colors.color8
    readonly property color colorFocus: palette.special.cursor

    function color(i) {
        return palette.colors["color" + i];
    }

    // Validates a pywal colors.json object (special + color0..15) and
    // returns it normalized, or null. The wallpaper-based theme feature
    // will feed presets through this.
    function paletteFromPywal(obj) {
        if (!obj || !obj.special || !obj.colors)
            return null;
        const special = {};
        for (const k of ["background", "foreground", "cursor"]) {
            if (typeof obj.special[k] !== "string")
                return null;
            special[k] = obj.special[k];
        }
        const colors = {};
        for (let i = 0; i < 16; i++) {
            if (typeof obj.colors["color" + i] !== "string")
                return null;
            colors["color" + i] = obj.colors["color" + i];
        }
        return { special: special, colors: colors };
    }

    readonly property string wallpaper: root.store.wallpaper
    property string wallpaperError: ""
    property bool wallpaperBusy: false

    readonly property string defaultWallpapersPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string wallpapersPath: root.store.wallpapersPath || defaultWallpapersPath
    readonly property int maxWallpapers: 24

    function setWallpapersPath(path) {
        path = path.trim();
        if (path.startsWith("~/"))
            path = Quickshell.env("HOME") + path.substring(1);
        root.store.wallpapersPath = path === defaultWallpapersPath ? "" : path;
    }

    // Analyzes the image with scripts/wallpaper-palette.py, makes the
    // result the WALLPAPER preset, applies it and shows the image with
    // swaybg. A bad path leaves the current theme alone and reports.
    function setWallpaper(path) {
        path = path.trim();
        if (!path)
            return;
        root.wallpaperError = "";
        root.wallpaperBusy = true;
        root.paletteProcess.command = [Quickshell.shellDir + "/scripts/wallpaper-palette.py", path];
        root.paletteProcess.running = true;
    }

    function clearWallpaper() {
        root.store.wallpaper = "";
        root.store.wallpaperColors = "";
        root.wallpaperError = "";
        if (root.store.preset === "wallpaper")
            applyPreset(builtinPresets[0].key);
        root.showWallpaper();
    }

    // swaybg draws the image, or the theme's background when none is set.
    function showWallpaper() {
        const args = root.wallpaper
            ? ["swaybg", "-i", root.wallpaper, "-m", "fill"]
            : ["swaybg", "-c", root.colorBg.toString()];
        Quickshell.execDetached(["sh", "-c", "pkill -x swaybg; exec \"$@\"", "swaybg", ...args]);
    }

    readonly property Process paletteProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpaperBusy = false;
                let data;
                try {
                    data = JSON.parse(this.text);
                } catch (e) {
                    root.wallpaperError = "[ COULDN'T READ THE IMAGE ]";
                    return;
                }
                if (data.error || !root.paletteFromPywal(data)) {
                    root.wallpaperError = "[ " + (data.error || "bad palette").toUpperCase() + " ]";
                    return;
                }
                root.store.wallpaper = data.wallpaper;
                root.store.wallpaperColors = JSON.stringify(data);
                root.applyPreset("wallpaper");
                root.showWallpaper();
            }
        }
    }

    readonly property var barPositions: ["left", "top", "right", "bottom"]
    readonly property int minGridUnit: 3
    readonly property int maxGridUnit: 10
    readonly property int maxSizeMultiplier: 4
    // gridUnit * sizeMultiplier is the unit every size derives from; past
    // this the bar is 8 * 20 = 160px thick and the font 52px.
    readonly property int maxEffectiveUnit: 20

    // Clamped on read too, so a hand-edited theme.ini can't yield scale 0.
    readonly property string barPosition: barPositions.includes(root.store.barPosition) ? root.store.barPosition : "left"
    readonly property int sizeMultiplier: Math.max(1, Math.min(maxSizeMultiplier, root.store.sizeMultiplier))
    readonly property int gridUnit: Math.max(minGridUnit, Math.min(maxGridUnit, root.store.gridUnit))
    readonly property int terminalOpacity: Math.max(10, Math.min(100, root.store.terminalOpacity))
    readonly property var agents: ["claude", "codex"]
    readonly property string defaultAgent: agents.includes(root.store.defaultAgent) ? root.store.defaultAgent : ""

    // Shared with Theme.qml, and with generated configs for apps that
    // should type in the same face and size as the shell.
    readonly property string fontFamily: "Noto Sans Mono"
    readonly property real scale: root.gridUnit * root.sizeMultiplier / 5
    readonly property int fontSize: Math.max(1, Math.round(13 * scale))

    function setBarPosition(position) {
        if (barPositions.includes(position))
            root.store.barPosition = position;
    }

    function setSizeMultiplier(n) {
        n = Math.max(1, Math.min(maxSizeMultiplier, Math.round(n)));
        if (root.gridUnit * n <= maxEffectiveUnit) {
            root.store.sizeMultiplier = n;
            root.writeFuzzelColors();
        }
    }

    function setGridUnit(n) {
        n = Math.max(minGridUnit, Math.min(maxGridUnit, Math.round(n)));
        if (n * root.sizeMultiplier <= maxEffectiveUnit) {
            root.store.gridUnit = n;
            root.writeFuzzelColors();
        }
    }

    function setDefaultAgent(agent) {
        root.store.defaultAgent = agents.includes(agent) ? agent : "";
    }

    function setTerminalOpacity(percent) {
        root.store.terminalOpacity = Math.max(10, Math.min(100, Math.round(percent)));
        root.writeAlacrittyColors();
        // Neovim and btop switch between painting the background and
        // letting the terminal's show through at 100% vs less.
        root.writeNvimTheme();
        root.writeBtopTheme();
    }

    // Keeps fuzzel's colors and font in sync (GitHub issue #4). fuzzel.ini
    // "include"s this file directly, so it just needs rewriting whenever
    // the preset or size changes — fuzzel re-reads its config fresh on
    // every launch, no reload signal needed. The font is set here rather
    // than in fuzzel.ini so it tracks the shell's size multiplier.
    readonly property FileView fuzzelColors: FileView {
        path: Quickshell.env("HOME") + "/.config/fuzzel/colors.ini"
        printErrors: true
    }

    function writeFuzzelColors() {
        const bg = root.colorBg.toString().replace("#", "");
        const fg = root.colorFg.toString().replace("#", "");
        const focus = root.colorFocus.toString().replace("#", "");
        root.fuzzelColors.setText(
            "[main]\n" +
            "font=" + root.fontFamily + ":pixelsize=" + root.fontSize + "\n" +
            "\n" +
            "[colors]\n" +
            "background=" + bg + "ee\n" +
            "text=" + fg + "ff\n" +
            "match=" + focus + "ff\n" +
            "selection=" + fg + "ff\n" +
            "selection-text=" + bg + "ff\n" +
            "selection-match=" + bg + "ff\n" +
            "border=" + fg + "ff\n"
        );
    }

    // Keeps labwc's window decorations in sync. rc.xml sets no
    // <theme><name>, so labwc never loads a themerc from a theme
    // directory — themerc-override (labwc-theme(5)) is the *only* file
    // that actually applies, on top of labwc's compiled-in defaults.
    // That's why structural settings (button size, padding, justify)
    // live here too, not just colors — dotfiles/labwc/themerc alone
    // would silently be ignored.
    readonly property FileView labwcTheme: FileView {
        path: Quickshell.env("HOME") + "/.config/labwc/themerc-override"
        printErrors: true
    }

    function writeLabwcTheme() {
        const bg = root.colorBg.toString();
        const fg = root.colorFg.toString();
        const dim = root.colorDim.toString();
        const focus = root.colorFocus.toString();
        root.labwcTheme.setText(
            "window.label.text.justify: left\n" +
            "window.titlebar.padding.width: 5\n" +
            "window.titlebar.padding.height: 5\n" +
            "window.button.width: 30\n" +
            "window.button.height: 30\n" +
            "window.button.spacing: 0\n" +
            "window.active.border.color: " + fg + "\n" +
            "window.inactive.border.color: " + dim + "\n" +
            "window.active.title.bg.color: " + bg + "\n" +
            "window.inactive.title.bg.color: " + bg + "\n" +
            "window.active.label.text.color: " + fg + "\n" +
            "window.inactive.label.text.color: " + dim + "\n" +
            "window.active.button.unpressed.image.color: " + fg + "\n" +
            "window.inactive.button.unpressed.image.color: " + dim + "\n" +
            "window.button.hover.bg.color: " + fg + "33\n" +
            "window.active.indicator.toggled-keybind.color: " + focus + "\n" +
            "menu.border.color: " + fg + "\n" +
            "menu.items.bg.color: " + bg + "\n" +
            "menu.items.text.color: " + fg + "\n" +
            "menu.items.active.bg.color: " + dim + "\n" +
            "menu.items.active.text.color: " + bg + "\n" +
            "menu.separator.color: " + dim + "\n" +
            "menu.title.bg.color: " + bg + "\n" +
            "menu.title.text.color: " + focus + "\n" +
            "osd.bg.color: " + bg + "\n" +
            "osd.border.color: " + fg + "\n" +
            "osd.label.text.color: " + fg + "\n" +
            "osd.window-switcher.style-classic.item.active.border.color: " + focus + "\n" +
            "osd.window-switcher.style-classic.item.active.bg.color: " + dim + "\n"
        );
        // Harmless no-op if labwc isn't the running compositor.
        Quickshell.execDetached(["labwc", "-r"]);
    }

    // Keeps alacritty's colors and window opacity in sync. alacritty.toml
    // "import"s this file (imports load before the importing file, so any
    // [colors] or window.opacity set there would win — deliberately left
    // out of alacritty.toml entirely). alacritty's live_config_reload
    // watches imports too, so open terminals pick changes up instantly.
    readonly property FileView alacrittyColors: FileView {
        path: Quickshell.env("HOME") + "/.config/alacritty/colors.toml"
        printErrors: true
    }

    function writeAlacrittyColors() {
        const c = i => "\"" + root.color(i) + "\"";
        const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        const block = offset => names.map((n, i) => n + " = " + c(i + offset)).join("\n");
        root.alacrittyColors.setText(
            "[window]\n" +
            "opacity = " + (root.terminalOpacity / 100).toFixed(2) + "\n" +
            "\n" +
            "[colors]\n" +
            "draw_bold_text_with_bright_colors = true\n" +
            "\n" +
            "[colors.primary]\n" +
            "background = \"" + root.colorBg.toString() + "\"\n" +
            "foreground = \"" + root.colorFg.toString() + "\"\n" +
            "\n" +
            "[colors.cursor]\n" +
            "text = \"" + root.colorBg.toString() + "\"\n" +
            "cursor = \"" + root.colorFocus.toString() + "\"\n" +
            "\n" +
            "[colors.selection]\n" +
            "text = \"" + root.colorBg.toString() + "\"\n" +
            "background = \"" + root.colorDim.toString() + "\"\n" +
            "\n" +
            "[colors.normal]\n" + block(0) + "\n" +
            "\n" +
            "[colors.bright]\n" + block(8) + "\n"
        );
    }

    // Keeps herdr's UI theme in sync. herdr's config.toml has no
    // import/include mechanism (confirmed against its own docs), so
    // unlike fuzzel/labwc/alacritty there's no separate file to
    // generate — this patches the [theme.custom] block in place between
    // marker comments, leaving the rest of the (git-tracked, symlinked)
    // config.toml untouched. If the markers are missing — file not
    // installed yet, or hand-edited away — this does nothing rather
    // than guess where to write.
    readonly property FileView herdrConfig: FileView {
        path: Quickshell.env("HOME") + "/.config/herdr/config.toml"
        printErrors: true
        // Read-modify-write needs .text() to return the current file
        // synchronously, unlike the write-only FileViews above.
        blockLoading: true
        // setText() otherwise saves asynchronously, so the
        // `herdr server reload-config` right after it could run before
        // the write actually lands on disk — reloading the *previous*
        // preset's colors and only catching up on the next call.
        blockWrites: true
    }

    function writeHerdrTheme() {
        const bg = root.colorBg.toString();
        const fg = root.colorFg.toString();
        const dim = root.colorDim.toString();
        const focus = root.colorFocus.toString();

        const beginMarker = "# --- BEGIN generated (ThemeStore.qml writeHerdrTheme) ---";
        const endMarker = "# --- END generated ---";
        const text = root.herdrConfig.text();
        const beginIdx = text.indexOf(beginMarker);
        const endIdx = text.indexOf(endMarker);
        if (beginIdx === -1 || endIdx === -1 || endIdx < beginIdx)
            return;

        const body =
            "accent = \"" + focus + "\"\n" +
            "panel_bg = \"" + bg + "\"\n" +
            "sidebar_bg = \"" + bg + "\"\n" +
            "active_row_bg = \"" + dim + "\"\n" +
            "selection_bg = \"" + dim + "\"\n" +
            "surface0 = \"" + root.color(0) + "\"\n" +
            "surface1 = \"" + dim + "\"\n" +
            "surface_dim = \"" + bg + "\"\n" +
            "overlay0 = \"" + dim + "\"\n" +
            "overlay1 = \"" + root.color(7) + "\"\n" +
            "text = \"" + fg + "\"\n" +
            "subtext0 = \"" + root.color(7) + "\"\n" +
            "mauve = \"" + root.color(5) + "\"\n" +
            "green = \"" + root.color(2) + "\"\n" +
            "yellow = \"" + root.color(3) + "\"\n" +
            "red = \"" + root.color(1) + "\"\n" +
            "blue = \"" + root.color(4) + "\"\n" +
            "teal = \"" + root.color(6) + "\"\n" +
            "peach = \"" + root.color(11) + "\"\n";

        root.herdrConfig.setText(
            text.substring(0, beginIdx + beginMarker.length) + "\n" +
            body +
            text.substring(endIdx)
        );
        // Harmless no-op if herdr's server isn't running.
        Quickshell.execDetached(["herdr", "server", "reload-config"]);
    }

    // Keeps the "muthur" Neovim colorscheme in sync. colors/muthur.lua
    // is nothing but color, so — unlike herdr's config.toml — it's
    // fully regenerated each time rather than patched in place.
    // LazyVim is told to use it by the separately-tracked (static)
    // dotfiles/nvim/plugins/muthur-theme.lua. Syntax groups map onto the
    // palette's 16 slots with their usual meanings (strings green,
    // errors red, ...), which reads as tinted rather than rainbow because
    // every slot is muted toward the theme's base. No live reload:
    // Neovim applies a colorscheme at startup; open instances follow
    // through the file watcher in dotfiles/nvim/lua/config/autocmds.lua,
    // which re-runs ":colorscheme muthur" when this file is rewritten.
    readonly property FileView nvimTheme: FileView {
        path: Quickshell.env("HOME") + "/.config/nvim/colors/muthur.lua"
        printErrors: true
    }

    function writeNvimTheme() {
        const groups = [
            // UI
            ["Normal", "fg = fg, bg = base"], ["NormalFloat", "fg = fg, bg = base"],
            ["FloatBorder", "fg = dim, bg = base"], ["CursorLine", "bg = c0"],
            ["CursorLineNr", "fg = focus, bold = true"], ["LineNr", "fg = dim"],
            ["Visual", "bg = dim"], ["Search", "fg = bg, bg = focus"],
            ["IncSearch", "fg = bg, bg = focus"], ["CurSearch", "fg = bg, bg = focus"],
            ["Pmenu", "fg = fg, bg = c0"], ["PmenuSel", "fg = bg, bg = focus"],
            ["PmenuSbar", "bg = c0"], ["PmenuThumb", "bg = dim"],
            ["StatusLine", "fg = fg, bg = c0"], ["StatusLineNC", "fg = dim, bg = base"],
            ["VertSplit", "fg = dim, bg = base"], ["WinSeparator", "fg = dim, bg = base"],
            ["TabLine", "fg = dim, bg = base"], ["TabLineSel", "fg = fg, bg = c0"],
            ["TabLineFill", "bg = base"], ["WinBar", "fg = fg, bg = base"],
            ["WinBarNC", "fg = dim, bg = base"], ["Title", "fg = focus, bold = true"],
            ["Directory", "fg = c4"], ["SignColumn", "bg = base"],
            ["FoldColumn", "fg = dim, bg = base"], ["Folded", "fg = dim, bg = c0"],
            ["NonText", "fg = dim"], ["SpecialKey", "fg = dim"],
            ["Whitespace", "fg = c0"], ["MatchParen", "fg = c11, bold = true, underline = true"],
            ["ColorColumn", "bg = c0"], ["QuickFixLine", "bg = c0"],
            ["ErrorMsg", "fg = c1, bold = true"], ["WarningMsg", "fg = c3"],
            ["MoreMsg", "fg = c2"], ["Question", "fg = c2"],
            // Syntax
            ["Comment", "fg = c8, italic = true"], ["String", "fg = c2"],
            ["Character", "fg = c2"], ["Number", "fg = c5"],
            ["Float", "fg = c5"], ["Boolean", "fg = c5"],
            ["Constant", "fg = c5"], ["Identifier", "fg = fg"],
            ["Function", "fg = c6, bold = true"], ["Statement", "fg = c4, bold = true"],
            ["Keyword", "fg = c4, bold = true"], ["Conditional", "fg = c4"],
            ["Repeat", "fg = c4"], ["Label", "fg = c4"],
            ["Operator", "fg = fg"], ["Exception", "fg = c1"],
            ["PreProc", "fg = c5"], ["Include", "fg = c5"],
            ["Define", "fg = c5"], ["Macro", "fg = c5"],
            ["Type", "fg = c3, bold = true"], ["StorageClass", "fg = c3"],
            ["Structure", "fg = c3"], ["Typedef", "fg = c3"],
            ["Special", "fg = c6"], ["SpecialComment", "fg = c8, italic = true"],
            ["Delimiter", "fg = c7"], ["Underlined", "fg = c4, underline = true"],
            ["Todo", "fg = bg, bg = c11, bold = true"], ["Error", "fg = bg, bg = c1, bold = true"],
            // Diagnostics / diff / git
            ["DiagnosticError", "fg = c1"], ["DiagnosticWarn", "fg = c3"],
            ["DiagnosticInfo", "fg = c4"], ["DiagnosticHint", "fg = c6"],
            ["DiagnosticOk", "fg = c2"],
            ["DiagnosticUnderlineError", "sp = c1, undercurl = true"],
            ["DiagnosticUnderlineWarn", "sp = c3, undercurl = true"],
            ["DiagnosticUnderlineInfo", "sp = c4, undercurl = true"],
            ["DiagnosticUnderlineHint", "sp = c6, undercurl = true"],
            ["DiffAdd", "fg = c2, bg = c0"], ["DiffChange", "fg = c3, bg = c0"],
            ["DiffDelete", "fg = c1, bg = c0"], ["DiffText", "fg = c11, bg = c0, bold = true"],
            ["Added", "fg = c2"], ["Changed", "fg = c3"], ["Removed", "fg = c1"],
            ["GitSignsAdd", "fg = c2"], ["GitSignsChange", "fg = c3"], ["GitSignsDelete", "fg = c1"],
            // Treesitter / LSP
            ["@variable", "fg = fg"], ["@variable.builtin", "fg = c5"],
            ["@variable.parameter", "fg = c7"], ["@variable.member", "fg = fg"],
            ["@constant", "fg = c5"], ["@constant.builtin", "fg = c5"],
            ["@module", "fg = c3"], ["@string", "fg = c2"],
            ["@string.escape", "fg = c14"], ["@string.special", "fg = c6"],
            ["@character", "fg = c2"], ["@number", "fg = c5"],
            ["@boolean", "fg = c5"], ["@function", "fg = c6, bold = true"],
            ["@function.builtin", "fg = c6"], ["@function.call", "fg = c6"],
            ["@function.method", "fg = c6"], ["@constructor", "fg = c3"],
            ["@keyword", "fg = c4, bold = true"], ["@keyword.function", "fg = c4"],
            ["@keyword.return", "fg = c4, bold = true"], ["@keyword.operator", "fg = c4"],
            ["@keyword.import", "fg = c5"], ["@conditional", "fg = c4"],
            ["@repeat", "fg = c4"], ["@operator", "fg = fg"],
            ["@punctuation", "fg = c7"], ["@punctuation.bracket", "fg = c7"],
            ["@punctuation.delimiter", "fg = c7"], ["@type", "fg = c3, bold = true"],
            ["@type.builtin", "fg = c3"], ["@property", "fg = fg"],
            ["@attribute", "fg = c5"], ["@comment", "fg = c8, italic = true"],
            ["@comment.todo", "fg = bg, bg = c11, bold = true"],
            ["@comment.error", "fg = bg, bg = c1, bold = true"],
            ["@comment.warning", "fg = bg, bg = c3, bold = true"],
            ["@tag", "fg = c4"], ["@tag.attribute", "fg = c3"], ["@tag.delimiter", "fg = c7"],
            ["@markup.heading", "fg = focus, bold = true"], ["@markup.link", "fg = c4, underline = true"],
            ["@markup.raw", "fg = c2"], ["@markup.list", "fg = c6"],
            ["@markup.strong", "bold = true"], ["@markup.italic", "italic = true"],
            ["@diff.plus", "fg = c2"], ["@diff.minus", "fg = c1"], ["@diff.delta", "fg = c3"],
            ["@lsp.type.parameter", "fg = c7"], ["@lsp.type.property", "fg = fg"]
        ];

        const hlLines = groups.map(g => "hl(0, \"" + g[0] + "\", { " + g[1] + " })").join("\n");
        const colorLines = [];
        for (let i = 0; i < 16; i++)
            colorLines.push("local c" + i + " = \"" + root.color(i) + "\"");

        root.nvimTheme.setText(
            "-- Generated by ThemeStore.qml (writeNvimTheme) — do not edit by\n" +
            "-- hand, changes are overwritten on every preset switch.\n" +
            "vim.cmd(\"hi clear\")\n" +
            "if vim.fn.exists(\"syntax_on\") then vim.cmd(\"syntax reset\") end\n" +
            "vim.o.background = \"" + (root.colorBg.hslLightness > 0.5 ? "light" : "dark") + "\"\n" +
            "vim.g.colors_name = \"muthur\"\n" +
            "\n" +
            "local bg = \"" + root.colorBg.toString() + "\"\n" +
            // Alacritty's opacity only applies to its default background,
            // so a translucent terminal needs the editor to leave the
            // window background unpainted (NONE) and show through; bg
            // itself stays a real color for inverted text.
            "local base = " + (root.terminalOpacity < 100 ? "\"NONE\"" : "bg") + "\n" +
            "local fg = \"" + root.colorFg.toString() + "\"\n" +
            "local dim = \"" + root.colorDim.toString() + "\"\n" +
            "local focus = \"" + root.colorFocus.toString() + "\"\n" +
            colorLines.join("\n") + "\n" +
            "local hl = vim.api.nvim_set_hl\n" +
            "\n" +
            "-- Terminal buffers use the same 16 slots.\n" +
            colorLines.map((_, i) => "vim.g.terminal_color_" + i + " = c" + i).join("\n") + "\n" +
            "\n" +
            hlLines + "\n"
        );
    }

    // btop reads a theme file from its themes/ directory (hex colors
    // only, so it's generated) and reloads it on SIGUSR2, which is sent
    // to any running instance after the write.
    readonly property FileView btopTheme: FileView {
        path: Quickshell.env("HOME") + "/.config/btop/themes/muthur.theme"
        printErrors: true
    }

    function writeBtopTheme() {
        const bg = root.colorBg.toString();
        const fg = root.colorFg.toString();
        const dim = root.colorDim.toString();
        const focus = root.colorFocus.toString();
        const c = i => root.color(i).toString();
        const entries = [
            // An empty main_bg is btop's "terminal default", which is the
            // only background alacritty makes translucent.
            ["main_bg", root.terminalOpacity < 100 ? "" : bg],
            ["main_fg", fg], ["title", fg], ["hi_fg", focus],
            // Selected row inverts like the shell's filled buttons.
            ["selected_bg", fg], ["selected_fg", bg],
            ["inactive_fg", dim], ["graph_text", fg], ["meter_bg", c(0)],
            ["proc_misc", c(4)],
            // One border color for every box, like the shell's panels.
            ["cpu_box", fg], ["mem_box", fg], ["net_box", fg], ["proc_box", fg],
            ["div_line", dim],
            // Level gradients go green -> yellow -> red like levelColor().
            ["temp_start", c(2)], ["temp_mid", c(3)], ["temp_end", c(1)],
            ["cpu_start", c(2)], ["cpu_mid", c(3)], ["cpu_end", c(1)],
            ["free_start", c(2)], ["free_mid", c(2)], ["free_end", c(10)],
            ["cached_start", c(6)], ["cached_mid", c(6)], ["cached_end", c(14)],
            ["available_start", c(3)], ["available_mid", c(3)], ["available_end", c(11)],
            ["used_start", c(2)], ["used_mid", c(3)], ["used_end", c(1)],
            ["download_start", c(4)], ["download_mid", c(12)], ["download_end", c(14)],
            ["upload_start", c(5)], ["upload_mid", c(13)], ["upload_end", c(9)],
            ["process_start", c(2)], ["process_mid", c(3)], ["process_end", c(1)]
        ];
        root.btopTheme.setText(
            "# Generated by ThemeStore.qml (writeBtopTheme) — do not edit by\n" +
            "# hand, changes are overwritten on every preset switch.\n" +
            entries.map(e => "theme[" + e[0] + "]=\"" + e[1] + "\"").join("\n") + "\n"
        );
        // Harmless no-op if no btop is running.
        Quickshell.execDetached(["pkill", "-USR2", "-x", "btop"]);
    }

    function applyPreset(key) {
        if (!presets.some(p => p.key === key))
            return;
        root.store.preset = key;
        root.writeFuzzelColors();
        root.writeLabwcTheme();
        root.writeAlacrittyColors();
        root.writeHerdrTheme();
        root.writeNvimTheme();
        root.writeBtopTheme();
        // The solid background follows the preset when no image is set.
        if (!root.wallpaper)
            root.showWallpaper();
    }

    Component.onCompleted: {
        root.writeFuzzelColors();
        root.writeLabwcTheme();
        root.writeAlacrittyColors();
        root.writeHerdrTheme();
        root.writeNvimTheme();
        root.writeBtopTheme();
        if (root.wallpaper)
            root.showWallpaper();
    }
}
