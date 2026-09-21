import QtQuick
import Quickshell

// Opened by clicking the clock. No month navigation and no year
// progress bar (unlike the inspiration screenshot) — this always shows
// the current month with today highlighted. Not built on PopupPanel:
// no tabs.
BarPopup {
    id: root

    requestedWidth: theme.gridUnit * 84
    requestedHeight: theme.gridUnit * 96

    Theme { id: theme }

    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var weekdayNames: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    property date today: new Date()

    // 42 cells (6 rows x 7 cols) covering the visible month, padded with
    // dimmed days from the adjacent months.
    readonly property var cells: {
        const year = root.today.getFullYear();
        const month = root.today.getMonth();
        const startOffset = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();

        const list = [];
        for (let i = 0; i < 42; i++) {
            const dayNum = i - startOffset + 1;
            let day, currentMonth;
            if (dayNum < 1) {
                day = daysInPrevMonth + dayNum;
                currentMonth = false;
            } else if (dayNum > daysInMonth) {
                day = dayNum - daysInMonth;
                currentMonth = false;
            } else {
                day = dayNum;
                currentMonth = true;
            }
            list.push({ day: day, currentMonth: currentMonth, isToday: currentMonth && day === root.today.getDate() });
        }
        return list;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    Column {
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 4
        spacing: theme.gridUnit * 3

        Text {
            text: root.monthNames[root.today.getMonth()] + " " + root.today.getDate()
            color: theme.colorFg
            font.family: theme.fontFamily
            font.pixelSize: theme.px(23)
            font.letterSpacing: theme.letterSpacing
            font.bold: true
        }

        Text {
            text: String(root.today.getFullYear())
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.letterSpacing: theme.letterSpacing
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.colorDim
        }

        Grid {
            id: grid
            width: parent.width
            columns: 7
            rowSpacing: theme.gridUnit * 3
            columnSpacing: 0

            // Day cells are square unless the panel got clamped to the
            // screen height; then they shrink to keep all 6 rows visible.
            readonly property real availableHeight: parent.height - y
            readonly property real cellSize: Math.min(width / 7, (availableHeight - rowSpacing * 6) / 7)

            Repeater {
                model: root.weekdayNames

                Text {
                    required property string modelData
                    width: grid.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(10)
                    font.letterSpacing: theme.letterSpacing
                }
            }

            Repeater {
                model: root.cells

                Rectangle {
                    required property var modelData
                    width: grid.width / 7
                    height: grid.cellSize
                    color: "transparent"
                    border.width: modelData.isToday ? 1 : 0
                    border.color: theme.colorFocus

                    Text {
                        anchors.centerIn: parent
                        text: String(modelData.day)
                        color: !modelData.currentMonth
                            ? theme.colorDim
                            : (modelData.isToday ? theme.colorFocus : theme.colorFg)
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                        font.letterSpacing: theme.letterSpacing
                    }
                }
            }
        }
    }
}
