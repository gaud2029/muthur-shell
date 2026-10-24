pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System load for the [MON] button and panel (GitHub issue #48): CPU
// (total and per core, from /proc/stat deltas), memory and swap, load
// average, frequency, temperatures (the hottest sensor of each hwmon
// device), disks, and the busiest processes. procfs and sysfs emit no
// change events, so it polls: every 2 s while the panel is open, every
// 5 s for the button alone, not at all when neither shows. The disks and
// the processes only while the panel is open.
Singleton {
    id: root

    // Settings, in monitor.ini (Cli.qml: monitor.button).
    readonly property IniSettings store: IniSettings {
        location: "file://" + Quickshell.shellDir + "/monitor.ini"
        category: "monitor"

        property bool button: true
    }

    function setButton(on) {
        store.button = on;
    }

    // How many open panels want the full, fast poll (MonitorPanel).
    property int watchers: 0
    readonly property bool active: watchers > 0 || store.button
    readonly property int interval: watchers > 0 ? 2000 : 5000

    // --- CPU ---------------------------------------------------------

    property real cpu: 0
    // Per core, 0-100.
    property var cores: []
    property var load: [0, 0, 0]
    // Average current frequency, MHz (0 when cpufreq isn't there).
    property real frequency: 0
    property var previous: null

    function readStat(text) {
        const now = {};
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                continue;
            const f = line.trim().split(/\s+/);
            const v = f.slice(1).map(Number);
            // user nice system idle iowait irq softirq steal
            const idle = v[3] + (v[4] || 0);
            const total = v.slice(0, 8).reduce((a, b) => a + b, 0);
            now[f[0]] = { idle: idle, total: total };
        }
        if (root.previous) {
            const usage = key => {
                const a = root.previous[key], b = now[key];
                if (!a || !b || b.total <= a.total)
                    return 0;
                return 100 * (1 - (b.idle - a.idle) / (b.total - a.total));
            };
            root.cpu = usage("cpu");
            root.cores = Object.keys(now).filter(k => k !== "cpu")
                .sort((a, b) => Number(a.substring(3)) - Number(b.substring(3)))
                .map(usage);
        }
        root.previous = now;
    }

    // --- Memory ------------------------------------------------------

    // Bytes.
    property real memTotal: 0
    property real memUsed: 0
    property real memCache: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memPercent: memTotal > 0 ? 100 * memUsed / memTotal : 0
    readonly property real swapPercent: swapTotal > 0 ? 100 * swapUsed / swapTotal : 0

    function readMeminfo(text) {
        const kb = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kb[m[1]] = Number(m[2]) * 1024;
        }
        root.memTotal = kb.MemTotal || 0;
        root.memUsed = (kb.MemTotal || 0) - (kb.MemAvailable || 0);
        root.memCache = (kb.Cached || 0) + (kb.Buffers || 0) + (kb.SReclaimable || 0);
        root.swapTotal = kb.SwapTotal || 0;
        root.swapUsed = (kb.SwapTotal || 0) - (kb.SwapFree || 0);
    }

    // --- Temperatures --------------------------------------------------

    // [{ label, celsius }], CPU and GPU first.
    property var temperatures: []
    readonly property real hottest: temperatures.reduce((m, t) => Math.max(m, t.celsius), 0)

    readonly property var sensorNames: ({
        k10temp: "CPU", coretemp: "CPU", zenpower: "CPU", amdgpu: "GPU", radeon: "GPU", nouveau: "GPU",
        nvme: "NVME", acpitz: "ACPI", thinkpad: "THINKPAD", iwlwifi_1: "WIFI"
    })

    function sensorLabel(name) {
        if (name.startsWith("mt79") || name.startsWith("iwlwifi") || name.startsWith("ath"))
            return "WIFI";
        return root.sensorNames[name] || name.toUpperCase();
    }

    // "name value" lines from the sensors script; one row per device, its
    // hottest reading (a 0 is a sensor that isn't wired).
    function readSensors(text) {
        const temps = {};
        const freqs = [];
        for (const line of text.split("\n")) {
            const [kind, name, value] = line.trim().split(/\s+/);
            const v = Number(value);
            if (kind === "temp" && v > 0) {
                const label = sensorLabel(name);
                temps[label] = Math.max(temps[label] || 0, v / 1000);
            } else if (kind === "freq" && v > 0) {
                freqs.push(v / 1000);
            }
        }
        const order = ["CPU", "GPU"];
        root.temperatures = Object.keys(temps)
            .sort((a, b) => (order.indexOf(a) + 1 || 9) - (order.indexOf(b) + 1 || 9) || a.localeCompare(b))
            .map(k => ({ label: k, celsius: temps[k] }));
        root.frequency = freqs.length ? freqs.reduce((a, b) => a + b, 0) / freqs.length : 0;
    }

    // --- Disks and processes (panel only) ------------------------------

    // [{ mount, size, used, percent }], one per device (btrfs subvolumes
    // share theirs: the shortest mount point stands for them).
    property var disks: []
    // [{ name, value }]: % of one core, and resident memory in bytes.
    property var topCpu: []
    property var topMem: []

    function readDisks(text) {
        const seen = {};
        const list = [];
        for (const line of text.trim().split("\n").slice(1)) {
            const [source, mount, size, used] = line.trim().split(/\s+/);
            if (!source || seen[source] || Number(size) === 0)
                continue;
            seen[source] = true;
            list.push({ mount: mount, size: Number(size), used: Number(used), percent: 100 * Number(used) / Number(size) });
        }
        root.disks = list;
    }

    // top's second sample: its first is the average since each process
    // started, as ps shows.
    function readTop(text) {
        const blocks = text.split(/\n(?=top - )/);
        const lines = blocks[blocks.length - 1].split("\n");
        const header = lines.findIndex(l => /^\s*PID\s/.test(l));
        if (header < 0)
            return;
        root.topCpu = lines.slice(header + 1)
            .map(l => l.trim().split(/\s+/))
            .filter(f => f.length >= 12)
            .map(f => ({ name: f.slice(11).join(" "), value: Number(f[8].replace(",", ".")) }))
            .filter(p => p.value > 0)
            .slice(0, 5);
    }

    function readPsMem(text) {
        root.topMem = text.trim().split("\n").map(l => {
            const f = l.trim().split(/\s+/);
            return { name: f.slice(0, -1).join(" "), value: Number(f[f.length - 1]) * 1024 };
        }).filter(p => p.name).slice(0, 5);
    }

    // --- Formatting --------------------------------------------------

    function bytes(n) {
        const units = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return (i >= 3 ? n.toFixed(1) : Math.round(n)) + units[i];
    }

    // --- Polling -----------------------------------------------------

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: loadavg; path: "/proc/loadavg"; blockLoading: true }

    function poll() {
        stat.reload();
        root.readStat(stat.text());
        meminfo.reload();
        root.readMeminfo(meminfo.text());
        loadavg.reload();
        root.load = loadavg.text().trim().split(/\s+/).slice(0, 3).map(Number);
        if (!sensors.running)
            sensors.running = true;
        if (root.watchers > 0) {
            if (!top.running)
                top.running = true;
            if (!psMem.running)
                psMem.running = true;
        }
    }

    Process {
        id: sensors
        command: ["sh", "-c",
            "for f in /sys/class/hwmon/hwmon*/temp*_input; do d=${f%/*}; "
            + "v=$(cat \"$f\" 2>/dev/null) && echo \"temp $(cat \"$d/name\") $v\"; done; "
            + "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do "
            + "echo \"freq cpu $(cat \"$f\" 2>/dev/null)\"; done"]
        stdout: StdioCollector { onStreamFinished: root.readSensors(text) }
    }

    Process {
        id: top
        command: ["top", "-b", "-n", "2", "-d", "1", "-w", "200", "-o", "%CPU"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector { onStreamFinished: root.readTop(text) }
    }

    Process {
        id: psMem
        command: ["ps", "-eo", "comm=,rss=", "--sort=-rss"]
        stdout: StdioCollector { onStreamFinished: root.readPsMem(text) }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=source,target,size,used", "-x", "tmpfs", "-x", "devtmpfs",
            "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "ramfs"]
        stdout: StdioCollector { onStreamFinished: root.readDisks(text) }
    }

    Timer {
        running: root.active
        repeat: true
        triggeredOnStart: true
        interval: root.interval
        onTriggered: root.poll()
    }

    // Disks change slowly.
    Timer {
        running: root.watchers > 0
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: if (!df.running) df.running = true
    }
}
