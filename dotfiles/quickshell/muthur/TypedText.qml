import QtQuick

// Text that types itself out a character at a time, the way MU/TH/UR
// answers, after an optional delay; retypes whenever `fullText` changes.
// `suffix` (a cursor, live input) is shown as is after the typed part.
Text {
    id: root

    property string fullText: ""
    property string suffix: ""
    // Before the first character, in ms.
    property int delay: 0
    // Per character, in ms.
    property int interval: 22
    property int shown: 0
    readonly property bool done: shown >= fullText.length

    text: fullText.substring(0, shown) + suffix

    function retype() {
        shown = 0;
        typer.stop();
        starter.restart();
    }

    onFullTextChanged: retype()
    Component.onCompleted: retype()

    Timer {
        id: starter
        interval: Math.max(1, root.delay)
        onTriggered: typer.start()
    }

    Timer {
        id: typer
        interval: root.interval
        repeat: true
        onTriggered: {
            root.shown++;
            if (root.done)
                stop();
        }
    }
}
