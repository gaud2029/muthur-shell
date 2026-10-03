pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// The session lock (ext-session-lock-v1): one LockView per screen, all
// sharing the state kept here — the typed password, the phase of the
// exchange and MU/TH/UR's last answer. Authenticates through PAM's
// "login" stack, like swaylock, so faillock and the rest of the system's
// policy apply. Locked from the drawer's LOCK button or from outside with
//   quickshell ipc -c muthur call lock lock
// (scripts/lock.sh, which swayidle in labwc's autostart runs).
Singleton {
    id: root

    // Mirrored by hand: WlSessionLock.locked doesn't notify when set from
    // QML, so a binding to it never updates.
    property bool locked: false
    onLockedChanged: lockFlag.setText(locked ? "1\n" : "")
    // "boot" while the screens power on and type their greeting, then
    // "input"; "verifying" while PAM decides, then "denied" (back to
    // "input" after a moment) or "granted" (the screens power off and the
    // session unlocks).
    property string phase: "boot"
    property string password: ""
    property int failures: 0
    // MU/TH/UR's answer under the prompt, and whether it's bad news.
    property string answer: ""
    property bool answerIsError: false
    // No input for a while at an empty prompt: the screens dim to the
    // clock to spare the panel.
    property bool idle: false
    property real lastInput: 0

    // Typing (and submitting) works except while PAM decides or the
    // screens power off.
    readonly property bool editable: phase === "boot" || phase === "input" || phase === "denied"

    readonly property string user: (Quickshell.env("USER") || "crew").toUpperCase()

    readonly property var deniedAnswers: [
        "ACCESS DENIED. IDENT NOT RECOGNIZED.",
        "UNABLE TO CLARIFY. IDENT REJECTED.",
        "ACCESS DENIED. CREW MEMBER NOT CONFIRMED."
    ]

    function lock() {
        if (sessionLock.locked)
            return;
        root.engage();
    }

    function engage() {
        root.phase = "boot";
        root.password = "";
        root.failures = 0;
        root.answer = "";
        root.answerIsError = false;
        root.poke();
        sessionLock.locked = true;
        root.locked = true;
        bootTimer.restart();
    }

    function poke() {
        root.lastInput = Date.now();
        root.idle = false;
    }

    function type(text) {
        root.poke();
        if (root.editable)
            root.password += text;
    }

    function backspace() {
        root.poke();
        if (root.editable)
            root.password = root.password.slice(0, -1);
    }

    function clear() {
        root.poke();
        if (root.editable)
            root.password = "";
    }

    function submit() {
        root.poke();
        if (!root.editable)
            return;
        if (root.password.length === 0) {
            root.say("UNABLE TO CLARIFY. ENTER IDENT TO PROCEED.", true);
            return;
        }
        root.phase = "verifying";
        root.say("", false);
        if (!pam.start())
            root.fail("INTERFACE FAULT. AUTHENTICATION UNAVAILABLE.");
    }

    function say(text, isError) {
        root.answer = text;
        root.answerIsError = isError;
    }

    function fail(text) {
        root.failures++;
        root.password = "";
        root.phase = "denied";
        root.say(text, true);
        deniedTimer.restart();
    }

    // A hot reload, or a crash and restart, of the shell drops the lock
    // object while the compositor keeps the session locked: a black screen
    // nobody could unlock. A flag in the runtime dir (gone at logout)
    // remembers the session was locked; a new instance that finds it locks
    // again, once the old lock object is gone (a second lock while it
    // exists is a protocol error). The session stays locked throughout.
    FileView {
        id: lockFlag
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/muthur-shell-locked"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: if (lockFlag.text().trim() === "1") relockTimer.start()

    Timer {
        id: relockTimer
        interval: 500
        onTriggered: if (!sessionLock.locked) root.engage()
    }

    WlSessionLock {
        id: sessionLock

        onLockStateChanged: root.locked = locked

        WlSessionLockSurface {
            color: "black"

            LockView {
                anchors.fill: parent
            }
        }
    }

    PamContext {
        id: pam
        // MUTHUR_PAM_DIR points a test instance at a throwaway PAM config
        // (pam_deny / pam_permit as "login"), so trying the lock out
        // doesn't count against the real account's faillock.
        configDirectory: Quickshell.env("MUTHUR_PAM_DIR") || "/etc/pam.d"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.password);
            else if (this.message)
                root.say(this.message.toUpperCase(), this.messageIsError);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "granted";
                root.say("ACCESS GRANTED. WELCOME BACK, " + root.user + ".", false);
                root.password = "";
                unlockTimer.restart();
            } else if (result === PamResult.MaxTries) {
                root.fail("MAXIMUM ATTEMPTS EXCEEDED. ACCESS SUSPENDED.");
            } else {
                // PAM may have said why (faillock's lockout notice); keep it.
                root.fail(root.answerIsError && root.answer ? root.answer
                    : root.deniedAnswers[(root.failures) % root.deniedAnswers.length]);
            }
        }

        onError: error => root.fail("INTERFACE FAULT. " + PamError.toString(error).toUpperCase() + ".")
    }

    // Long enough for the power-on and the greeting; typing is accepted
    // throughout.
    Timer {
        id: bootTimer
        interval: 2600
        onTriggered: if (root.phase === "boot") root.phase = "input"
    }

    Timer {
        id: deniedTimer
        interval: 2200
        onTriggered: if (root.phase === "denied") root.phase = "input"
    }

    // The screens' power-off animation runs before the lock lets go.
    Timer {
        id: unlockTimer
        interval: 2000
        onTriggered: {
            sessionLock.locked = false;
            root.locked = false;
            root.phase = "boot";
            root.answer = "";
        }
    }

    Timer {
        running: root.locked
        repeat: true
        interval: 1000
        onTriggered: root.idle = root.phase === "input" && root.password.length === 0
            && Date.now() - root.lastInput > 30000
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }

        // Whether the compositor has confirmed the lock (every screen
        // covered); read directly, it doesn't notify (see `locked`).
        function isSecure(): bool {
            return sessionLock.secure;
        }
    }
}
