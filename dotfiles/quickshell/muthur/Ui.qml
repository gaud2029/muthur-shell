pragma Singleton
import QtQuick
import Quickshell

// Opens and closes the bar's popups from outside a click (`muthur ui`,
// Cli.qml): each Bar listens and acts only for its own screen.
Singleton {
    id: root

    // drawer, sys:<tab>, ai:<tab>, calendar, battery, launcher
    readonly property var sysTabs: ({ network: "wifi", bt: "bluetooth", audio: "audio", display: "display", keyboard: "keyboard", look: "look" })
    readonly property var aiTabs: ["claude", "codex"]
    readonly property var targets: ["drawer", "calendar", "battery", "launcher"]
        .concat(Object.keys(sysTabs).map(t => "sys:" + t))
        .concat(aiTabs.map(t => "ai:" + t))

    // The screens that have a bar.
    readonly property var barScreens: ThemeStore.barOnMainOnly
        ? [ThemeStore.mainScreen]
        : Quickshell.screens.map(s => s.name)

    signal openRequested(string target, string screen)
    signal closeRequested()

    // An error message, or "" once asked.
    function open(target, screen) {
        if (!targets.includes(target))
            return "\"" + target + "\" is not one of " + targets.join(", ");
        const name = screen || ThemeStore.mainScreen;
        // Not a bar popup: its own window, on any screen.
        if (target === "launcher") {
            if (!Quickshell.screens.some(s => s.name === name))
                return "no screen \"" + name + "\"";
            Launcher.open(name);
            return "";
        }
        if (!barScreens.includes(name))
            return "no bar on \"" + name + "\" (bars: " + barScreens.join(", ") + ")";
        openRequested(target, name);
        return "";
    }

    function close() {
        Launcher.close();
        closeRequested();
    }
}
