import QtQuick
import Quickshell.Services.Mpris

// The bar's MPRIS strip (GitHub issue #23): the current track as text and
// previous / play-pause / next, hidden while nothing is playing or paused.
// A vertical bar has no room for a title, so it keeps only the controls.
// The drawer shows the same player with more detail.
AxisGrid {
    id: root

    // Same choice as the drawer: whichever player is playing, else the
    // first one, so a paused track still shows.
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) || players[0] || null;
    }

    visible: !!player && player.playbackState !== MprisPlaybackState.Stopped
    spacing: theme.gridUnit
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Theme { id: theme }

    Text {
        visible: !theme.vertical
        width: Math.min(implicitWidth, theme.gridUnit * 60)
        elide: Text.ElideRight
        text: root.player
            ? [root.player.trackTitle || "(untitled)", root.player.trackArtist].filter(s => s).join(" — ")
            : ""
        color: root.player && root.player.isPlaying ? theme.colorFg : theme.colorDim
        font.family: theme.fontFamily
        font.pixelSize: theme.px(11)
        font.letterSpacing: theme.letterSpacing
    }

    TerminalButton {
        label: "|<"
        square: true
        visible: !!root.player && root.player.canGoPrevious
        onClicked: root.player.previous()
    }

    TerminalButton {
        label: root.player && root.player.isPlaying ? "||" : ">"
        square: true
        visible: !!root.player && root.player.canTogglePlaying
        onClicked: root.player.togglePlaying()
    }

    TerminalButton {
        label: ">|"
        square: true
        visible: !!root.player && root.player.canGoNext
        onClicked: root.player.next()
    }
}
