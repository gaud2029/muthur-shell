import QtQuick

// How fresh an AI quota read is: "UPDATED 30S AGO", with the fetch in
// progress or the last failure appended. Takes a ClaudeUsage/CodexUsage
// singleton; hidden until it has data.
Text {
    id: root

    property var usage: null

    // Bumped by the timer so the age is recomputed while showing.
    property real now: Date.now()

    function age(ms) {
        const s = Math.max(0, Math.floor((now - ms) / 1000));
        if (s < 10)
            return "JUST NOW";
        if (s < 60)
            return Math.floor(s / 5) * 5 + "S AGO";
        if (s < 3600)
            return Math.floor(s / 60) + "M AGO";
        if (s < 86400)
            return Math.floor(s / 3600) + "H AGO";
        return Math.floor(s / 86400) + "D AGO";
    }

    Theme { id: theme }

    visible: !!usage && usage.hasData
    text: !usage || !usage.hasData ? ""
        : usage.fetching ? "UPDATED " + age(usage.updatedAt) + " · UPDATING..."
        : usage.error.length > 0 ? "UPDATE FAILED · LAST " + age(usage.updatedAt)
        : "UPDATED " + age(usage.updatedAt)
    color: usage && usage.error.length > 0 && !usage.fetching ? theme.colorFocus : theme.colorDim
    font.family: theme.fontFamily
    font.pixelSize: theme.px(11)

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
}
