pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code quota, read from `claude -p /usage`. Refreshed every minute
// while its tab is showing, and every 10 minutes in the background when
// Claude is the default agent (the [AI] button shows its session bar).
// The last good read is cached on disk and kept when a fetch fails, so
// the panel always has numbers to show, with their age.
Singleton {
    id: root

    property bool active: false
    readonly property bool background: ThemeStore.defaultAgent === "claude"

    property real sessionRemaining: 0
    property string sessionReset: ""
    property real weekRemaining: 0
    property string weekReset: ""
    // When the numbers above were read (ms since epoch); 0 before the first read.
    property real updatedAt: 0
    property bool fetching: false
    // Why the last fetch failed, cleared by the next good one.
    property string error: ""
    readonly property bool hasData: updatedAt > 0
    // Shown instead of the bars only while there's no data at all.
    readonly property string fallbackMessage: hasData ? "" : error
    readonly property bool loaded: hasData || error.length > 0
    readonly property bool ready: hasData

    // A fetch takes a few seconds; never restart one that's running, or
    // it ends with empty output and reads as a failure.
    function refresh() {
        if (usageProcess.running)
            return;
        fetching = true;
        requestTimeout.restart();
        usageProcess.running = true;
    }

    // Reopening the panel right after a read shouldn't spawn another one.
    function refreshIfStale() {
        if (Date.now() - updatedAt > 30000)
            refresh();
    }

    function finish(message) {
        error = message;
        fetching = false;
        requestTimeout.stop();
    }

    onActiveChanged: if (active) refreshIfStale()
    onBackgroundChanged: if (background) refreshIfStale()
    Component.onCompleted: {
        try {
            const cached = JSON.parse(cacheFile.text());
            sessionRemaining = cached.sessionRemaining;
            sessionReset = cached.sessionReset;
            weekRemaining = cached.weekRemaining;
            weekReset = cached.weekReset;
            updatedAt = cached.updatedAt;
        } catch (e) {}
        if (background)
            refreshIfStale();
    }

    readonly property FileView cacheFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/muthur/claude-usage.json"
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
        command: [Quickshell.shellDir + "/scripts/ai-usage-stats.py", "claude"]
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
        interval: 30000
        onTriggered: {
            root.finish("[ USAGE REQUEST TIMED OUT ]");
            usageProcess.running = false;
        }
    }

    Process {
        id: usageProcess
        // labwc starts the shell without ~/.local/bin on PATH (only .bashrc adds it).
        command: ["sh", "-c", "export PATH=\"$HOME/.local/bin:$PATH\"; exec claude -p /usage"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.fetching)
                    return;
                const text = this.text;
                const sessionMatch = text.match(/Current session:\s*(\d+)%\s*used\s*·\s*resets\s*(.+)/);
                const weekMatch = text.match(/Current week[^:]*:\s*(\d+)%\s*used\s*·\s*resets\s*(.+)/);

                if (!sessionMatch || !weekMatch) {
                    root.finish(text.split("\n").find(l => l.trim().length > 0) || "[ COULDN'T READ USAGE ]");
                    return;
                }
                root.sessionRemaining = 100 - parseInt(sessionMatch[1]);
                root.sessionReset = "resets " + sessionMatch[2].trim();
                root.weekRemaining = 100 - parseInt(weekMatch[1]);
                root.weekReset = "resets " + weekMatch[2].trim();
                root.updatedAt = Date.now();
                root.finish("");
                root.cacheFile.setText(JSON.stringify({
                    sessionRemaining: root.sessionRemaining,
                    sessionReset: root.sessionReset,
                    weekRemaining: root.weekRemaining,
                    weekReset: root.weekReset,
                    updatedAt: root.updatedAt
                }) + "\n");
            }
        }
    }
}
