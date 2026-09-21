import QtQuick
import Quickshell

ShellRoot {
    Niri {
        id: niriService
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            niri: niriService
        }
    }
}
