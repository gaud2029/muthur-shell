pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light (GitHub issue #28): warms the screens through wlsunset
// (wlr-gamma-control), which the shell runs and restarts with new
// arguments whenever a setting changes — it has no runtime control.
// Set in [SYS] > DISPLAY, toggled from the drawer or with
//   quickshell ipc -c muthur call nightlight toggle
Singleton {
    id: root

    readonly property IniSettings store: IniSettings {
        location: "file://" + Quickshell.shellDir + "/nightlight.ini"
        category: "nightlight"

        property bool enabled: false
        // "always" (warm all the time), "schedule" (fixed hours) or "sun"
        // (sunset/sunrise at a location).
        property string mode: "schedule"
        // The warm temperature, in kelvin; days stay at 6500 K.
        property int temperature: 4000
        property string sunset: "20:00"
        property string sunrise: "07:00"
        property string latitude: ""
        property string longitude: ""
    }

    readonly property bool enabled: store.enabled
    readonly property string mode: ["always", "schedule", "sun"].includes(store.mode) ? store.mode : "schedule"
    readonly property int temperature: Math.max(minTemperature, Math.min(maxTemperature, store.temperature))
    readonly property int minTemperature: 1900
    readonly property int maxTemperature: 6000
    readonly property int dayTemperature: 6500

    readonly property bool locationSet: validCoordinate(store.latitude, 90) && validCoordinate(store.longitude, 180)
    // Running with what it has: SUN mode needs a location first.
    readonly property bool ready: mode !== "sun" || locationSet

    function validTime(t) {
        return /^([01]\d|2[0-3]):[0-5]\d$/.test(t);
    }

    function validCoordinate(s, limit) {
        const v = Number(s);
        return s !== "" && !isNaN(v) && Math.abs(v) <= limit;
    }

    function toggle() {
        store.enabled = !enabled;
    }

    function setMode(m) {
        store.mode = m;
    }

    function setTemperature(k) {
        store.temperature = Math.round(k / 100) * 100;
    }

    function setTimes(sunset, sunrise) {
        if (validTime(sunset))
            store.sunset = sunset;
        if (validTime(sunrise))
            store.sunrise = sunrise;
    }

    function setLocation(lat, lon) {
        store.latitude = lat.trim();
        store.longitude = lon.trim();
    }

    // setpriv: the kernel stops wlsunset if the shell goes away (a crash, a
    // restart), so a stale one can't keep the screen warm or fight the
    // next one over the gamma.
    readonly property var command: {
        const args = ["setpriv", "--pdeathsig", "TERM", "wlsunset", "-t", String(temperature)];
        if (mode === "always")
            // Night and day at the same warmth: warm whatever the time.
            return args.concat(["-T", String(temperature + 1), "-S", "06:00", "-s", "18:00"]);
        args.push("-T", String(dayTemperature));
        if (mode === "sun")
            return args.concat(["-l", store.latitude, "-L", store.longitude]);
        return args.concat(["-S", store.sunrise, "-s", store.sunset, "-d", "1800"]);
    }

    // wlsunset puts the gamma back when it's stopped. A change stops it
    // and starts it again a moment later (also debouncing slider drags).
    Process {
        id: proc
        command: root.command
        stderr: StdioCollector { id: errors }
        // It chats on stderr ("adding output"); only a failure is worth a
        // warning, not being stopped for a restart or the off switch.
        onExited: code => {
            if (code !== 0 && !restartTimer.running)
                console.warn("wlsunset exited with", code + ":", errors.text.trim());
        }
    }

    function restart() {
        proc.running = false;
        restartTimer.restart();
    }

    onCommandChanged: restart()
    onEnabledChanged: restart()
    onReadyChanged: restart()

    Timer {
        id: restartTimer
        interval: 300
        onTriggered: proc.running = root.enabled && root.ready
    }

    Component.onCompleted: restartTimer.restart()

    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function isEnabled(): bool {
            return root.enabled;
        }
    }
}
