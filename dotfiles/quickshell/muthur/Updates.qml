pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pending package updates, for the [UPD] button and panel. checkupdates
// (pacman-contrib) syncs a temporary copy of the databases, so checking
// needs no root and never leaves the real ones half-synced. Checked a
// minute after startup, every hour, after a resume, and on demand:
//   quickshell ipc -c muthur call updates check
// Nothing is installed until upgrade() opens `sudo pacman -Syu` in a
// terminal.
Singleton {
    id: root

    // [{ name, from, to, important }], important ones first.
    property var packages: []
    readonly property int importantCount: packages.filter(p => p.important).length
    // The running kernel's modules are gone: a new kernel was installed.
    property bool rebootRequired: false

    // Same shape as ClaudeUsage/CodexUsage, for UsageAge.
    property bool hasData: false
    property bool fetching: false
    property string error: ""
    property real updatedAt: 0

    readonly property int interval: 60 * 60 * 1000

    // Packages whose update usually means a reboot or a new session.
    readonly property var importantNames: ["systemd", "glibc", "mesa", "labwc", "quickshell", "limine", "plymouth", "sddm", "pipewire", "qt6-base", "qt6-declarative"]

    // Kernels (linux, linux-cachyos, linux-zen...), not their firmware
    // and headers.
    function isImportant(name) {
        const kernel = /^linux(-[a-z0-9]+)*$/.test(name) && !/-(firmware|headers|docs)\b/.test(name)
            && !name.startsWith("linux-firmware") && name !== "linux-api-headers";
        return kernel || name.startsWith("nvidia") || importantNames.includes(name);
    }

    function check() {
        if (checker.running)
            return;
        root.fetching = true;
        checker.running = true;
        kernel.running = true;
    }

    // A terminal of its own, detached so a shell reload can't kill pacman
    // halfway; when it's done it asks the shell to check again.
    function upgrade() {
        Quickshell.execDetached(["alacritty", "--title", "MU/TH/UR // SYSTEM UPDATE", "-e", "bash", "-c",
            "sudo pacman -Syu; status=$?; quickshell ipc -c muthur call updates check >/dev/null 2>&1; "
            + "echo; read -rp \"[ EXIT $status — ENTER CLOSES ]\""]);
    }

    Process {
        id: checker
        command: ["checkupdates"]
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }

        // 0: updates listed, 2: none, anything else: failed (offline...),
        // keeping the last list.
        onExited: code => {
            root.fetching = false;
            if (code !== 0 && code !== 2) {
                root.error = err.text.trim() || "checkupdates exited " + code;
                retry.restart();
                return;
            }
            const list = code === 2 ? [] : out.text.trim().split("\n").map(line => {
                const [name, from, , to] = line.trim().split(/\s+/);
                return { name: name, from: from, to: to, important: root.isImportant(name) };
            }).filter(p => p.name && p.to);
            root.packages = list.filter(p => p.important).concat(list.filter(p => !p.important));
            root.error = "";
            root.hasData = true;
            root.updatedAt = Date.now();
        }
    }

    Process {
        id: kernel
        command: ["sh", "-c", "test -d \"/usr/lib/modules/$(uname -r)\""]
        onExited: code => root.rebootRequired = code !== 0
    }

    Timer {
        running: true
        interval: 60 * 1000
        onTriggered: root.check()
    }

    // After a failure (offline at login...), sooner than the next hour.
    Timer {
        id: retry
        interval: 5 * 60 * 1000
        onTriggered: root.check()
    }

    Timer {
        running: true
        repeat: true
        interval: root.interval
        onTriggered: root.check()
    }

    // A resume shows as the wall clock jumping ahead of this timer.
    Timer {
        property real last: Date.now()

        running: true
        repeat: true
        interval: 30 * 1000
        onTriggered: {
            const now = Date.now();
            if (now - last > interval * 4)
                root.check();
            last = now;
        }
    }

    IpcHandler {
        target: "updates"

        function check(): void {
            root.check();
        }

        function upgrade(): void {
            root.upgrade();
        }

        // name old -> new, one per line, as checkupdates prints them.
        function list(): string {
            return root.packages.map(p => p.name + " " + p.from + " -> " + p.to).join("\n");
        }

        function count(): int {
            return root.packages.length;
        }
    }
}
