import QtQuick
import Quickshell

// A first click arms the button (it fills and asks to confirm); a second
// one within a few seconds runs the command, otherwise it disarms — so a
// stray click can't suspend, power off or log out.
TerminalButton {
    id: root

    property string action: ""
    property var command: []
    property bool armed: false

    label: armed ? "CONFIRM " + action + "?" : action
    selected: armed
    onClicked: {
        if (armed) {
            armed = false;
            Quickshell.execDetached(command);
        } else {
            armed = true;
        }
    }

    Timer {
        running: root.armed
        interval: 4000
        onTriggered: root.armed = false
    }
}
