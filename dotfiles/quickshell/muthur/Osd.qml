pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// On-screen display (GitHub issue #26) for the volume, mic mute and
// brightness keys, which labwc binds to this IPC target (rc.xml):
//   quickshell ipc -c muthur call osd volumeUp | volumeDown | mute
//                                     micMute | brightnessUp | brightnessDown
// Each changes the value itself — PipeWire's default sink/source, the
// backlight through logind (no brightnessctl) — then shows it for a
// moment (OsdWindow.qml). Keyboard layout switches show up too.
Singleton {
    id: root

    // "volume" | "mic" | "brightness" | "layout"
    property string kind: ""
    // 0..1, for the bar.
    property real level: 0
    property bool muted: false
    // The layout switch's from/to codes.
    property string text: ""
    property bool shown: false

    readonly property real step: 0.05
    readonly property int duration: 1200

    function show(k, lvl, m, t) {
        kind = k;
        level = Math.max(0, Math.min(1, lvl));
        muted = m;
        text = t || "";
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: root.duration
        onTriggered: root.shown = false
    }

    // --- Audio -------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Live volume/mute data only flows for tracked nodes.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => !!o)
    }

    // Changing the volume unmutes, like most desktops.
    function volumeStep(delta) {
        if (!sink || !sink.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, Math.round((sink.audio.volume + delta) * 100) / 100));
        show("volume", sink.audio.volume, false);
    }

    function toggleMute() {
        if (!sink || !sink.audio)
            return;
        sink.audio.muted = !sink.audio.muted;
        show("volume", sink.audio.volume, sink.audio.muted);
    }

    function toggleMicMute() {
        if (!source || !source.audio)
            return;
        source.audio.muted = !source.audio.muted;
        show("mic", source.audio.volume, source.audio.muted);
    }

    // --- Brightness --------------------------------------------------

    // The first kernel backlight device (DisplayTab lists them all).
    property string backlight: ""
    property int maxBrightness: 0

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d\" ] && echo \"$(basename \"$d\") $(cat \"$d/max_brightness\")\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, max] = this.text.trim().split(" ");
                root.backlight = name || "";
                root.maxBrightness = parseInt(max) || 0;
            }
        }
    }

    // `brightness` is the requested level (amdgpu's actual_brightness is
    // a non-linear readback); sysfs raises no change events, so it's read
    // fresh on each key press.
    FileView {
        id: brightnessFile
        path: root.backlight ? "/sys/class/backlight/" + root.backlight + "/brightness" : ""
        blockLoading: true
    }

    // Never fully off: a black screen is a trap.
    function brightnessStep(delta) {
        if (!backlight || maxBrightness <= 0)
            return;
        brightnessFile.reload();
        const current = (parseInt(brightnessFile.text()) || 0) / maxBrightness;
        const next = Math.max(0.01, Math.min(1, Math.round((current + delta) * 100) / 100));
        Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
            "SetBrightness", "ssu", "backlight", backlight, String(Math.round(next * maxBrightness))]);
        show("brightness", next, false);
    }

    // --- Keyboard layout ---------------------------------------------

    property string lastLayout: Keyboard.current

    Connections {
        target: Keyboard
        function onCurrentChanged() {
            if (Keyboard.current !== root.lastLayout)
                root.show("layout", 0, false, Keyboard.shortLabel(root.lastLayout) + " > " + Keyboard.shortLabel(Keyboard.current));
            root.lastLayout = Keyboard.current;
        }
    }

    IpcHandler {
        target: "osd"

        function volumeUp(): void {
            root.volumeStep(root.step);
        }

        function volumeDown(): void {
            root.volumeStep(-root.step);
        }

        function mute(): void {
            root.toggleMute();
        }

        function micMute(): void {
            root.toggleMicMute();
        }

        function brightnessUp(): void {
            root.brightnessStep(root.step);
        }

        function brightnessDown(): void {
            root.brightnessStep(-root.step);
        }
    }
}
