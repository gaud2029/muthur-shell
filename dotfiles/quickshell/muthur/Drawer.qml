import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

// Ribbon opened by the [+]/[-] button — system tray (issue #7) and MPRIS
// "now playing" (issue #8). Deliberately independent of the SYS/AI
// popup-panel exclusion group, and not built on PopupPanel: it has no
// tabs and a very different shape.
PanelWindow {
    id: root

    // Set by Bar from popupPlacement() before each open.
    property var placement: ({ anchor: "bottom-left", x: 0, y: 0 })

    anchors {
        top: placement.anchor.startsWith("top")
        bottom: placement.anchor.startsWith("bottom")
        left: placement.anchor.endsWith("left")
        right: placement.anchor.endsWith("right")
    }
    margins {
        top: placement.y
        bottom: placement.y
        left: placement.x
        right: placement.x
    }

    implicitWidth: theme.gridUnit * 88
    implicitHeight: theme.gridUnit * 84
    color: theme.colorBg
    visible: false
    onVisibleChanged: if (visible) escapeCatcher.forceActiveFocus()

    exclusiveZone: 0
    aboveWindows: true
    focusable: true

    Theme { id: theme }

    EscapeToClose { id: escapeCatcher; targetWindow: root }

    // Prefer whichever player is actively playing; fall back to the
    // first known player so a paused track still shows.
    readonly property var activePlayer: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) || players[0] || null;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: theme.colorFg
        border.width: 1
    }

    // Session controls, pinned to the bottom edge.
    Row {
        id: sessionRow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: theme.gridUnit * 3
        spacing: theme.gridUnit * 2

        TerminalButton {
            label: "LOCK"
            onClicked: Quickshell.execDetached(["swaylock", "-f", "-c", "000000"])
        }
        ConfirmButton {
            action: "LOGOUT"
            // Hyprland with a Lua config takes only the Lua dispatch form,
            // the classic config only the classic one; hyprctl exits
            // non-zero on the mismatch. niri's quit asks for confirmation
            // by default; this button already did.
            command: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
                ? ["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || hyprctl dispatch exit"]
                : Quickshell.env("NIRI_SOCKET")
                    ? ["niri", "msg", "action", "quit", "--skip-confirmation"]
                    : ["labwc", "--exit"]
        }
        ConfirmButton {
            action: "SUSPEND"
            command: ["systemctl", "suspend"]
        }
        ConfirmButton {
            action: "POWER OFF"
            command: ["systemctl", "poweroff"]
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: sessionRow.top
        anchors.margins: theme.gridUnit * 3
        height: 1
        color: theme.colorDim
    }

    Column {
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 3
        anchors.bottomMargin: sessionRow.height + theme.gridUnit * 9
        clip: true
        spacing: theme.gridUnit * 3

        Text {
            text: "TRAY"
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Flow {
            width: parent.width
            spacing: theme.gridUnit * 2

            Repeater {
                model: SystemTray.items

                IconImage {
                    id: trayIcon
                    required property var modelData
                    implicitSize: theme.tile
                    // An icon name the theme doesn't have resolves to the
                    // theme's own "missing image" glyph (Quickshell/Qt
                    // fall back before QML ever sees a load error) — that
                    // is expected, not a bug in this file.
                    source: Quickshell.iconPath(modelData.icon)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                trayIcon.modelData.activate();
                            } else if (mouse.button === Qt.MiddleButton) {
                                trayIcon.modelData.secondaryActivate();
                            } else if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu) {
                                const pos = trayIcon.mapToItem(null, mouse.x, mouse.y);
                                trayIcon.modelData.display(root, pos.x, pos.y);
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: SystemTray.items.values.length === 0
            text: "[ NO TRAY ICONS ]"
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Text {
            text: "NOW PLAYING"
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Text {
            visible: !root.activePlayer
            text: "[ NOTHING PLAYING ]"
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(11)
            font.letterSpacing: theme.letterSpacing
        }

        Column {
            width: parent.width
            visible: !!root.activePlayer
            spacing: theme.gridUnit

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.activePlayer ? (root.activePlayer.trackTitle || "(untitled)") : ""
                color: theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
                font.letterSpacing: theme.letterSpacing
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.activePlayer
                    ? [root.activePlayer.trackArtist, root.activePlayer.isPlaying ? "PLAYING" : "PAUSED"].filter(s => s).join(" — ")
                    : ""
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Row {
                spacing: theme.gridUnit * 2

                TerminalButton {
                    label: "|<"
                    square: true
                    visible: !!root.activePlayer && root.activePlayer.canGoPrevious
                    onClicked: root.activePlayer.previous()
                }
                TerminalButton {
                    label: root.activePlayer && root.activePlayer.isPlaying ? "||" : ">"
                    square: true
                    visible: !!root.activePlayer && root.activePlayer.canTogglePlaying
                    onClicked: root.activePlayer.togglePlaying()
                }
                TerminalButton {
                    label: ">|"
                    square: true
                    visible: !!root.activePlayer && root.activePlayer.canGoNext
                    onClicked: root.activePlayer.next()
                }
            }
        }
    }
}
