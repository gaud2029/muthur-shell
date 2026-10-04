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

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
