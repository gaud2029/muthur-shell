//@ pragma UseQApplication
// Tray items' native menus (Drawer.qml) are platform menus, which need
// a QApplication.
import QtQuick
import Quickshell

ShellRoot {
    // Singletons load on first use; touch the ones with IPC targets now
    // ("quickshell ipc -c muthur call lock lock", "... call focus toggle",
    // "... call nightlight toggle", and Cli's "muthur" for the muthur
    // command) so they exist from the start — and NightLight starts
    // wlsunset. NotificationPopups and OsdWindow below
    // start the notification server and the "osd" target.
    Component.onCompleted: {
        LockScreen.locked;
        Focus.active;
        NightLight.enabled;
        Cli.entries;
    }

    // Notification popups, on the main screen only.
    NotificationPopups {
        screen: Quickshell.screens.find(s => s.name === ThemeStore.mainScreen) || Quickshell.screens[0]
    }

    // Volume/brightness/layout OSD, on the main screen too.
    OsdWindow {
        screen: Quickshell.screens.find(s => s.name === ThemeStore.mainScreen) || Quickshell.screens[0]
    }

    // Every screen, or only the main one (ThemeStore.mainScreen, set in
    // [SYS] > DISPLAY).
    Variants {
        model: ThemeStore.barOnMainOnly
            ? Quickshell.screens.filter(s => s.name === ThemeStore.mainScreen)
            : Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
