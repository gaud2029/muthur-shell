import QtQuick
import QtQuick.Shapes

// A small vector sketch of one of the themed wallpaper designs (grid,
// topo, horizon, dots), drawn from ThemeStore.wallpaperLayouts in a
// preset's own colors: the same few lines for every theme, showing the
// pattern rather than the image.
Item {
    id: root

    property int design: 0
    property color background: "black"
    property color line: "grey"
    property color accent: "white"

    readonly property var layout: ThemeStore.wallpaperLayouts[design]
    // Path data is in a 100×100 box; strokes stay 1px at any size.
    readonly property real unit: 100 / Math.max(1, width)

    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.background
    }

    Shape {
        width: 100
        height: 100
        scale: 1 / root.unit
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.layout.fill ? "transparent" : Qt.alpha(root.line, 0.45)
            fillColor: root.layout.fill ? Qt.alpha(root.line, 0.8) : "transparent"
            strokeWidth: root.unit
            PathSvg { path: root.layout.base }
        }

        ShapePath {
            strokeColor: Qt.alpha(root.line, 0.9)
            fillColor: "transparent"
            strokeWidth: root.unit
            PathSvg { path: root.layout.major }
        }

        ShapePath {
            strokeColor: root.accent
            fillColor: "transparent"
            strokeWidth: root.unit * 1.5
            PathSvg { path: root.layout.accent }
        }
    }
}
