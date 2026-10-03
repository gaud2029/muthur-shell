//@ pragma UseQApplication
// Tray items' native menus (Drawer.qml) are platform menus, which need
// a QApplication.
import QtQuick
import Quickshell

ShellRoot {
    // Singletons load on first use; touch the lock now so its IPC target
    // ("quickshell ipc -c muthur call lock lock") exists from the start.
    Component.onCompleted: LockScreen.locked

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
