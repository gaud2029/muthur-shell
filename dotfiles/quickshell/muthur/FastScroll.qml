import QtQuick

// Mouse-wheel scrolling for a Flickable or ListView, faster than Qt's
// own (a few pixels a notch): each notch moves a fixed distance, eased
// over a moment so the jump stays readable. Touchpads keep their own
// pixel deltas, a little amplified. Declare it inside the view it
// scrolls; it only takes the wheel while there's something to scroll,
// so an inner list that fits lets the wheel through to the panel.
WheelHandler {
    id: root

    required property Flickable flickable
    // Per wheel notch, in pixels at 1x.
    property real notch: 140

    readonly property Theme theme: Theme {}

    target: null
    enabled: flickable.contentHeight > flickable.height + 1

    property real goal: 0

    onWheel: event => {
        const range = Math.max(0, root.flickable.contentHeight - root.flickable.height);
        const from = scroll.running ? root.goal : root.flickable.contentY;
        const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.5
            : event.angleDelta.y / 120 * root.theme.px(root.notch);
        root.goal = Math.max(0, Math.min(range, from - delta));
        scroll.to = root.goal;
        scroll.restart();
    }

    property NumberAnimation scroll: NumberAnimation {
        target: root.flickable
        property: "contentY"
        duration: 140
        easing.type: Easing.OutCubic
    }
}
