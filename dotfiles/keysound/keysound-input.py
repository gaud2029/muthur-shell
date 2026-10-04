#!/usr/bin/env python3
"""Keypress feed for the muthur shell's typing sounds (GitHub issue #21).

Runs as a system service (muthur-keysound-input.service: a throwaway
DynamicUser in the `input` group, sandboxed) so no user process ever needs
raw keyboard access. It reads the keyboards' evdev nodes and, for each key
press, sends one byte to whoever is connected to its socket:

    bits 0-1  what kind of key: 0 any, 1 space, 2 enter, 3 backspace
    bits 2-4  roughly where on the keyboard, 0 (far left) .. 6 (far right)

The keycode itself is dropped on the spot: what leaves this process is
"a key, about here", enough to place a sound in stereo and nothing to
reconstruct text from. Modifiers make no sound and send nothing. The
keyboards are only opened while someone is listening.

Standard library only: it's started by systemd with the system Python.
"""

import errno
import os
import selectors
import socket
import struct
import time

SOCKET_PATH = os.environ.get("MUTHUR_KEYSOUND_SOCKET",
                             "/run/muthur-keysound/events.sock")
RESCAN_SECONDS = 3

EVENT = struct.Struct("llHHi")  # struct input_event on 64-bit
EV_KEY = 0x01
EV_REP_BIT = 0x100000           # in the EV= bitmask: autorepeat, i.e. a typing keyboard

KEY, SPACE, ENTER, BACKSPACE = range(4)
SILENT = {29, 97, 42, 54, 56, 100, 125, 126, 58, 0x1d0}  # ctrl, shift, alt, meta, caps, fn


def build_layout():
    """Keycode -> (kind, position 0..6) for a staggered main block."""
    layout = {}
    rows = [  # first keycode, key count, stagger (in key widths)
        (2, 12, 1.0),    # 1 .. =
        (16, 12, 1.5),   # q .. ]
        (30, 11, 1.75),  # a .. '
        (44, 10, 2.25),  # z .. /
    ]
    width = 14.5
    for first, count, stagger in rows:
        for i in range(count):
            pos = (stagger + i + 0.5) / width
            layout[first + i] = (KEY, round(pos * 6))
    layout.update({
        1: (KEY, 0), 41: (KEY, 0), 15: (KEY, 0), 86: (KEY, 1),
        43: (KEY, 6), 57: (SPACE, 3),
        28: (ENTER, 6), 96: (ENTER, 6), 14: (BACKSPACE, 6),
    })
    return layout


LAYOUT = build_layout()


def encode(code):
    if code in SILENT:
        return None
    kind, pos = LAYOUT.get(code, (KEY, 3))
    return bytes([kind | max(0, min(6, pos)) << 2])


def keyboards():
    """The event nodes of devices that look like typing keyboards."""
    found = []
    try:
        with open("/proc/bus/input/devices") as f:
            blocks = f.read().split("\n\n")
    except OSError:
        return found
    for block in blocks:
        ev, handlers = 0, []
        for line in block.splitlines():
            if line.startswith("B: EV="):
                ev = int(line[6:], 16)
            elif line.startswith("H: Handlers="):
                handlers = line[12:].split()
        if ev & EV_REP_BIT and "kbd" in handlers:
            found += ["/dev/input/" + h for h in handlers if h.startswith("event")]
    return found


class Feed:
    def __init__(self):
        self.sel = selectors.DefaultSelector()
        self.clients = set()
        self.devices = {}  # path -> fd
        self.next_scan = 0

        os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
        try:
            os.unlink(SOCKET_PATH)
        except FileNotFoundError:
            pass
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o666)
        self.server.listen(8)
        self.server.setblocking(False)
        self.sel.register(self.server, selectors.EVENT_READ, "server")

    def open_devices(self):
        for path in keyboards():
            if path in self.devices:
                continue
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            self.devices[path] = fd
            self.sel.register(fd, selectors.EVENT_READ, path)

    def close_device(self, path):
        fd = self.devices.pop(path)
        self.sel.unregister(fd)
        os.close(fd)

    def close_devices(self):
        for path in list(self.devices):
            self.close_device(path)

    def send(self, data):
        for client in list(self.clients):
            try:
                client.send(data)
            except BlockingIOError:
                pass  # a slow listener misses a click, nothing more
            except OSError:
                self.drop(client)

    def drop(self, client):
        self.clients.discard(client)
        self.sel.unregister(client)
        client.close()
        if not self.clients:
            self.close_devices()

    def read_device(self, path, fd):
        try:
            data = os.read(fd, EVENT.size * 64)
        except BlockingIOError:
            return
        except OSError as e:
            if e.errno in (errno.ENODEV, errno.EIO):
                self.close_device(path)  # unplugged
            return
        for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
            _, _, kind, code, value = EVENT.unpack_from(data, i)
            if kind == EV_KEY and value == 1:
                byte = encode(code)
                if byte:
                    self.send(byte)

    def run(self):
        while True:
            if self.clients and time.monotonic() >= self.next_scan:
                self.open_devices()  # hotplug
                self.next_scan = time.monotonic() + RESCAN_SECONDS
            for key, _ in self.sel.select(timeout=RESCAN_SECONDS):
                tag = key.data
                if tag == "server":
                    client, _ = self.server.accept()
                    client.setblocking(False)
                    self.clients.add(client)
                    self.sel.register(client, selectors.EVENT_READ, "client")
                    self.next_scan = 0
                elif tag == "client":
                    # Listeners never talk; readable means hung up.
                    try:
                        if not key.fileobj.recv(64):
                            self.drop(key.fileobj)
                    except OSError:
                        self.drop(key.fileobj)
                else:
                    self.read_device(tag, key.fd)


if __name__ == "__main__":
    Feed().run()
