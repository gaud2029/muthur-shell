pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The launcher (Super+Space, LauncherPanel.qml), in place of fuzzel: the
// open windows, the installed applications, the commands run from it
// before, and whatever
// was typed as a shell command when nothing else is wanted — Enter on
// `echo test > test.txt` runs it, with bash in $HOME. A prefix switches
// mode: `=` calculates. Opened from labwc
// with
//   quickshell ipc -c muthur call launcher toggle
// or `muthur ui open launcher`.
Singleton {
    id: root

    property bool visible: false
    // The output it opens on ("" = the main screen).
    property string screenName: ""
    property string query: ""

    // How many times each application was launched, by desktop id, and
    // the commands run, most recent first.
    readonly property IniSettings store: IniSettings {
        location: "file://" + Quickshell.shellDir + "/launcher.ini"
        category: "launcher"

        property string usage: "{}"
        property string history: "[]"
    }

    readonly property int historyLimit: 30

    function parse(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return fallback;
        }
    }

    readonly property var usage: parse(store.usage, {})
    readonly property var history: parse(store.history, [])

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var windows: ToplevelManager.toplevels.values

    function open(screen) {
        root.screenName = screen || "";
        root.query = "";
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open("");
    }

    // --- Matching ----------------------------------------------------
    //
    // Prefixes and substrings only, no scattered-letter fuzzy matching:
    // a command typed out ("ls -la") shouldn't find some application
    // whose name happens to hold those letters in order.

    // 2: the text starts with q, 1: one of its words does.
    function textScore(text, q) {
        const t = (text || "").toLowerCase();
        if (t.startsWith(q))
            return 2;
        return t.split(/[\s\-_.]+/).some(w => w.startsWith(q)) ? 1 : 0;
    }

    // Strong (>= 10): the name matches. Weak: only the generic name, the
    // executable or a keyword does — those come after the commands run
    // before, so "ec" finds `echo ...` ahead of some app tagged "record".
    function appScore(entry, q) {
        const exec = (entry.command && entry.command.length > 0 ? entry.command[0] : "").split("/").pop();
        const name = textScore(entry.name, q);
        if (name > 0)
            return 10 * name;
        return Math.max(textScore(exec, q) * 2, textScore(entry.genericName, q),
            ...(entry.keywords || []).map(k => textScore(k, q)));
    }

    // A window by its app id or title: strong when either starts with q,
    // weak when only a word of the title does.
    function windowScore(toplevel, q) {
        const best = Math.max(textScore(toplevel.appId, q), textScore(toplevel.title, q));
        return best === 2 ? 20 : best;
    }

    // --- `=` calculator ----------------------------------------------
    //
    // Numbers, + - * / % ^ and parentheses, and the functions and
    // constants below; anything else is refused before it gets near the
    // JavaScript engine.

    readonly property var mathNames: ({
        sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
        log: Math.log10, ln: Math.log, exp: Math.exp, min: Math.min, max: Math.max,
        pi: Math.PI, e: Math.E
    })

    // { value: "23" } or { error: "..." }.
    function calculate(expr) {
        if (!/^[0-9a-z\s+\-*\/%^().,]*$/i.test(expr))
            return { error: "numbers, + - * / % ^ ( ) and sqrt, ln, log, sin, pi..." };
        const unknown = (expr.match(/[a-z]+/gi) || []).find(n => !(n.toLowerCase() in root.mathNames));
        if (unknown)
            return { error: "unknown: " + unknown };
        const js = expr.replace(/\^/g, "**").replace(/[a-z]+/gi, n => "M." + n.toLowerCase());
        try {
            const v = new Function("M", "return (" + js + ");")(root.mathNames);
            if (typeof v !== "number" || !isFinite(v))
                return { error: "no finite result" };
            // 0.1 + 0.2 shows 0.3.
            return { value: String(Number(v.toPrecision(12))) };
        } catch (e) {
            return { error: "incomplete expression" };
        }
    }

    function calcResults(expr) {
        if (!expr)
            return [{ kind: "calc", tag: "CALC", label: "= _", detail: "type an expression: = 2^10 / 3" }];
        const r = calculate(expr);
        return r.error
            ? [{ kind: "calc", tag: "CALC", label: "= ?", detail: r.error }]
            : [{ kind: "calc", tag: "CALC", label: "= " + r.value, detail: expr + "   ENTER COPIES", value: r.value }];
    }

    // [{ kind, tag, label, detail, ... }], best first: windows and
    // applications by name, commands run before, the other windows and
    // applications, then the typed text itself. kind is "win" (with
    // `toplevel`), "app" (`entry`), "cmd" or "run" (`command`), or
    // "calc" (`value`) after a `=`.
    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        const raw = root.query.trim();
        if (raw.startsWith("="))
            return calcResults(raw.substring(1).trim());
        const used = id => Math.min(root.usage[id] || 0, 9);

        const windows = root.windows
            .map(t => ({ toplevel: t, score: q ? windowScore(t, q) : 20 }))
            .filter(r => r.score > 0)
            .map(r => ({ kind: "win", tag: "WIN", strong: r.score >= 10, label: r.toplevel.title || r.toplevel.appId,
                detail: r.toplevel.appId, toplevel: r.toplevel }));

        const apps = root.apps
            .map(e => ({ entry: e, score: q ? appScore(e, q) : 10 }))
            .filter(r => r.score > 0)
            .sort((a, b) => (b.score + used(b.entry.id) / 10) - (a.score + used(a.entry.id) / 10)
                || a.entry.name.localeCompare(b.entry.name))
            .map(r => ({ kind: "app", tag: "APP", strong: r.score >= 10, label: r.entry.name.toUpperCase(),
                detail: r.entry.genericName || r.entry.comment, entry: r.entry }));

        const strong = windows.filter(r => r.strong).concat(apps.filter(r => r.strong));
        const weak = windows.filter(r => !r.strong).concat(apps.filter(r => !r.strong));
        if (!raw)
            return strong;

        const cmds = root.history
            .filter(c => c.toLowerCase().startsWith(q) && c !== raw)
            .map(c => ({ kind: "cmd", tag: "CMD", label: c, detail: "", command: c }));

        return strong.concat(cmds, weak, [{ kind: "run", tag: "RUN", label: raw, detail: "", command: raw }]);
    }

    // --- Launching ---------------------------------------------------

    readonly property string home: Quickshell.env("HOME")

    function launch(result, inTerminal) {
        if (!result)
            return;
        if (result.kind === "calc") {
            // Nothing to copy yet: stay open.
            if (result.value === undefined)
                return;
            Quickshell.execDetached(["wl-copy", result.value]);
        } else if (result.kind === "win")
            result.toplevel.activate();
        else if (result.kind === "app")
            launchApp(result.entry, inTerminal);
        else
            runCommand(result.command, inTerminal);
        root.close();
    }

    function launchApp(entry, inTerminal) {
        const counts = Object.assign({}, root.usage);
        counts[entry.id] = (counts[entry.id] || 0) + 1;
        store.usage = JSON.stringify(counts);

        // Terminal=true entries (yazi, btop...) run in alacritty, as
        // fuzzel's `terminal=alacritty -e` did.
        if (entry.runInTerminal || inTerminal)
            Quickshell.execDetached({
                command: ["alacritty", "-e"].concat(entry.command),
                workingDirectory: entry.workingDirectory || root.home
            });
        else
            entry.execute();
    }

    // Detached, through bash in $HOME, its output thrown away — or in an
    // alacritty that stays open to show it.
    function runCommand(command, inTerminal) {
        store.history = JSON.stringify([command].concat(root.history.filter(c => c !== command)).slice(0, root.historyLimit));
        Quickshell.execDetached({
            command: inTerminal ? ["alacritty", "--hold", "-e", "bash", "-c", command] : ["bash", "-c", command],
            workingDirectory: root.home
        });
    }

    // Typed: the typed text as a command, whatever matched.
    function runQuery(inTerminal) {
        const raw = root.query.trim();
        if (!raw)
            return;
        runCommand(raw, inTerminal);
        root.close();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open("");
        }

        function close(): void {
            root.close();
        }
    }
}
