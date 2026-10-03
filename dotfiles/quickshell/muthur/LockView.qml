import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.UPower

// One screen of the lock: the MU/TH/UR 6000 terminal on a CRT tube, over
// the Nostromo's wireframe descent. A big clock, a framed exchange where
// MU/TH/UR asks for an ident and answers, and a status line. Everything
// it shows comes from LockScreen, so every screen tells the same story;
// typing works on whichever one has the keyboard.
Item {
    id: root

    Theme { id: theme }

    // Sizes are designed for 1080p and scale with the screen.
    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property string phase: LockScreen.phase

    readonly property color answerColor: phase === "granted" ? theme.colorGreen
        : LockScreen.answerIsError ? theme.colorRed : theme.colorFg

    function sz(n) {
        return Math.max(1, Math.round(n * root.u));
    }

    // A line of the exchange with MU/TH/UR.
    component Line: TypedText {
        width: parent ? parent.width : 0
        elide: Text.ElideRight
        color: theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: root.sz(28)
        font.letterSpacing: root.sz(3)
    }

    component Status: Text {
        color: theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: root.sz(18)
        font.letterSpacing: root.sz(4)
    }

    // --- Data ---------------------------------------------------------

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
    }
    readonly property string host: (hostFile.text() || "UNKNOWN").trim().toUpperCase()

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: uptimeFile.reload()
    }
    readonly property string uptime: {
        const s = Math.floor(parseFloat(uptimeFile.text()) || 0);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        const pad = n => String(n).padStart(2, "0");
        return (d > 0 ? d + "D " : "") + pad(h) + "H " + pad(m) + "M";
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isPresent && battery.isLaptopBattery
    readonly property int charge: hasBattery ? Math.round(battery.percentage * 100) : 0

    // A line of drifting hex in the status bar: nothing, but alive.
    property string dataStream: ""
    Timer {
        interval: 160
        repeat: true
        running: !LockScreen.idle
        triggeredOnStart: true
        onTriggered: {
            const word = () => Math.floor(Math.random() * 65536).toString(16).toUpperCase().padStart(4, "0");
            root.dataStream = [word(), word(), word(), word(), word(), word()].join(" ");
        }
    }

    property bool cursorOn: true
    Timer {
        interval: 530
        repeat: true
        running: true
        onTriggered: root.cursorOn = !root.cursorOn
    }

    // The verifying bar sweeps while PAM thinks.
    property int sweep: 0
    Timer {
        interval: 90
        repeat: true
        running: root.phase === "verifying"
        onTriggered: root.sweep = (root.sweep + 1) % 12
    }

    // --- Input ----------------------------------------------------------

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                LockScreen.submit();
            else if (event.key === Qt.Key_Backspace)
                ctrl ? LockScreen.clear() : LockScreen.backspace();
            else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_U))
                LockScreen.clear();
            else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32)
                LockScreen.type(event.text);
            else
                LockScreen.poke();
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: LockScreen.idle ? Qt.BlankCursor : Qt.ArrowCursor
        onPositionChanged: LockScreen.poke()
        onPressed: {
            LockScreen.poke();
            keys.forceActiveFocus();
        }
    }

    // --- Picture --------------------------------------------------------

    CrtScreen {
        id: crt
        anchors.fill: parent

        VectorTerrain {
            y: parent.height * 0.6
            width: parent.width
            height: parent.height * 0.4
            opacity: LockScreen.idle ? 0.12 : 0.3
            speed: LockScreen.idle ? 0.2 : 0.6
            Behavior on opacity { NumberAnimation { duration: 1500 } }
        }

        // Everything with text, drawn only through the glow below.
        Item {
            id: screenText
            width: parent.width
            height: parent.height

            // Burn-in care: the idle picture wanders a few pixels a minute.
            property real driftX: 0
            property real driftY: 0
            Timer {
                interval: 60000
                repeat: true
                running: LockScreen.idle
                onTriggered: {
                    screenText.driftX = (Math.random() - 0.5) * root.sz(40);
                    screenText.driftY = (Math.random() - 0.5) * root.sz(40);
                }
            }

            Item {
                id: frame
                x: screenText.driftX
                y: screenText.driftY
                width: parent.width
                height: parent.height

                readonly property real margin: root.sz(80)
                // Everything but the clock dims when idle.
                property real chrome: LockScreen.idle ? 0.12 : 1
                Behavior on chrome { NumberAnimation { duration: 1500 } }

                // Header.
                Column {
                    x: frame.margin
                    y: frame.margin
                    opacity: frame.chrome
                    spacing: root.sz(6)

                    Text {
                        text: "MU/TH/UR 6000"
                        color: theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: root.sz(36)
                        font.bold: true
                        font.letterSpacing: root.sz(8)
                    }
                    Text {
                        text: "INTERFACE 2037  ·  MAINFRAME ACCESS"
                        color: theme.colorFg
                        opacity: 0.55
                        font.family: theme.fontFamily
                        font.pixelSize: root.sz(18)
                        font.letterSpacing: root.sz(4)
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: frame.margin
                    y: frame.margin
                    opacity: frame.chrome
                    spacing: root.sz(6)

                    Text {
                        anchors.right: parent.right
                        text: "WEYLAND-YUTANI CORP"
                        color: theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: root.sz(18)
                        font.letterSpacing: root.sz(4)
                    }
                    Text {
                        anchors.right: parent.right
                        text: "VESSEL " + root.host + "  ·  CREW " + LockScreen.user
                        color: theme.colorFg
                        opacity: 0.55
                        font.family: theme.fontFamily
                        font.pixelSize: root.sz(18)
                        font.letterSpacing: root.sz(4)
                    }
                }

                // Rule under the header, with a bright lead-in.
                Rectangle {
                    x: frame.margin
                    y: frame.margin + root.sz(84)
                    width: parent.width - frame.margin * 2
                    height: 1
                    color: theme.colorDim
                    opacity: frame.chrome

                    Rectangle {
                        width: root.sz(160)
                        height: Math.max(2, root.sz(3))
                        anchors.verticalCenter: parent.verticalCenter
                        color: theme.colorFg
                    }
                }

                // Clock.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.2
                    spacing: root.sz(4)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: Qt.formatDateTime(root.now, "HH")
                            color: theme.colorFg
                            font.family: theme.fontFamily
                            font.pixelSize: root.sz(210)
                            font.letterSpacing: root.sz(12)
                        }
                        Text {
                            text: ":"
                            opacity: root.now.getSeconds() % 2 === 0 ? 1 : 0.25
                            color: theme.colorFg
                            font.family: theme.fontFamily
                            font.pixelSize: root.sz(210)
                        }
                        Text {
                            text: Qt.formatDateTime(root.now, "mm")
                            color: theme.colorFg
                            font.family: theme.fontFamily
                            font.pixelSize: root.sz(210)
                            font.letterSpacing: root.sz(12)
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, "dddd dd MMMM yyyy").toUpperCase()
                        color: theme.colorFg
                        opacity: 0.8
                        font.family: theme.fontFamily
                        font.pixelSize: root.sz(28)
                        font.letterSpacing: root.sz(10)
                    }
                }

                // The exchange with MU/TH/UR, framed, over the terrain.
                Rectangle {
                    id: console_
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.56
                    width: Math.min(parent.width - frame.margin * 2, root.sz(1180))
                    height: lines.height + root.sz(64)
                    color: Qt.alpha(theme.colorBg, 0.88)
                    border.color: root.phase === "denied" ? theme.colorRed
                        : root.phase === "granted" ? theme.colorGreen : theme.colorFg
                    border.width: Math.max(1, root.sz(2))
                    opacity: frame.chrome

                    // Tab on the top edge.
                    Rectangle {
                        x: root.sz(32)
                        anchors.verticalCenter: parent.top
                        width: tabText.width + root.sz(24)
                        height: tabText.height + root.sz(8)
                        color: theme.colorBg

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: "[ PRIORITY ONE ]"
                            color: console_.border.color
                            font.family: theme.fontFamily
                            font.pixelSize: root.sz(18)
                            font.letterSpacing: root.sz(4)
                        }
                    }

                    Column {
                        id: lines
                        x: root.sz(40)
                        y: root.sz(36)
                        width: parent.width - root.sz(80)
                        spacing: root.sz(14)

                        Line {
                            fullText: "> SESSION LOCKED. CREW MEMBER " + LockScreen.user + "."
                            delay: 700
                        }
                        Line {
                            fullText: "> INTERFACE 2037 READY FOR INQUIRY."
                            delay: 1500
                        }
                        Line {
                            fullText: "> IDENTIFY: "
                            delay: 2300
                            color: theme.colorFocus
                            // The typed password as stars, then the cursor.
                            suffix: done ? "*".repeat(Math.min(LockScreen.password.length, 40))
                                + (root.phase === "verifying" || root.phase === "granted" ? ""
                                   : root.cursorOn ? "█" : " ") : ""
                        }
                        Line {
                            visible: root.phase === "verifying"
                            fullText: "> VERIFYING IDENT "
                            suffix: done ? "[" + Array.from({ length: 12 }, (_, i) =>
                                Math.abs(i - root.sweep) < 3 ? "█" : "░").join("") + "]" : ""
                        }
                        Line {
                            visible: LockScreen.answer.length > 0 && root.phase !== "verifying"
                            fullText: LockScreen.answer ? "> " + LockScreen.answer : ""
                            interval: 12
                            color: root.answerColor
                        }
                    }
                }

                // Status line.
                Item {
                    x: frame.margin
                    y: parent.height - frame.margin - height
                    width: parent.width - frame.margin * 2
                    height: statusLeft.height
                    opacity: frame.chrome

                    Status {
                        id: statusLeft
                        text: root.hasBattery
                            ? "POW " + String(root.charge).padStart(3, "0") + "%  ["
                              + Array.from({ length: 10 }, (_, i) => i < Math.round(root.charge / 10) ? "█" : "░").join("") + "]"
                            : "POW  AUX SUPPLY"
                        color: root.hasBattery ? theme.levelColor(root.charge) : theme.colorFg
                    }
                    Status {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dataStream
                        color: theme.colorDim
                    }
                    Status {
                        anchors.right: parent.right
                        text: "UPTIME " + root.uptime
                    }
                }
            }
        }

        // Phosphor glow: the text bleeds a little light around itself.
        // hideSource rather than `visible: false` on screenText: a hidden
        // tree emits no visibility changes, so the exchange's Column would
        // never make room for a line that appears.
        ShaderEffectSource {
            id: textTexture
            anchors.fill: screenText
            sourceItem: screenText
            hideSource: true
            visible: false
        }

        MultiEffect {
            source: textTexture
            anchors.fill: screenText
            shadowEnabled: true
            shadowColor: theme.colorFg
            shadowBlur: 0.9
            blurMax: 32
            shadowOpacity: 0.7
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        // Tearing across the picture when an ident is refused.
        Repeater {
            id: tears
            model: 7

            Rectangle {
                required property int index
                property real seed: Math.random()
                visible: glitch.running
                x: (seed - 0.5) * root.sz(120)
                y: crt.height * ((index + seed) / 7)
                width: crt.width
                height: root.sz(3 + seed * 18)
                color: Qt.alpha(index % 2 ? theme.colorRed : theme.colorFg, 0.18 + seed * 0.2)
            }
        }

        SequentialAnimation {
            id: glitch
            ScriptAction {
                script: {
                    for (let i = 0; i < tears.count; i++)
                        tears.itemAt(i).seed = Math.random();
                }
            }
            PauseAnimation { duration: 90 }
            ScriptAction {
                script: {
                    for (let i = 0; i < tears.count; i++)
                        tears.itemAt(i).seed = Math.random();
                }
            }
            PauseAnimation { duration: 110 }
        }
    }

    Connections {
        target: LockScreen

        function onPhaseChanged() {
            if (root.phase === "denied") {
                crt.shake();
                glitch.restart();
            } else if (root.phase === "granted") {
                powerOffDelay.restart();
            }
        }
    }

    // Let "ACCESS GRANTED" be read before the tube goes dark.
    Timer {
        id: powerOffDelay
        interval: 1000
        onTriggered: crt.powerOff()
    }

    Component.onCompleted: {
        crt.powerOn();
        keys.forceActiveFocus();
    }
}
