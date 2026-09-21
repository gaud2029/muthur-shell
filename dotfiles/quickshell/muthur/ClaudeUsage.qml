pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code quota, read from `claude -p /usage`. Refreshed every minute
// while its tab is showing, and every 10 minutes in the background when
// Claude is the default agent (the [AI] button shows its session bar).
Singleton {
    id: root

    property bool active: false
    readonly property bool background: ThemeStore.defaultAgent === "claude"

    property real sessionRemaining: 0
    property string sessionReset: ""
    property real weekRemaining: 0
    property string weekReset: ""
    property string fallbackMessage: ""
    property bool loaded: false
    readonly property bool ready: loaded && fallbackMessage.length === 0

    function refresh() {
        usageProcess.running = false;
        usageProcess.running = true;
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

    Process {
        id: usageProcess
        command: ["claude", "-p", "/usage"]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text;
                const sessionMatch = text.match(/Current session:\s*(\d+)%\s*used\s*·\s*resets\s*(.+)/);
                const weekMatch = text.match(/Current week[^:]*:\s*(\d+)%\s*used\s*·\s*resets\s*(.+)/);

                if (sessionMatch && weekMatch) {
                    root.sessionRemaining = 100 - parseInt(sessionMatch[1]);
                    root.sessionReset = "resets " + sessionMatch[2].trim();
                    root.weekRemaining = 100 - parseInt(weekMatch[1]);
                    root.weekReset = "resets " + weekMatch[2].trim();
                    root.fallbackMessage = "";
                } else {
                    root.fallbackMessage = text.split("\n").find(l => l.trim().length > 0) || "[ COULDN'T READ USAGE ]";
                }
                root.loaded = true;
            }
        }
    }
}
