//@ pragma UseQApplication
// Tray items' native menus (Drawer.qml) are platform menus, which need
// a QApplication.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
