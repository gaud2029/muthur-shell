import QtQuick
import Quickshell.Services.Pipewire

// A Dropdown over the Pipewire devices `accepts` lets through.
Dropdown {
    id: root

    // Which Pipewire nodes belong in the list.
    property var accepts: node => false

    options: Pipewire.nodes.values.filter(n => root.accepts(n))
    labelFor: n => n ? (n.description || n.nickname || n.name) : "-"
}
