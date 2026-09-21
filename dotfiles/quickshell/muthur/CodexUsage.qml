pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Codex quota, read over the `codex app-server` JSON protocol. Same
// refresh policy as ClaudeUsage.
Singleton {
    id: root

    property bool active: false
    readonly property bool background: ThemeStore.defaultAgent === "codex"
    property bool fetching: false
    property bool installed: false
    property bool loaded: false
    property real sessionRemaining: 0
    property string sessionReset: ""
    property real weekRemaining: 0
    property string weekReset: ""
    property string fallbackMessage: ""
    property bool sessionAvailable: false
    property bool weekAvailable: false
    readonly property bool ready: loaded && installed && fallbackMessage.length === 0

    function refresh() {
        if (fetching || whichProcess.running || usageProcess.running)
            return;
        fetching = true;
        requestTimeout.restart();
        whichProcess.running = true;
    }

    function finish(message) {
        fallbackMessage = message;
        fetching = false;
        loaded = true;
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
        sessionAvailable = !!validWindow(session);
        weekAvailable = !!validWindow(week);
        sessionRemaining = sessionAvailable ? Math.max(0, Math.min(100, 100 - session.usedPercent)) : 0;
        weekRemaining = weekAvailable ? Math.max(0, Math.min(100, 100 - week.usedPercent)) : 0;
        sessionReset = resetText(session);
        weekReset = resetText(week);
        finish(sessionAvailable || weekAvailable ? "" : "[ CODEX QUOTAS UNAVAILABLE ]");
    }

    onActiveChanged: if (active) refresh()
    onBackgroundChanged: if (background && !loaded) refresh()
    Component.onCompleted: if (background) refresh()


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
        command: ["which", "codex"]
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
