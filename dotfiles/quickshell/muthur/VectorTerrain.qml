import QtQuick

// A wireframe ground plane flying toward the viewer, like the Nostromo's
// descent displays: rails converging on a vanishing point at the top edge
// and cross lines sliding down in perspective. Built from plain rectangles
// (the rails never move, only the cross lines do), so it's all scene graph
// and no per-frame painting. Used by the lock screen.
Item {
    id: root

    property color color: theme.colorFg
    // Cross lines passing under the viewer per second.
    property real speed: 0.6
    property int rails: 28
    property int crossLines: 18
    // How far the rails fan out at the bottom edge, in widths.
    property real spread: 3.2
    property bool running: true

    // 0..1 across one cross-line spacing; drives the motion.
    property real phase: 0

    clip: true

    Theme { id: theme }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 1000 / root.speed
        loops: Animation.Infinite
        running: root.running && root.visible
    }

    // Rails: rotated 1px lines hung from the vanishing point.
    Repeater {
        model: root.rails + 1

        Rectangle {
            required property int index
            readonly property real dx: (index / root.rails - 0.5) * root.spread * root.width
            x: root.width / 2
            y: 0
            width: 1
            height: Math.hypot(dx, root.height)
            transformOrigin: Item.Top
            rotation: -Math.atan2(dx, root.height) * 180 / Math.PI
            antialiasing: true
            color: root.color
            opacity: 0.55
        }
    }

    // Cross lines at depth d draw at height / d: d = 1 is the bottom edge,
    // large d crowds toward the horizon.
    Repeater {
        model: root.crossLines

        Rectangle {
            required property int index
            readonly property real depth: index + 1 - root.phase
            x: 0
            y: depth > 0 ? root.height / depth : root.height
            width: root.width
            height: 1
            color: root.color
            opacity: Math.min(1, y / (root.height * 0.3)) * 0.8
            visible: y < root.height
        }
    }

    // A haze over the far distance where the lines pack too tightly to
    // read, and the horizon line on top of it.
    Rectangle {
        width: root.width
        height: root.height * 0.35
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.colorBg }
            GradientStop { position: 1.0; color: Qt.alpha(theme.colorBg, 0) }
        }
    }

    Rectangle {
        width: root.width
        height: 1
        color: root.color
    }
}
