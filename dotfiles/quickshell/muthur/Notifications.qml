pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

// The shell is the notification server (GitHub issue #25, replacing mako):
// every notification is kept in `history` (the [+] drawer lists it) until
// it's dismissed or its sender withdraws it, and shows as a popup
// (NotificationPopups.qml) unless muted — do-not-disturb, or focus mode.
// Critical ones always pop up.
//   quickshell ipc -c muthur call notifications toggleDnd | clear
Singleton {
    id: root

    property bool dnd: false
    readonly property bool muted: dnd || Focus.active

    // Newest first.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    // The ones currently shown as popups, newest first; a notification
    // that closes drops out of the history and so out of here.
    property var popupList: []
    readonly property var popups: popupList.filter(n => history.includes(n))
    // Arrived since the drawer was last opened.
    property int unread: 0

    // Oldest ones are dismissed past this.
    readonly property int historyLimit: 50
    // Popup lifetime when the sender doesn't ask for one; critical ones
    // stay until dismissed.
    readonly property int defaultTimeout: 6000

    // Arrival times by notification id, kept across hot reloads with the
    // notifications themselves (keepOnReload). JSON: a JS object can't
    // cross into the reloaded engine.
    PersistentProperties {
        id: persist
        reloadableId: "notifications"
        property string receivedAt: "{}"
    }

    function receivedAt(n) {
        const t = n ? JSON.parse(persist.receivedAt)[n.id] : 0;
        return t ? new Date(t) : null;
    }

    function timeout(n) {
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        return n.urgency === NotificationUrgency.Critical ? 0 : defaultTimeout;
    }

    function hidePopup(n) {
        popupList = popupList.filter(p => p !== n);
    }

    function dismiss(n) {
        hidePopup(n);
        n.dismiss();
    }

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popupList = [];
        unread = 0;
    }

    // A popup ran out: transient notifications go entirely, the rest stay
    // in the history.
    function timedOut(n) {
        hidePopup(n);
        if (n.transient)
            n.expire();
    }

    // Invoking an action closes a non-resident notification by itself.
    function invoke(action, n) {
        hidePopup(n);
        action.invoke();
    }

    // "Open the sender": its default action if it has one, else raise its
    // window, else launch its desktop entry.
    function open(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) {
            invoke(def, n);
            return;
        }
        const names = [n.desktopEntry, n.appName].filter(s => s).map(s => s.toLowerCase());
        const win = ToplevelManager.toplevels.values.find(t => {
            const app = (t.appId || "").toLowerCase();
            return app && names.some(s => app === s || app.split(".").pop() === s.split(".").pop());
        });
        if (win) {
            win.activate();
        } else if (n.desktopEntry) {
            const entry = DesktopEntries.byId(n.desktopEntry);
            if (entry)
                entry.execute();
        }
        dismiss(n);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            // Kept from before a hot reload and announced again: already
            // in the history, not new.
            if (n.lastGeneration)
                return;

            const all = server.trackedNotifications.values;
            for (let i = 0; i < all.length - root.historyLimit; i++)
                all[i].dismiss();

            // Times of notifications that have since closed go.
            const old = JSON.parse(persist.receivedAt);
            const at = {};
            for (const t of server.trackedNotifications.values)
                if (old[t.id])
                    at[t.id] = old[t.id];
            at[n.id] = Date.now();
            persist.receivedAt = JSON.stringify(at);

            root.unread++;
            if (!root.muted || n.urgency === NotificationUrgency.Critical)
                root.popupList = [n].concat(root.popups);
        }
    }

    // Going quiet takes the popups down too (they stay in the history).
    onMutedChanged: if (muted)
        popupList = popups.filter(n => n.urgency === NotificationUrgency.Critical)

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }

        function clear(): void {
            root.clear();
        }
    }
}
