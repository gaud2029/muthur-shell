import QtQuick

// A Grid that lays its items out along the bar: one column on a vertical
// bar, one row on a horizontal one. Both dimensions are assigned
// imperatively rather than bound: two separate bindings re-evaluate one at
// a time, and the intermediate 1x1 state logs a "more visible items than
// rows*columns" warning on every orientation switch.
Grid {
    Theme { id: theme }

    readonly property bool vertical: theme.vertical

    function relayout() {
        if (vertical) {
            rows = -1;
            columns = 1;
        } else {
            columns = -1;
            rows = 1;
        }
        forceLayout();
    }

    onVerticalChanged: relayout()
    Component.onCompleted: relayout()
}
