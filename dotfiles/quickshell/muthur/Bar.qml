import QtQuick
import Quickshell

PanelWindow {
    id: root

    property var niri
    property var popupPanels: [controlPanel, aiPanel, calendarPanel, batteryPanel]

    readonly property string position: theme.barPosition
    readonly property bool vertical: theme.vertical

    // Screen corner + margins that put a popup right beside `item`, opening
    // toward the bar's far end so it can't overflow whichever end the
    // button sits at. Shape matches fuzzel's --anchor/--x-margin/--y-margin.
    function popupPlacement(item) {
        const pos = item.mapToItem(null, 0, 0);
        if (root.vertical) {
            const upper = pos.y + item.height / 2 < root.height / 2;
            return {
                anchor: (upper ? "top" : "bottom") + "-" + root.position,
                x: 0,
                y: upper ? pos.y : root.height - pos.y - item.height
            };
        }
        const left = pos.x + item.width / 2 < root.width / 2;
        return {
            anchor: root.position + "-" + (left ? "left" : "right"),
            x: left ? pos.x : root.width - pos.x - item.width,
            y: 0
        };
    }

    function togglePanel(panel) {
        const wasVisible = panel.visible;
        for (const p of popupPanels)
            p.visible = false;
        panel.visible = !wasVisible;
    }

    anchors {
        left: root.position !== "right"
        right: root.position !== "left"
        top: root.position !== "bottom"
        bottom: root.position !== "top"
    }

    // The axis stretched by the anchors ignores its implicit size, so the
    // other one becomes the bar thickness (and the reserved exclusive zone).
    implicitWidth: theme.barThickness
    implicitHeight: theme.barThickness
    color: theme.colorBg

    Theme { id: theme }

    // Scanline texture — cheap CRT flavor, static so it's painted once.
    Canvas {
        anchors.fill: parent
        opacity: 0.12
        onPaint: {
            const ctx = getContext("2d");
            ctx.strokeStyle = "black";
            ctx.lineWidth = 1;
            for (let y = 0; y < height; y += 2) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
    }

    // Hairline on the edge facing the desktop. Positioned with x/y rather
    // than anchors: switching anchors on a position change passes through
    // a transient state with both sides anchored, which writes an explicit
    // size that survives once the anchor is cleared.
    Rectangle {
        x: root.position === "left" ? parent.width - 1 : 0
        y: root.position === "top" ? parent.height - 1 : 0
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
        color: theme.colorFg
    }

    // Widgets flow along the bar from each end: a "start" group at the
    // top/left and an "end" group at the bottom/right, each centered across
    // the bar. Same x/y-not-anchors rule as the hairline above.
    component BarGroup: AxisGrid {
        property bool atEnd: false
        spacing: theme.gridUnit * 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        x: root.vertical ? (parent.width - width) / 2 : (atEnd ? parent.width - width : 0)
        y: root.vertical ? (atEnd ? parent.height - height : 0) : (parent.height - height) / 2
    }

    // Length along the bar left over once every other widget is placed;
    // the window list may grow into 75% of it.
    readonly property real windowListBudget: {
        const along = item => root.vertical ? item.height : item.width;
        const used = along(launcher) + along(workspaces) + startGroup.spacing * 2
                   + along(endGroup) + startGroup.spacing;
        return Math.max(0, 0.75 * (along(content) - used));
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 2

        BarGroup {
            id: startGroup
            // Wider than the end group: the workspace and window tiles are
            // themselves 1-unit apart, so their sections need clearer gaps.
            spacing: theme.gridUnit * 4

            TerminalButton {
                id: launcher
                square: true
                onClicked: {
                    const p = root.popupPlacement(launcher);
                    Quickshell.execDetached(["fuzzel", "--anchor", p.anchor,
                                             "--x-margin", String(p.x), "--y-margin", String(p.y)]);
                }

                // The terminal cursor, breathing instead of blinking.
                Rectangle {
                    anchors.centerIn: parent
                    width: theme.px(8)
                    height: theme.px(14)
                    color: launcher.filled ? theme.colorBg : theme.colorFg

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }

            Workspaces {
                id: workspaces
                niri: root.niri
                screen: root.screen
                outputName: root.screen ? root.screen.name : ""
            }

            WindowList {
                lengthBudget: root.windowListBudget
            }
        }

        BarGroup {
            id: endGroup
            atEnd: true

            BatteryButton {
                selected: batteryPanel.visible
                onClicked: root.togglePanel(batteryPanel)
            }

            Clock {
                active: calendarPanel.visible
                onClicked: root.togglePanel(calendarPanel)
            }

            AiButton {
                selected: aiPanel.visible
                onClicked: root.togglePanel(aiPanel)
            }

            TerminalButton {
                label: "SYS"
                square: true
                selected: controlPanel.visible
                onClicked: root.togglePanel(controlPanel)
            }

            TerminalButton {
                id: plusButton
                label: drawer.visible ? "-" : "+"
                square: true
                selected: drawer.visible
                onClicked: {
                    drawer.placement = root.popupPlacement(plusButton);
                    drawer.visible = !drawer.visible;
                }
            }
        }
    }

    ControlPanel {
        id: controlPanel
        screen: root.screen
    }

    AiPanel {
        id: aiPanel
        screen: root.screen
    }

    CalendarPanel {
        id: calendarPanel
        screen: root.screen
    }

    BatteryPanel {
        id: batteryPanel
        screen: root.screen
    }

    Drawer {
        id: drawer
        screen: root.screen
    }
}
