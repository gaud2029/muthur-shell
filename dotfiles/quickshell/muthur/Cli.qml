pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The shell side of the `muthur` command (GitHub issue #35,
// dotfiles/bin/muthur): one registry entry per setting the panels expose,
// each going through the same function the panel calls, so the CLI and
// the UI can't drift apart. A new setting gets an entry here and `muthur
// get/set/list` and the completion pick it up.
//
// Values travel as strings; on/off for booleans. Every IPC call returns
// a result, or a message starting with "error: ".
Singleton {
    id: root

    // --- Entry builders ----------------------------------------------
    //
    // { key, type, help, get(): value, set(value): "" | error message,
    //   values(): [...] (enum, list), min/max (int) }

    function entry(type, key, help, get, set, extra) {
        return Object.assign({ key: key, type: type, help: help, get: get, set: set }, extra || {});
    }

    function boolEntry(key, help, get, set) {
        return entry("bool", key, help, get, set);
    }

    function intEntry(key, help, min, max, get, set) {
        return entry("int", key, help, get, set, { min: min, max: max });
    }

    function enumEntry(key, help, values, get, set) {
        return entry("enum", key, help, get, set, { values: values });
    }

    // --- Audio helpers -----------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => !!o)
    }

    function nodeLabel(n) {
        return n ? (n.description || n.nickname || n.name) : "";
    }

    function audioNodes(type) {
        return Pipewire.nodes.values.filter(n => !n.isStream && (n.type & type) === type);
    }

    function audioOf(node, what) {
        if (!node || !node.audio)
            return "no default " + what;
        return "";
    }

    // --- The registry ------------------------------------------------

    readonly property var entries: [
        // LOOK
        enumEntry("look.preset", "color preset",
            () => ThemeStore.presets.map(p => p.key),
            () => ThemeStore.preset,
            v => { ThemeStore.applyPreset(v); return ""; }),
        // A theme's own wallpaper is picked with its theme, like its
        // thumbnail in LOOK; any other image is analyzed for a palette.
        entry("string", "look.wallpaper", "wallpaper image path, or none",
            () => ThemeStore.wallpaper || "none",
            v => {
                if (v === "" || v === "none") {
                    ThemeStore.clearWallpaper();
                    return "";
                }
                const path = v.startsWith("~/") ? Quickshell.env("HOME") + v.substring(1) : v;
                const themed = path.match(/\/([^/]+)\/([^/]+)\.png$/);
                const index = themed ? ThemeStore.themedDesigns.indexOf(themed[2]) : -1;
                if (index >= 0 && path === ThemeStore.themedWallpaper(themed[1], index))
                    ThemeStore.pickTheme(themed[1], index);
                else
                    ThemeStore.setWallpaper(path);
                return "";
            }),
        boolEntry("look.wallpaper-theme", "picking a wallpaper also switches to its colors",
            () => ThemeStore.themeFromWallpaper,
            v => { ThemeStore.setThemeFromWallpaper(v); return ""; }),
        entry("string", "look.wallpapers-dir", "directory the wallpaper grid lists",
            () => ThemeStore.wallpapersPath,
            v => { ThemeStore.setWallpapersPath(v); return ""; }),
        enumEntry("look.font", "monospace family for the shell, fuzzel and alacritty",
            () => ThemeStore.monoFontFamilies,
            () => ThemeStore.fontFamily,
            v => { ThemeStore.setFontFamily(v); return ""; }),
        intEntry("look.size", "size multiplier (size × grid ≤ " + ThemeStore.maxEffectiveUnit + ")",
            1, ThemeStore.maxSizeMultiplier,
            () => ThemeStore.sizeMultiplier,
            v => {
                if (v * ThemeStore.gridUnit > ThemeStore.maxEffectiveUnit)
                    return "too big with look.grid " + ThemeStore.gridUnit + " (size × grid ≤ " + ThemeStore.maxEffectiveUnit + ")";
                ThemeStore.setSizeMultiplier(v);
                return "";
            }),
        intEntry("look.grid", "base grid unit in px (size × grid ≤ " + ThemeStore.maxEffectiveUnit + ")",
            ThemeStore.minGridUnit, ThemeStore.maxGridUnit,
            () => ThemeStore.gridUnit,
            v => {
                if (v * ThemeStore.sizeMultiplier > ThemeStore.maxEffectiveUnit)
                    return "too big with look.size " + ThemeStore.sizeMultiplier + " (size × grid ≤ " + ThemeStore.maxEffectiveUnit + ")";
                ThemeStore.setGridUnit(v);
                return "";
            }),
        intEntry("look.terminal-opacity", "alacritty background opacity, percent", 10, 100,
            () => ThemeStore.terminalOpacity,
            v => { ThemeStore.setTerminalOpacity(v); return ""; }),

        // DISPLAY
        enumEntry("display.bar-position", "screen edge the bar sits on",
            () => ThemeStore.barPositions,
            () => ThemeStore.barPosition,
            v => { ThemeStore.setBarPosition(v); return ""; }),
        enumEntry("display.main", "main display: popups, notifications, the OSD",
            () => Quickshell.screens.map(s => s.name),
            () => ThemeStore.mainScreen,
            v => { ThemeStore.setMainScreen(v); return ""; }),
        enumEntry("display.bar-on", "a bar on every display, or the main one only",
            () => ["all", "main"],
            () => ThemeStore.barOnMainOnly ? "main" : "all",
            v => { ThemeStore.setBarOnMainOnly(v === "main"); return ""; }),
        intEntry("display.brightness", "backlight, percent", 1, 100,
            () => Osd.brightness() < 0 ? "none" : Math.round(Osd.brightness() * 100),
            v => Osd.setBrightness(v / 100) < 0 ? "no backlight device" : ""),
        boolEntry("display.nightlight", "night light",
            () => NightLight.enabled,
            v => { if (v !== NightLight.enabled) NightLight.toggle(); return ""; }),
        enumEntry("display.nightlight.mode", "always, fixed hours, or the sun at a location",
            () => ["always", "schedule", "sun"],
            () => NightLight.mode,
            v => { NightLight.setMode(v); return ""; }),
        intEntry("display.nightlight.temperature", "warmth in kelvin (rounded to 100)",
            NightLight.minTemperature, NightLight.maxTemperature,
            () => NightLight.temperature,
            v => { NightLight.setTemperature(v); return ""; }),
        entry("time", "display.nightlight.warm-at", "schedule: warm from HH:MM",
            () => NightLight.store.sunset,
            v => { NightLight.setTimes(v, NightLight.store.sunrise); return ""; }),
        entry("time", "display.nightlight.day-at", "schedule: back to day at HH:MM",
            () => NightLight.store.sunrise,
            v => { NightLight.setTimes(NightLight.store.sunset, v); return ""; }),
        entry("string", "display.nightlight.location", "sun mode: LAT,LON in decimal degrees, or none",
            () => NightLight.locationSet ? NightLight.store.latitude + "," + NightLight.store.longitude : "none",
            v => {
                if (v === "none" || v === "") {
                    NightLight.setLocation("", "");
                    return "";
                }
                const parts = v.split(",");
                if (parts.length !== 2 || !NightLight.validCoordinate(parts[0].trim(), 90)
                        || !NightLight.validCoordinate(parts[1].trim(), 180))
                    return "expected LAT,LON (e.g. 45.5,-73.6)";
                NightLight.setLocation(parts[0], parts[1]);
                return "";
            }),

        // AUDIO
        enumEntry("audio.output", "default output device",
            () => root.audioNodes(PwNodeType.AudioSink).map(root.nodeLabel),
            () => root.nodeLabel(root.sink) || "none",
            v => {
                const node = root.audioNodes(PwNodeType.AudioSink).find(n => root.nodeLabel(n) === v);
                Pipewire.preferredDefaultAudioSink = node;
                return "";
            }),
        intEntry("audio.volume", "output volume, percent", 0, 100,
            () => root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) : "none",
            v => root.audioOf(root.sink, "output") || (root.sink.audio.volume = v / 100, "")),
        boolEntry("audio.mute", "output muted",
            () => !!(root.sink && root.sink.audio && root.sink.audio.muted),
            v => root.audioOf(root.sink, "output") || (root.sink.audio.muted = v, "")),
        enumEntry("audio.input", "default input device",
            () => root.audioNodes(PwNodeType.AudioSource).map(root.nodeLabel),
            () => root.nodeLabel(root.source) || "none",
            v => {
                const node = root.audioNodes(PwNodeType.AudioSource).find(n => root.nodeLabel(n) === v);
                Pipewire.preferredDefaultAudioSource = node;
                return "";
            }),
        intEntry("audio.input-volume", "input volume, percent", 0, 100,
            () => root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) : "none",
            v => root.audioOf(root.source, "input") || (root.source.audio.volume = v / 100, "")),
        boolEntry("audio.input-mute", "input muted",
            () => !!(root.source && root.source.audio && root.source.audio.muted),
            v => root.audioOf(root.source, "input") || (root.source.audio.muted = v, "")),
        enumEntry("audio.ambience", "ambient sound",
            () => Keyboard.soundAmbiences.map(a => a.key),
            () => Keyboard.soundAmbienceType,
            v => { Keyboard.setSoundAmbienceType(v); return ""; }),
        enumEntry("audio.ambience.mode", "plays all along, or follows typing",
            () => ["continuous", "typing"],
            () => Keyboard.soundAmbienceFollow ? "typing" : "continuous",
            v => { Keyboard.setSoundAmbienceFollow(v === "typing"); return ""; }),
        intEntry("audio.ambience.level", "ambient sound level, percent", 0, 100,
            () => Keyboard.soundAmbience,
            v => { Keyboard.setSoundAmbience(v); return ""; }),

        // KEYBOARD
        entry("list", "keyboard.layouts", "configured layouts, comma-separated (xkb names: us, ca, fr(dvorak)...)",
            () => Keyboard.layouts.join(","),
            v => Keyboard.setLayouts(v),
            { values: () => Keyboard.catalog.map(e => e.key) }),
        enumEntry("keyboard.layout", "active layout",
            () => Keyboard.layouts,
            () => Keyboard.current,
            v => { Keyboard.select(Keyboard.layouts.indexOf(v)); return ""; }),
        intEntry("keyboard.repeat-rate", "key repeats per second", Keyboard.minRepeatRate, Keyboard.maxRepeatRate,
            () => Keyboard.repeatRate,
            v => { Keyboard.setRepeat(v, Keyboard.repeatDelay); return ""; }),
        intEntry("keyboard.repeat-delay", "ms before the first repeat (rounded to 10)", Keyboard.minRepeatDelay, Keyboard.maxRepeatDelay,
            () => Keyboard.repeatDelay,
            v => { Keyboard.setRepeat(Keyboard.repeatRate, v); return ""; }),
        enumEntry("keyboard.sound", "typing sound theme",
            () => Keyboard.soundThemes.map(t => t.key),
            () => Keyboard.soundTheme,
            v => { Keyboard.setSoundTheme(v); return ""; }),
        enumEntry("keyboard.sound.when", "typing sounds always, or only in focus mode",
            () => ["always", "focus"],
            () => Keyboard.soundWhen,
            v => { Keyboard.setSoundWhen(v); return ""; }),
        intEntry("keyboard.sound.volume", "typing sound volume, percent", 0, 100,
            () => Keyboard.soundVolume,
            v => { Keyboard.setSoundVolume(v); return ""; }),

        // AI, notifications, focus
        enumEntry("ai.default", "whose 5h session bar the [AI] button shows",
            () => ["none"].concat(ThemeStore.agents),
            () => ThemeStore.defaultAgent || "none",
            v => { ThemeStore.setDefaultAgent(v === "none" ? "" : v); return ""; }),
        boolEntry("notifications.dnd", "do-not-disturb: only critical notifications pop up",
            () => Notifications.dnd,
            v => { Notifications.dnd = v; return ""; }),
        boolEntry("focus", "focus mode: the bar folds away",
            () => Focus.active,
            v => { Focus.active = v; return ""; }),
        boolEntry("caffeine", "caffeine mode: no idle screen-off or lock",
            () => Caffeine.active,
            v => { Caffeine.active = v; return ""; })
    ]

    function find(key) {
        return entries.find(e => e.key === key) || null;
    }

    function format(e, value) {
        return e.type === "bool" ? (value ? "on" : "off") : String(value);
    }

    // The string as the entry's type, or { error }.
    function parse(e, text) {
        switch (e.type) {
        case "bool": {
            const t = text.toLowerCase();
            if (["on", "true", "yes", "1"].includes(t)) return { value: true };
            if (["off", "false", "no", "0"].includes(t)) return { value: false };
            return { error: "\"" + text + "\" is not on or off" };
        }
        case "int": {
            if (!/^-?\d+$/.test(text))
                return { error: "\"" + text + "\" is not a whole number" };
            const n = parseInt(text);
            if (n < e.min || n > e.max)
                return { error: n + " is outside " + e.min + ".." + e.max };
            return { value: n };
        }
        case "enum": {
            const values = e.values();
            if (values.includes(text))
                return { value: text };
            const ci = values.find(v => v.toLowerCase() === text.toLowerCase());
            if (ci !== undefined)
                return { value: ci };
            return { error: "\"" + text + "\" is not one of " + values.join(", ") };
        }
        case "time":
            if (!NightLight.validTime(text))
                return { error: "\"" + text + "\" is not HH:MM" };
            return { value: text };
        case "list":
            return { value: text.split(",").map(s => s.trim()).filter(s => s) };
        default:
            return { value: text };
        }
    }

    function setOne(key, text) {
        const e = find(key);
        if (!e)
            return key + ": unknown setting (muthur list)";
        const p = parse(e, text);
        if (p.error)
            return key + ": " + p.error;
        const err = e.set(p.value);
        return err ? key + ": " + err : "";
    }

    function describe(e) {
        const d = { key: e.key, type: e.type, value: format(e, e.get()), help: e.help };
        if (e.values)
            d.values = e.values();
        if (e.type === "int") {
            d.min = e.min;
            d.max = e.max;
        }
        return d;
    }

    // Fonts are only listed after a scan (the LOOK tab does one on open).
    Component.onCompleted: ThemeStore.scanFonts()

    IpcHandler {
        target: "muthur"

        function get(key: string): string {
            const e = root.find(key);
            return e ? root.format(e, e.get()) : "error: " + key + ": unknown setting (muthur list)";
        }

        // Every setting, as a JSON object (snapshots, `get --json`).
        function getAll(): string {
            const all = {};
            for (const e of root.entries)
                all[e.key] = root.format(e, e.get());
            return JSON.stringify(all);
        }

        function set(key: string, value: string): string {
            const err = root.setOne(key, value);
            return err ? "error: " + err : "";
        }

        function toggle(key: string): string {
            const e = root.find(key);
            if (!e)
                return "error: " + key + ": unknown setting (muthur list)";
            if (e.type !== "bool")
                return "error: " + key + ": not an on/off setting";
            const err = e.set(!e.get());
            return err ? "error: " + key + ": " + err : "";
        }

        // A JSON object of key: value (a snapshot). Only what differs is
        // set; the wallpaper before the preset (picking one can switch the
        // preset); what fails gets a second pass (look.size and look.grid
        // limit each other).
        function setMany(json: string): string {
            let all;
            try {
                all = JSON.parse(json);
            } catch (e) {
                return "error: not JSON";
            }
            const first = ["look.wallpaper-theme", "look.wallpaper"];
            const keys = first.filter(k => k in all)
                .concat(Object.keys(all).filter(k => !first.includes(k) && k !== "look.preset"))
                .concat("look.preset" in all ? ["look.preset"] : [])
                .filter(k => {
                    const e = root.find(k);
                    return !e || root.format(e, e.get()) !== String(all[k]);
                });
            let failed = keys.filter(k => root.setOne(k, String(all[k])));
            failed = failed.map(k => root.setOne(k, String(all[k]))).filter(err => err);
            return failed.length ? "error: " + failed.join("\nerror: ") : "";
        }

        // Every setting with its type, current value, allowed values and
        // help, as JSON (`muthur list`, completion).
        function list(): string {
            return JSON.stringify({ settings: root.entries.map(root.describe), ui: Ui.targets, screens: Ui.barScreens });
        }

        function uiOpen(target: string, screen: string): string {
            const err = Ui.open(target, screen);
            return err ? "error: " + err : "";
        }

        function uiClose(): string {
            Ui.close();
            return "";
        }
    }
}
