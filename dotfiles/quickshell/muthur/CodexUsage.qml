pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Codex quota, read over the `codex app-server` JSON protocol. Same
// refresh policy and on-disk cache as ClaudeUsage.
Singleton {
    id: root

    property bool active: false
    readonly property bool background: ThemeStore.defaultAgent === "codex"
    property bool fetching: false
    property bool installed: false
    property real sessionRemaining: 0
    property string sessionReset: ""
    property real weekRemaining: 0
    property string weekReset: ""
    property bool sessionAvailable: false
    property bool weekAvailable: false
    // When the numbers above were read (ms since epoch); 0 before the first read.
    property real updatedAt: 0
    // Why the last fetch failed, cleared by the next good one.
    property string error: ""
    // Set once a fetch has finished, even one that found no codex.
    property bool checked: false
    readonly property bool hasData: updatedAt > 0
    // Shown instead of the bars only while there's no data at all.
    readonly property string fallbackMessage: hasData ? "" : error
    readonly property bool loaded: hasData || checked
    readonly property bool ready: hasData && installed

    function refresh() {
        if (fetching || whichProcess.running || usageProcess.running)
            return;
        fetching = true;
        requestTimeout.restart();
        whichProcess.running = true;
    }

    // Reopening the panel right after a read shouldn't spawn another one.
    function refreshIfStale() {
        if (Date.now() - updatedAt > 30000)
            refresh();
    }

    function finish(message) {
        error = message;
        fetching = false;
        checked = true;
        requestTimeout.stop();
        whichProcess.running = false;
        usageProcess.running = false;
    }

    function resetText(window) {
        return window && typeof window.resetsAt === "number"
            ? "resets " + Qt.formatDateTime(new Date(window.resetsAt * 1000), "ddd HH:mm") : "";
    }

    function validWindow(window) {
        return window && typeof window.usedPercent === "number" && isFinite(window.usedPercent);
    }

    function readLimits(result) {
        // Prefer the Codex bucket over any model-specific limits.
        const limits = result && ((result.rateLimitsByLimitId || {}).codex || result.rateLimits);
        const windows = limits ? [limits.primary, limits.secondary] : [];
        const session = windows.find(w => w && w.windowDurationMins === 300);
        const week = windows.find(w => w && w.windowDurationMins === 10080);
        const hasSession = !!validWindow(session);
        const hasWeek = !!validWindow(week);
        if (!hasSession && !hasWeek) {
            finish("[ CODEX QUOTAS UNAVAILABLE ]");
            return;
        }
        sessionAvailable = hasSession;
        weekAvailable = hasWeek;
        sessionRemaining = hasSession ? Math.max(0, Math.min(100, 100 - session.usedPercent)) : 0;
        weekRemaining = hasWeek ? Math.max(0, Math.min(100, 100 - week.usedPercent)) : 0;
        sessionReset = resetText(session);
        weekReset = resetText(week);
        updatedAt = Date.now();
        finish("");
        cacheFile.setText(JSON.stringify({
            sessionAvailable: sessionAvailable,
            sessionRemaining: sessionRemaining,
            sessionReset: sessionReset,
            weekAvailable: weekAvailable,
            weekRemaining: weekRemaining,
            weekReset: weekReset,
            updatedAt: updatedAt
        }) + "\n");
    }

    onActiveChanged: if (active) refreshIfStale()
    onBackgroundChanged: if (background) refreshIfStale()
    Component.onCompleted: {
        try {
            const cached = JSON.parse(cacheFile.text());
            sessionAvailable = cached.sessionAvailable;
            sessionRemaining = cached.sessionRemaining;
            sessionReset = cached.sessionReset;
            weekAvailable = cached.weekAvailable;
            weekRemaining = cached.weekRemaining;
            weekReset = cached.weekReset;
            updatedAt = cached.updatedAt;
            installed = true;
        } catch (e) {}
        if (background)
            refreshIfStale();
    }

    readonly property FileView cacheFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/muthur/codex-usage.json"
        blockLoading: true
        printErrors: false
    }

    // Local token statistics (tokens by day / by model over the last 7
    // days), aggregated by scripts/ai-usage-stats.py from the CLI's own
    // session logs. Only refreshed while the tab is showing.
    property var statsDays: []
    property var statsModels: []
    property bool statsLoaded: false

    function refreshStats() {
        statsProcess.running = false;
        statsProcess.running = true;
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refreshStats()
    }

    Process {
        id: statsProcess
        command: [Quickshell.shellDir + "/scripts/ai-usage-stats.py", "codex"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.statsDays = (data.days || []).map(d => ({ label: d.label, value: d.tokens }));
                    root.statsModels = (data.models || []).map(m => ({ label: m.name, value: m.tokens }));
                } catch (e) {
                    root.statsDays = [];
                    root.statsModels = [];
                }
                root.statsLoaded = true;
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    Timer {
        interval: 600000
        repeat: true
        running: root.background && !root.active
        onTriggered: root.refresh()
    }

    Timer {
        id: requestTimeout
        interval: 20000
        onTriggered: root.finish("[ CODEX USAGE REQUEST TIMED OUT ]")
    }

    Process {
        id: whichProcess
        // labwc starts the shell without ~/.local/bin on PATH (only .bashrc adds it).
        command: ["sh", "-c", "export PATH=\"$HOME/.local/bin:$PATH\"; command -v codex"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.fetching)
                    return;
                root.installed = this.text.trim().length > 0;
                if (root.installed) {
                    usageProcess.command = [this.text.trim(), "app-server"];
                    usageProcess.running = true;
                } else {
                    root.finish("");
                }
            }
        }
    }

    Process {
        id: usageProcess
        stdinEnabled: true

        function send(message) {
            write(JSON.stringify(message) + "\n");
        }

        onStarted: send({ id: 1, method: "initialize", params: {
            clientInfo: { name: "muthur_shell", title: "MU/TH/UR Shell", version: "1.0" }
        } })

        stdout: SplitParser {
            onRead: line => {
                if (!root.fetching || !line.trim())
                    return;
                let message;
                try {
                    message = JSON.parse(line);
                } catch (e) {
                    root.finish("[ INVALID CODEX USAGE RESPONSE ]");
                    return;
                }
                if (!message || (message.id !== 1 && message.id !== 2))
                    return;
                if (message.error) {
                    const detail = String(message.error.message || "");
                    root.finish(/auth|login|log in|sign in|unauthorized|401/i.test(detail)
                        ? "[ SIGN IN WITH CODEX LOGIN ]"
                        : "[ COULDN'T READ CODEX USAGE ] " + detail);
                    return;
                }
                if (message.id === 1) {
                    usageProcess.send({ method: "initialized" });
                    usageProcess.send({ id: 2, method: "account/rateLimits/read" });
                } else if (message.id === 2) {
                    root.readLimits(message.result);
                }
            }
        }

        // Drain diagnostics separately: stdout is exclusively the JSON protocol.
        stderr: SplitParser { onRead: line => {} }
        onExited: exitCode => {
            if (root.fetching)
                root.finish("[ CODEX USAGE PROCESS EXITED: " + exitCode + " ]");
        }
    }

}
