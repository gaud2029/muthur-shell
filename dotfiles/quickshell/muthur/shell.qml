//@ pragma UseQApplication
// Tray items' native menus (Drawer.qml) are platform menus, which need
// a QApplication.
import QtQuick
import Quickshell

ShellRoot {
    // Singletons load on first use; touch the ones with IPC targets now
    // ("quickshell ipc -c muthur call lock lock", "... call focus toggle")
    // so they exist from the start.
    Component.onCompleted: {
        LockScreen.locked;
        Focus.active;
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
