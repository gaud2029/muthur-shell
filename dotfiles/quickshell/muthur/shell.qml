import QtQuick
import Quickshell

ShellRoot {
    Niri {
        id: niriService
    }

    // Loaded only under Hyprland so the Quickshell.Hyprland plugin (which
    // warns when it finds no Hyprland socket) stays out of the way elsewhere.
    Loader {
        id: hyprlandService
        active: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        source: "HyprlandWorkspaces.qml"
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            niri: niriService
            hyprland: hyprlandService.item
        }
    }
}
