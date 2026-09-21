import QtQuick

// A thin scrollbar for a Flickable, drawn in the shell's terminal style:
// a dim track along the right edge with a solid thumb. Only visible when
// there is more content than fits. Place it as a sibling of the Flickable
// and point `flickable` at it; it anchors itself to the Flickable's edge.
Rectangle {
    id: root

    required property Flickable flickable

    readonly property bool needed: flickable.contentHeight > flickable.height + 1

    anchors.top: flickable.top
    anchors.bottom: flickable.bottom
    anchors.left: flickable.right
    anchors.leftMargin: theme.gridUnit
    width: theme.gridUnit
    visible: needed
    color: "transparent"
    border.color: theme.colorDim
    border.width: 1

    Theme { id: theme }

    readonly property real range: Math.max(0, flickable.contentHeight - flickable.height)

    Rectangle {
        id: thumb
        x: 0
        width: parent.width
        height: Math.max(theme.gridUnit * 3, parent.height * flickable.height / Math.max(1, flickable.contentHeight))
        y: root.range > 0 ? (parent.height - height) * Math.max(0, Math.min(1, flickable.contentY / root.range)) : 0
        color: dragArea.pressed ? theme.colorFocus : theme.colorFg
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        property real grabOffset: 0

        function scrollTo(mouseY) {
            const travel = root.height - thumb.height;
            if (travel <= 0)
                return;
            const pos = Math.max(0, Math.min(1, (mouseY - grabOffset) / travel));
            flickable.contentY = pos * root.range;
        }

        onPressed: mouse => {
            // Grab the thumb where it was clicked; a click on the track
            // centers the thumb there instead.
            grabOffset = (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height)
                ? mouse.y - thumb.y : thumb.height / 2;
            scrollTo(mouse.y);
        }
        onPositionChanged: mouse => { if (pressed) scrollTo(mouse.y); }
    }
}
