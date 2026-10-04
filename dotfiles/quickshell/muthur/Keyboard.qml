pragma Singleton
import QtQuick
import Qt.labs.settings
import Quickshell
import Quickshell.Io

// Keyboard layouts and key repeat (GitHub issue #8). labwc has no action
// to switch layouts, but it re-reads its environment files on reconfigure
// and rebuilds the keymap from XKB_DEFAULT_LAYOUT: the active layout is
// written to environment.d/muthur-keyboard.env, alone, and labwc
// reconfigured. Only one layout is loaded at a time, so the bar button
// is always right about which one is active. Key repeat lives in rc.xml
// (labwc has no other place for it), whose two values are rewritten in
// place.
//
// Cycled from the bar's layout button, or from outside with
//   quickshell ipc -c muthur call keyboard next
Singleton {
    id: root

    readonly property Settings store: Settings {
        fileName: Quickshell.shellDir + "/keyboard.ini"
        category: "keyboard"

        // The configured layouts in xkb's "layout" or "layout(variant)"
        // form, comma-separated, and the index of the active one.
        property string layouts: ""
        property int active: 0

        // Typing sounds: the key theme ("off" = no player), the ambience
        // under the keys, and volume and ambience level in percent.
        property string soundTheme: "off"
        property string soundAmbienceType: "drone"
        property int soundVolume: 50
        property int soundAmbience: 50
    }

    readonly property var layouts: store.layouts ? store.layouts.split(",") : ["us"]
    readonly property int active: Math.max(0, Math.min(layouts.length - 1, store.active))
    readonly property string current: layouts[active]

    // The bar's label: the layout code, without the variant.
    function shortLabel(entry) {
        return entry.split("(")[0].toUpperCase();
    }

    // xkb's own name for it, e.g. "French (Canada, Dvorak)".
    function describe(entry) {
        return root.names[entry] || entry;
    }

    function select(i) {
        if (i < 0 || i >= root.layouts.length)
            return;
        root.store.active = i;
        root.apply();
    }

    function next() {
        if (root.layouts.length > 1)
            root.select((root.active + 1) % root.layouts.length);
    }

    function add(entry) {
        if (root.layouts.includes(entry) || !root.names[entry])
            return;
        root.store.layouts = root.layouts.concat([entry]).join(",");
    }

    function remove(i) {
        if (root.layouts.length < 2)
            return;
        const current = root.current;
        const kept = root.layouts.filter((_, j) => j !== i);
        root.store.layouts = kept.join(",");
        // Removing the active layout falls back to the first one.
        root.store.active = Math.max(0, kept.indexOf(current));
        root.apply();
    }

    // Every layout and variant xkb knows, as { key, name } sorted by name,
    // for the KEYBOARD tab's search; and the same names by key.
    property var catalog: []
    property var names: ({})

    readonly property FileView rules: FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: root.parseRules(text())
    }

    // "! layout" lines are "  ca   French (Canada)"; "! variant" lines
    // are "  fr-dvorak   ca: French (Canada, Dvorak)".
    function parseRules(text) {
        const names = {};
        const catalog = [];
        let section = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("! ")) {
                section = line.slice(2).trim();
                continue;
            }
            const m = line.match(/^\s+(\S+)\s+(.+)$/);
            if (!m)
                continue;
            let key = m[1];
            let name = m[2];
            if (section === "variant") {
                const v = name.match(/^(\S+):\s*(.+)$/);
                if (!v)
                    continue;
                key = v[1] + "(" + m[1] + ")";
                name = v[2];
            } else if (section !== "layout") {
                continue;
            }
            names[key] = name;
            catalog.push({ key: key, name: name });
        }
        root.names = names;
        root.catalog = catalog.sort((a, b) => a.name.localeCompare(b.name));
    }

    readonly property FileView envFile: FileView {
        path: Quickshell.env("HOME") + "/.config/labwc/environment.d/muthur-keyboard.env"
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    // Written only when it changes: a reconfigure reloads all of labwc's
    // config, and on startup the file labwc read at login is usually
    // already right.
    function apply() {
        const text = "# Written by the muthur shell's [SYS] KEYBOARD tab; edits are overwritten.\n"
            + "XKB_DEFAULT_LAYOUT=" + root.current + "\n";
        if (root.envFile.text() === text)
            return;
        root.envFile.setText(text);
        Quickshell.execDetached(["labwc", "-r"]);
    }

    // Key repeat: repeats per second, and ms before the first one.
    readonly property int minRepeatRate: 5
    readonly property int maxRepeatRate: 80
    readonly property int minRepeatDelay: 150
    readonly property int maxRepeatDelay: 1000
    property int repeatRate: 25
    property int repeatDelay: 600

    readonly property FileView rcFile: FileView {
        path: Quickshell.env("HOME") + "/.config/labwc/rc.xml"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.readRepeat()
    }

    function readRepeat() {
        const text = root.rcFile.text();
        const rate = text.match(/<repeatRate>\s*(\d+)\s*<\/repeatRate>/);
        const delay = text.match(/<repeatDelay>\s*(\d+)\s*<\/repeatDelay>/);
        root.repeatRate = rate ? Number(rate[1]) : 25;
        root.repeatDelay = delay ? Number(delay[1]) : 600;
    }

    // Shown at once; written once the slider settles, not on every step
    // of a drag.
    function setRepeat(rate, delay) {
        root.repeatRate = Math.max(minRepeatRate, Math.min(maxRepeatRate, Math.round(rate)));
        root.repeatDelay = Math.max(minRepeatDelay, Math.min(maxRepeatDelay, Math.round(delay / 10) * 10));
        repeatWriter.restart();
    }

    function setTag(text, tag, value) {
        const re = new RegExp("<" + tag + ">\\s*\\d+\\s*</" + tag + ">");
        const element = "<" + tag + ">" + value + "</" + tag + ">";
        return re.test(text) ? text.replace(re, element)
            : text.replace(/<keyboard>/, "<keyboard>\n    " + element);
    }

    Timer {
        id: repeatWriter
        interval: 400
        onTriggered: {
            const before = root.rcFile.text();
            const after = root.setTag(root.setTag(before, "repeatRate", root.repeatRate),
                                      "repeatDelay", root.repeatDelay);
            if (after === before)
                return;
            root.rcFile.setText(after);
            Quickshell.execDetached(["labwc", "-r"]);
        }
    }

    Component.onCompleted: {
        // First run: start from whatever labwc was started with.
        if (!root.store.layouts)
            root.store.layouts = (Quickshell.env("XKB_DEFAULT_LAYOUT") || "us").split(",")[0];
        root.readRepeat();
        root.apply();
        root.syncPlayer();
    }

    // --- Typing sounds (GitHub issue #21) ------------------------------
    //
    // muthur-keysound plays them: a PipeWire player that takes key
    // presses from the muthur-keysound-input system service (keycodes
    // never reach it, only what kind of key and roughly where) and
    // synthesizes the theme's sounds, placed left to right like the keys,
    // over a binaural drone that swells while typing. It runs only while
    // a theme is picked, and takes its settings over stdin.
    // Both are installed by dotfiles/keysound/install-keysound.sh.

    readonly property var soundThemes: [
        { key: "off", label: "OFF", about: "" },
        { key: "muthur", label: "MU/TH/UR", about: "TERMINAL BLIPS. ITS DRONE: A MAINFRAME HUM, THETA 6 HZ." },
        { key: "nostromo", label: "NOSTROMO", about: "HEAVY DECK CLICKS. ITS DRONE: THE ENGINE ROOM, ALPHA 10 HZ." },
        { key: "thocc", label: "NOSTROMO THOCC", about: "DEEP AND CREAMY, ALL BODY AND NO CLICK: A LUBED BOARD ON A HEAVY CASE." }
    ]
    readonly property var soundAmbiences: [
        { key: "drone", label: "THEME DRONE", about: "THE KEY THEME'S BINAURAL DRONE: A CLOSE PITCH IN EACH EAR, HEARD AS A SLOW BEAT." },
        { key: "vessel", label: "VESSEL", about: "INSIDE THE SHIP: AIR HANDLING, A DEEP RUMBLE, THE HULL TICKING NOW AND THEN. NO PITCH." },
        { key: "rain", label: "HULL RAIN", about: "RAIN ON THE HULL: A FINE HISS OVERHEAD, A MUFFLED ROAR, DROPS ALL AROUND, A LEAK TO THE LEFT." },
        { key: "softrain", label: "SOFT RAIN", about: "RAIN HEARD THROUGH THICK PLATING: A MUFFLED WASH SWELLING IN SLOW GUSTS, THE ODD HEAVY DROP. NOTHING HIGH." },
        { key: "lowerdeck", label: "LOWER DECK", about: "MACHINERY TURNING OVER BELOW: A BROAD THROB WITH NO PITCH, A STEAM VENT LETTING GO NOW AND THEN." },
        { key: "bridge", label: "BRIDGE", about: "A QUIET ROOM: SOFT AIR AND RELAYS TICKING IN THE CONSOLES AROUND YOU." },
        { key: "lifesupport", label: "LIFE SUPPORT", about: "VENTILATION BREATHING IN AND OUT, A CONSOLE CHIRPING NOW AND THEN." }
    ]
    readonly property string soundTheme: soundThemes.some(t => t.key === store.soundTheme) ? store.soundTheme : "off"
    readonly property string soundAmbienceType: soundAmbiences.some(a => a.key === store.soundAmbienceType) ? store.soundAmbienceType : "drone"
    readonly property int soundVolume: Math.max(0, Math.min(100, store.soundVolume))
    readonly property int soundAmbience: Math.max(0, Math.min(100, store.soundAmbience))

    // "off"; "starting"; "missing" (the player isn't installed);
    // "waiting" (no input service to listen to); "connected".
    property string soundStatus: "off"

    function setSoundTheme(key) {
        if (!root.soundThemes.some(t => t.key === key))
            return;
        root.store.soundTheme = key;
        root.syncPlayer();
        root.sendSound();
    }

    function setSoundAmbienceType(key) {
        if (!root.soundAmbiences.some(a => a.key === key))
            return;
        root.store.soundAmbienceType = key;
        root.sendSound();
    }

    function setSoundVolume(percent) {
        root.store.soundVolume = Math.max(0, Math.min(100, Math.round(percent)));
        root.sendSound();
    }

    function setSoundAmbience(percent) {
        root.store.soundAmbience = Math.max(0, Math.min(100, Math.round(percent)));
        root.sendSound();
    }

    // A sweep of keys from left to right.
    function testSound() {
        if (root.player.running)
            root.player.write("test\n");
    }

    function sendSound() {
        if (root.player.running && root.soundTheme !== "off")
            root.player.write("theme " + root.soundTheme + "\nambience " + root.soundAmbienceType
                + "\nvolume " + root.soundVolume / 100
                + "\ndrone " + root.soundAmbience / 100 + "\n");
    }

    // Started and stopped by hand rather than bound: a player that dies
    // while a theme is on gets restarted (see onExited).
    function syncPlayer() {
        const wanted = root.soundTheme !== "off";
        if (wanted && !root.player.running) {
            root.soundStatus = "starting";
            root.player.running = true;
            missingCheck.restart();
        } else if (!wanted) {
            root.player.running = false;
            root.soundStatus = "off";
        }
    }

    readonly property Process player: Process {
        command: ["muthur-keysound"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                if (line === "input connected" || line === "input waiting") {
                    root.soundStatus = line.slice(6);
                    root.sendSound();
                }
            }
        }
        onExited: if (root.soundTheme !== "off" && root.soundStatus !== "missing") restartPlayer.restart()
    }

    // The player says "input waiting" as soon as it runs; silence means
    // it never started.
    Timer {
        id: missingCheck
        interval: 1500
        onTriggered: if (root.soundStatus === "starting") root.soundStatus = "missing"
    }

    Timer {
        id: restartPlayer
        interval: 2000
        onTriggered: root.syncPlayer()
    }

    IpcHandler {
        target: "keyboard"

        function next(): void {
            root.next();
        }

        function current(): string {
            return root.current;
        }
    }
}
