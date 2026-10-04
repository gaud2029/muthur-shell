import QtQuick
import QtQuick.Effects

// MU/TH/UR 6000 as the SDDM greeter (GitHub issue #24): the shell's lock
// screen, asking a crew member to identify before the session starts.
// The tube powers on over the wireframe descent, MU/TH/UR names the
// vessel and the crew member, and takes the ident; a refused one tears
// and shakes the picture, an accepted one powers the tube off.
//
// Keys: type the password, Enter to log in, Up/Down for another crew
// member, F1 for another session, F10/F11/F12 to suspend, restart, power
// off (pressed twice: the first only arms). The status line's items do
// the same on click.
Item {
    id: root

    Theme { id: theme }

    readonly property real u: Math.min(width / 1920, height / 1080)

    function sz(n) {
        return Math.max(1, Math.round(n * root.u));
    }

    // "boot" while the greeting types, then "input"; "verifying" while
    // SDDM decides; "denied" (back to "input" after a moment) or
    // "granted" (the tube powers off as the session starts).
    property string phase: "boot"
    property string password: ""
    property string answer: ""
    property bool answerIsError: false
    readonly property bool editable: phase === "boot" || phase === "input" || phase === "denied"

    readonly property var deniedAnswers: [
        "ACCESS DENIED. IDENT NOT RECOGNIZED.",
        "UNABLE TO CLARIFY. IDENT REJECTED.",
        "ACCESS DENIED. CREW MEMBER NOT CONFIRMED."
    ]
    property int failures: 0

    // Empty in --test-mode.
    readonly property string host: (sddm.hostName || "NOSTROMO").toUpperCase()

    // --- Crew and sessions ---------------------------------------------
    //
    // The models only expose their rows through delegates, so two
    // transparent lists keep a current row whose roles the rest reads.
    // (Not visible: false — a hidden, zero-size ListView never creates
    // its current item.)

    ListView {
        id: users
        width: 1
        height: 1
        opacity: 0
        model: userModel
        currentIndex: Math.max(0, userModel.lastIndex)
        delegate: Item {
            required property string name
            required property string realName
            readonly property string userName: name
        }
    }
    readonly property string userName: users.currentItem ? users.currentItem.userName : ""
    readonly property string crew: userName.toUpperCase()

    ListView {
        id: sessions
        width: 1
        height: 1
        opacity: 0
        model: sessionModel
        currentIndex: Math.max(0, sessionModel.lastIndex)
        delegate: Item {
            required property string name
            readonly property string sessionName: name
        }
    }
    readonly property string session: sessions.currentItem ? sessions.currentItem.sessionName.toUpperCase() : "-"

    function cycle(list, step) {
        if (list.count > 1)
            list.currentIndex = (list.currentIndex + step + list.count) % list.count;
    }

    // --- Actions ------------------------------------------------------

    function say(text, isError) {
        root.answer = text;
        root.answerIsError = isError;
    }

    function submit() {
        if (!root.editable)
            return;
        if (root.password.length === 0) {
            root.say("UNABLE TO CLARIFY. ENTER IDENT TO PROCEED.", true);
            return;
        }
        root.phase = "verifying";
        root.say("", false);
        sddm.login(root.userName, root.password, sessions.currentIndex);
    }

    // Power actions arm on a first press and run on a second within four
    // seconds, like the shell's drawer.
    property string armed: ""
    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    function power(action) {
        if (root.armed !== action) {
            root.armed = action;
            disarm.restart();
            root.say(action + " REQUESTED. CONFIRM TO PROCEED.", false);
            return;
        }
        root.armed = "";
        root.say(action + " CONFIRMED.", false);
        if (action === "SUSPEND")
            sddm.suspend();
        else if (action === "RESTART")
            sddm.reboot();
        else
            sddm.powerOff();
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.phase = "granted";
            root.say("ACCESS GRANTED. WELCOME ABOARD, " + root.crew + ".", false);
            powerOffDelay.restart();
        }

        function onLoginFailed() {
            root.failures++;
            root.password = "";
            root.phase = "denied";
            root.say(root.deniedAnswers[root.failures % root.deniedAnswers.length], true);
            crt.shake();
            glitch.restart();
            deniedTimer.restart();
        }
    }

    Timer {
        id: bootTimer
        interval: 2600
        running: true
        onTriggered: if (root.phase === "boot") root.phase = "input"
    }

    // SDDM always answers a real login; this only matters if it doesn't
    // (test mode never does), so the prompt can't stay stuck.
    Timer {
        interval: 15000
        running: root.phase === "verifying"
        onTriggered: {
            root.password = "";
            root.phase = "input";
            root.say("NO RESPONSE FROM AUTHENTICATION. TRY AGAIN.", true);
        }
    }

    Timer {
        id: deniedTimer
        interval: 2200
        onTriggered: if (root.phase === "denied") root.phase = "input"
    }

    Timer {
        id: powerOffDelay
        interval: 1000
        onTriggered: crt.powerOff()
    }

    // --- Clock, cursor, data stream ------------------------------------

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    property bool cursorOn: true
    Timer {
        interval: 530
        repeat: true
        running: true
        onTriggered: root.cursorOn = !root.cursorOn
    }

    property int sweep: 0
    Timer {
        interval: 90
        repeat: true
        running: root.phase === "verifying"
        onTriggered: root.sweep = (root.sweep + 1) % 12
    }

    property string dataStream: ""
    Timer {
        interval: 160
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            const word = () => Math.floor(Math.random() * 65536).toString(16).toUpperCase().padStart(4, "0");
            root.dataStream = [word(), word(), word(), word(), word(), word()].join(" ");
        }
    }

    // --- Input ----------------------------------------------------------

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.submit();
            else if (event.key === Qt.Key_Backspace) {
                if (root.editable)
                    root.password = ctrl ? "" : root.password.slice(0, -1);
            } else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_U)) {
                if (root.editable)
                    root.password = "";
            } else if (event.key === Qt.Key_Up)
                root.cycle(users, -1);
            else if (event.key === Qt.Key_Down)
                root.cycle(users, 1);
            else if (event.key === Qt.Key_F1)
                root.cycle(sessions, 1);
            else if (event.key === Qt.Key_F10 && sddm.canSuspend)
                root.power("SUSPEND");
            else if (event.key === Qt.Key_F11 && sddm.canReboot)
                root.power("RESTART");
            else if (event.key === Qt.Key_F12 && sddm.canPowerOff)
                root.power("POWER OFF");
            else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                if (root.editable)
                    root.password += event.text;
            }
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: keys.forceActiveFocus()
    }

    // --- Picture --------------------------------------------------------

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

    // A clickable status-line item; lights up while armed.
    component Action: Status {
        id: action
        property string name: ""
        property bool available: true
        signal activated()
        visible: available
        text: "[" + name + "]"
        color: root.armed === name ? theme.colorYellow : theme.colorFg
        opacity: actionMouse.containsMouse ? 1 : 0.7

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            anchors.margins: -root.sz(6)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                action.activated();
                keys.forceActiveFocus();
            }
        }
    }

    CrtScreen {
        id: crt
        anchors.fill: parent

        VectorTerrain {
            y: parent.height * 0.6
            width: parent.width
            height: parent.height * 0.4
            opacity: 0.3
        }

        Item {
            id: screenText
            width: parent.width
            height: parent.height

            readonly property real margin: root.sz(80)

            // Header.
            Column {
                x: screenText.margin
                y: screenText.margin
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
                    text: "INTERFACE 2037  ·  CREW ACCESS"
                    color: theme.colorFg
                    opacity: 0.55
                    font.family: theme.fontFamily
                    font.pixelSize: root.sz(18)
                    font.letterSpacing: root.sz(4)
                }
            }

            Column {
                anchors.right: parent.right
                anchors.rightMargin: screenText.margin
                y: screenText.margin
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
                    text: "VESSEL " + root.host
                    color: theme.colorFg
                    opacity: 0.55
                    font.family: theme.fontFamily
                    font.pixelSize: root.sz(18)
                    font.letterSpacing: root.sz(4)
                }
            }

            Rectangle {
                x: screenText.margin
                y: screenText.margin + root.sz(84)
                width: parent.width - screenText.margin * 2
                height: 1
                color: theme.colorDim

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

            // The exchange with MU/TH/UR.
            Rectangle {
                id: console_
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.56
                width: Math.min(parent.width - screenText.margin * 2, root.sz(1180))
                height: lines.height + root.sz(64)
                color: Qt.alpha(theme.colorBg, 0.88)
                border.color: root.phase === "denied" ? theme.colorRed : theme.colorFg
                border.width: Math.max(1, root.sz(2))

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
                        fullText: "> VESSEL " + root.host + " ONLINE. CREW ACCESS REQUESTED."
                        delay: 700
                    }
                    Line {
                        fullText: "> CREW MEMBER: " + root.crew
                        delay: 1500
                        // More than one crew member: Up/Down picks.
                        suffix: done && users.count > 1 ? "   [↑↓]" : ""
                        color: theme.colorBone
                    }
                    Line {
                        fullText: "> IDENTIFY: "
                        delay: 2300
                        color: theme.colorFocus
                        suffix: done ? "*".repeat(Math.min(root.password.length, 40))
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
                        visible: root.answer.length > 0 && root.phase !== "verifying"
                        fullText: root.answer ? "> " + root.answer : ""
                        interval: 12
                        color: root.phase === "granted" ? theme.colorGreen
                            : root.answerIsError ? theme.colorRed
                            : root.armed ? theme.colorYellow : theme.colorFg
                    }
                    Line {
                        visible: keyboard.capsLock && root.editable
                        fullText: visible ? "> CAPS LOCK IS ON." : ""
                        interval: 12
                        color: theme.colorYellow
                    }
                }
            }

            // Status line: session and keyboard on the left, the data
            // stream in the middle, power on the right.
            Item {
                x: screenText.margin
                y: parent.height - screenText.margin - height
                width: parent.width - screenText.margin * 2
                height: sessionAction.height

                Row {
                    spacing: root.sz(28)

                    Action {
                        id: sessionAction
                        name: "SESSION " + root.session + (sessions.count > 1 ? " F1" : "")
                        color: theme.colorFg
                        onActivated: root.cycle(sessions, 1)
                    }
                    Status {
                        visible: keyboard.layouts.length > 1
                        text: "KBD " + (keyboard.layouts.length > keyboard.currentLayout
                            ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : "")
                    }
                }

                Status {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dataStream
                    color: theme.colorDim
                }

                Row {
                    anchors.right: parent.right
                    spacing: root.sz(28)

                    Action {
                        name: "SUSPEND"
                        available: sddm.canSuspend
                        onActivated: root.power(name)
                    }
                    Action {
                        name: "RESTART"
                        available: sddm.canReboot
                        onActivated: root.power(name)
                    }
                    Action {
                        name: "POWER OFF"
                        available: sddm.canPowerOff
                        onActivated: root.power(name)
                    }
                }
            }
        }

        // Phosphor glow, as on the lock screen (hideSource, not a hidden
        // tree: the exchange's Column must still lay out lines that
        // appear).
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

    Component.onCompleted: {
        crt.powerOn();
        keys.forceActiveFocus();
    }
}
