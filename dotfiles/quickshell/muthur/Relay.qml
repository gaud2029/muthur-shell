pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Matrix messages, through relay (a separate project: a small end-to-end
// encrypted Matrix client whose daemon serves JSON lines on
// $XDG_RUNTIME_DIR/relay.sock). Nothing here knows Matrix: the daemon
// syncs, decrypts and sends; this only mirrors its rooms and the open
// room's messages for [MSG] and its panel. Without the daemon running,
// `available` stays false and [MSG] stays hidden; it's tried again every
// few seconds, so starting relay later just works.
Singleton {
    id: root

    readonly property bool available: socket.connected
    // { user_id, device_id, verified, cross_signing, synced }
    property var status: null
    // [{ id, name, encrypted, unread, highlights, last_ts }], latest first.
    property var rooms: []
    readonly property int unread: rooms.reduce((n, r) => n + r.unread, 0)
    readonly property int highlights: rooms.reduce((n, r) => n + r.highlights, 0)

    // The open conversation ("" for the room list) and its messages:
    // [{ id, sender_name, ts, body, msgtype, own, edit, undecryptable }].
    property string currentRoom: ""
    readonly property var currentRoomInfo: rooms.find(r => r.id === currentRoom) ?? null
    property var messages: []
    property bool loading: false
    property string error: ""

    readonly property string socketPath: (Quickshell.env("RELAY_SOCKET") || "")
        || (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/relay.sock"

    property int nextId: 1
    property var pending: ({})

    function request(cmd, args, callback) {
        if (!socket.connected)
            return;
        const id = root.nextId++;
        if (callback)
            root.pending[id] = callback;
        socket.write(JSON.stringify(Object.assign({ id: id, cmd: cmd }, args || {})) + "\n");
        socket.flush();
    }

    function openRoom(roomId) {
        root.currentRoom = roomId;
        root.messages = [];
        root.error = "";
        root.loading = true;
        request("history", { room: roomId, limit: 50 }, (ok, data, err) => {
            if (roomId !== root.currentRoom)
                return;
            root.loading = false;
            root.messages = ok ? data || [] : [];
            root.error = ok ? "" : err;
        });
        markRead(roomId);
    }

    function closeRoom() {
        root.currentRoom = "";
        root.messages = [];
        root.error = "";
    }

    function markRead(roomId) {
        const room = root.rooms.find(r => r.id === roomId);
        if (room && room.unread > 0)
            request("read", { room: roomId });
    }

    function send(body) {
        const roomId = root.currentRoom;
        if (!roomId || !body.trim())
            return;
        // Shown when it comes back through sync, like everyone else's.
        request("send", { room: roomId, body: body }, (ok, data, err) => {
            if (!ok)
                root.error = err;
        });
    }

    function handle(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.event) {
            if (msg.event === "rooms")
                root.rooms = msg.data || [];
            else if (msg.event === "status")
                root.status = msg.data;
            else if (msg.event === "message" && msg.data.room === root.currentRoom) {
                root.messages = root.messages.concat([msg.data]);
                if (panelOpen)
                    markRead(root.currentRoom);
            }
            return;
        }
        const callback = root.pending[msg.id];
        if (callback) {
            delete root.pending[msg.id];
            callback(msg.ok, msg.data, msg.error || "");
        }
    }

    // Set by the panel: new messages in the open room only count as read
    // while it's actually on screen.
    property bool panelOpen: false
    onPanelOpenChanged: if (panelOpen && currentRoom)
        markRead(currentRoom)

    // The conversation on screen: relay sends no desktop notification
    // for it, the message being right there.
    readonly property string shownRoom: panelOpen ? currentRoom : ""
    onShownRoomChanged: request("focus", { room: shownRoom })

    Socket {
        id: socket
        path: root.socketPath
        connected: true
        parser: SplitParser {
            onRead: line => root.handle(line)
        }
        onConnectedChanged: {
            root.pending = {};
            if (connected) {
                root.request("subscribe");
                if (root.shownRoom)
                    root.request("focus", { room: root.shownRoom });
                root.request("status", {}, (ok, data) => { if (ok) root.status = data; });
                root.request("rooms", {}, (ok, data) => { if (ok) root.rooms = data || []; });
                if (root.currentRoom)
                    root.openRoom(root.currentRoom);
            } else {
                root.status = null;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}
