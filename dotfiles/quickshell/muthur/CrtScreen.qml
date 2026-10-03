import QtQuick

// A full-screen CRT tube: whatever is put inside it is drawn on the
// theme's background behind scanlines, a vignette, a slow rolling band and
// the odd flicker, and can be switched on and off like an old monitor —
// a beam opening out into the picture, and collapsing back to a line and
// a dot. Shared by the lock screen and the screensaver.
Item {
    id: root

    default property alias content: stage.data
    // The phosphor's color: the beam, the band, the power-on flash.
    property color tint: theme.colorFg
    // Off until powerOn(); an off tube is plain black.
    readonly property bool lit: stage.opacity > 0

    signal poweredOn()
    signal poweredOff()

    function powerOn() {
        offAnim.stop();
        onAnim.restart();
    }

    function powerOff() {
        onAnim.stop();
        offAnim.restart();
    }

    // A short horizontal judder, for a rejected password.
    function shake() {
        shakeAnim.restart();
    }

    Theme { id: theme }

    // Outside the picture the tube is black, whatever the palette.
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Item {
        id: stage
        width: root.width
        height: root.height
        opacity: 0
        transform: Scale {
            id: tube
            origin.x: stage.width / 2
            origin.y: stage.height / 2
            xScale: 0
            yScale: 0.004
        }

        Rectangle {
            anchors.fill: parent
            color: theme.colorBg
            z: -1
        }
    }

    // Scanlines, painted once per size.
    Canvas {
        anchors.fill: parent
        opacity: 0.22
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "black";
            for (let y = 0; y < height; y += 3)
                ctx.fillRect(0, y, width, 1);
        }
    }

    // The band of brighter phosphor that rolls down an unsynced screen.
    Rectangle {
        id: band
        width: root.width
        height: root.height * 0.22
        visible: root.lit
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(root.tint, 0.05) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        NumberAnimation on y {
            from: -band.height
            to: root.height
            duration: 9000
            loops: Animation.Infinite
            running: band.visible
        }
    }

    // Darker corners, as on a curved tube.
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const r = Math.hypot(width, height) / 2;
            const g = ctx.createRadialGradient(width / 2, height / 2, r * 0.45, width / 2, height / 2, r);
            g.addColorStop(0, "rgba(0,0,0,0)");
            g.addColorStop(1, "rgba(0,0,0,0.75)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }

    // Now and then the picture dips for a frame or two.
    Rectangle {
        id: dip
        anchors.fill: parent
        color: "black"
        opacity: 0
    }

    Timer {
        running: root.lit
        repeat: true
        interval: 2500
        onTriggered: {
            interval = 400 + Math.random() * 6000;
            dipAnim.restart();
        }
    }

    SequentialAnimation {
        id: dipAnim
        NumberAnimation { target: dip; property: "opacity"; to: 0.05 + Math.random() * 0.06; duration: 30 }
        NumberAnimation { target: dip; property: "opacity"; to: 0; duration: 90 }
    }

    // White-hot burst as the picture opens.
    Rectangle {
        id: flash
        anchors.fill: parent
        color: Qt.lighter(root.tint, 1.6)
        opacity: 0
    }

    // The beam: a bright line while the picture opens or collapses, and
    // the dot it leaves behind.
    Rectangle {
        id: beam
        anchors.centerIn: parent
        width: Math.max(height, root.width * tube.xScale)
        height: Math.max(2, root.height / 360)
        color: Qt.lighter(root.tint, 1.5)
        opacity: 0
    }

    SequentialAnimation {
        id: onAnim
        ScriptAction {
            script: {
                tube.xScale = 0;
                tube.yScale = 0.004;
                stage.opacity = 1;
                beam.opacity = 1;
            }
        }
        NumberAnimation { target: tube; property: "xScale"; to: 1; duration: 180; easing.type: Easing.OutQuad }
        ParallelAnimation {
            NumberAnimation { target: tube; property: "yScale"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: beam; property: "opacity"; to: 0; duration: 240 }
            SequentialAnimation {
                NumberAnimation { target: flash; property: "opacity"; to: 0.22; duration: 90 }
                NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutQuad }
            }
        }
        ScriptAction { script: root.poweredOn() }
    }

    SequentialAnimation {
        id: offAnim
        ParallelAnimation {
            NumberAnimation { target: tube; property: "yScale"; to: 0.004; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: beam; property: "opacity"; to: 1; duration: 220 }
            SequentialAnimation {
                NumberAnimation { target: flash; property: "opacity"; to: 0.12; duration: 60 }
                NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 160 }
            }
        }
        NumberAnimation { target: tube; property: "xScale"; to: 0; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: stage.opacity = 0 }
        NumberAnimation { target: beam; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InQuad }
        ScriptAction { script: root.poweredOff() }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: stage; property: "x"; to: -14; duration: 40 }
        NumberAnimation { target: stage; property: "x"; to: 11; duration: 50 }
        NumberAnimation { target: stage; property: "x"; to: -7; duration: 50 }
        NumberAnimation { target: stage; property: "x"; to: 4; duration: 50 }
        NumberAnimation { target: stage; property: "x"; to: 0; duration: 60 }
    }
}
