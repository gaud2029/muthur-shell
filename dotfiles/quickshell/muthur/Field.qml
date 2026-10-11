import QtQuick

// A bordered one-line input with a dim placeholder.
Rectangle {
    id: root

    property alias input: input_
    property string placeholder: ""

    height: theme.buttonSize
    color: "transparent"
    border.color: input_.activeFocus ? theme.colorFocus : theme.colorDim
    border.width: 1

    Theme { id: theme }

    TextInput {
        id: input_
        anchors.fill: parent
        anchors.leftMargin: theme.gridUnit * 2
        anchors.rightMargin: theme.gridUnit * 2
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: theme.colorFg
        selectionColor: theme.colorDim
        selectedTextColor: theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: theme.px(12)

        Text {
            anchors.fill: parent
            visible: !input_.text && !input_.activeFocus
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: theme.colorDim
            font.family: theme.fontFamily
            font.pixelSize: theme.px(12)
            font.letterSpacing: theme.letterSpacing
        }
    }
}
