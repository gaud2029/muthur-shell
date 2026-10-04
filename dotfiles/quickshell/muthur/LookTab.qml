import QtQuick
import Qt.labs.folderlistmodel
import Quickshell

Item {
    id: root

    Theme { id: theme }

    // Wallpapers drawn since the last look show up on the next open.
    onVisibleChanged: if (visible) ThemeStore.scanThemedWallpapers()

    component SectionHeader: Text {
        color: theme.colorFg
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSize
        font.letterSpacing: theme.letterSpacing
    }

    // One preset: its first four colors on its own background, its name,
    // and its four wallpapers (wallpapers/themed.py) on the right. A
    // thumbnail picks the preset with that wallpaper; the rest of the row
    // picks it with the first one, or alone if none were drawn.
    component PresetRow: Rectangle {
        id: swatchRow
        required property var modelData
        readonly property bool active: ThemeStore.preset === modelData.key
        readonly property bool hasWallpapers: ThemeStore.themedKeys.includes(modelData.key)

        width: parent ? parent.width : 0
        height: theme.gridUnit * 10
        color: "transparent"
        border.color: active ? theme.colorFocus : theme.colorDim
        border.width: 1

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ThemeStore.pickTheme(swatchRow.modelData.key, swatchRow.hasWallpapers ? 0 : -1)
        }

        Row {
            anchors.left: parent.left
            anchors.right: thumbs.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: theme.gridUnit * 2
            anchors.rightMargin: theme.gridUnit * 2
            spacing: theme.gridUnit * 2

            // The preset's first four ANSI slots, on its own background.
            Rectangle {
                id: swatchBox
                width: swatches.width + theme.gridUnit * 2
                height: theme.tile
                color: swatchRow.modelData.special.background
                border.color: theme.colorDim
                border.width: 1

                Row {
                    id: swatches
                    anchors.centerIn: parent
                    spacing: 1

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index
                            width: theme.gridUnit * 2
                            height: theme.gridUnit * 2
                            color: swatchRow.modelData.colors["color" + index]
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - swatchBox.width - parent.spacing
                elide: Text.ElideRight
                text: (swatchRow.active ? "> " : "  ") + swatchRow.modelData.name
                color: swatchRow.active ? theme.colorFocus : theme.colorFg
                font.family: theme.fontFamily
                font.pixelSize: theme.px(12)
                font.letterSpacing: theme.letterSpacing
            }
        }

        Row {
            id: thumbs
            anchors.right: parent.right
            anchors.rightMargin: theme.gridUnit
            anchors.verticalCenter: parent.verticalCenter
            spacing: theme.gridUnit

            Repeater {
                model: 4

                Rectangle {
                    id: thumb
                    required property int index
                    readonly property string path: ThemeStore.themedWallpaper(swatchRow.modelData.key, index)
                    readonly property bool current: ThemeStore.wallpaper === path

                    visible: swatchRow.hasWallpapers
                    width: theme.gridUnit * 8
                    height: theme.gridUnit * 8
                    color: "transparent"
                    border.width: current ? 2 : 1
                    border.color: current ? theme.colorFocus
                                : thumbMouse.containsMouse ? theme.colorFg : theme.colorDim

                    WallpaperLayout {
                        anchors.fill: parent
                        anchors.margins: thumb.border.width
                        design: thumb.index
                        background: swatchRow.modelData.special.background
                        line: swatchRow.modelData.colors.color8
                        accent: swatchRow.modelData.special.cursor
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ThemeStore.pickTheme(swatchRow.modelData.key, thumb.index)
                    }
                }
            }
        }
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: theme.gridUnit * 3
        anchors.rightMargin: theme.gridUnit * 5
        contentHeight: column.height
        clip: true

        FastScroll { flickable: scroller }

        Column {
            id: column
            width: parent.width
            spacing: theme.gridUnit * 2

            SectionHeader { text: "THEME" }

            // Dark presets first, then the light ones, each under a label.
            Repeater {
                model: [
                    { label: "DARK", presets: ThemeStore.darkPresets },
                    { label: "LIGHT", presets: ThemeStore.lightPresets }
                ]

                Column {
                    id: group
                    required property var modelData
                    visible: modelData.presets.length > 0
                    width: parent ? parent.width : 0
                    spacing: theme.gridUnit * 2

                    Text {
                        text: group.modelData.label
                        color: theme.colorDim
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(11)
                        font.letterSpacing: theme.letterSpacing
                    }

                    Repeater {
                        model: group.modelData.presets

                        PresetRow {}
                    }
                }
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "WALLPAPERS PATH" }

            // A directory of images; each shows as a thumbnail below and
            // becomes the wallpaper + WALLPAPER preset when clicked.
            Row {
                width: parent.width
                spacing: theme.gridUnit * 2

                Rectangle {
                    width: parent.width - applyButton.width - theme.gridUnit * 2
                    height: theme.buttonSize
                    color: "transparent"
                    border.color: pathInput.activeFocus ? theme.colorFocus : theme.colorDim
                    border.width: 1

                    TextInput {
                        id: pathInput
                        anchors.fill: parent
                        anchors.margins: theme.gridUnit * 2
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        text: ThemeStore.wallpapersPath === ThemeStore.defaultWallpapersPath ? "" : ThemeStore.wallpapersPath
                        color: theme.colorFg
                        selectionColor: theme.colorDim
                        selectedTextColor: theme.colorFg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.px(12)
                        onAccepted: ThemeStore.setWallpapersPath(text)

                        Text {
                            anchors.fill: parent
                            visible: !pathInput.text && !pathInput.activeFocus
                            verticalAlignment: Text.AlignVCenter
                            text: ThemeStore.defaultWallpapersPath.replace(Quickshell.env("HOME"), "~")
                            color: theme.colorDim
                            font.family: theme.fontFamily
                            font.pixelSize: theme.px(12)
                        }
                    }
                }

                TerminalButton {
                    id: applyButton
                    label: "APPLY"
                    onClicked: ThemeStore.setWallpapersPath(pathInput.text)
                }
            }

            FolderListModel {
                id: wallpapers
                folder: "file://" + ThemeStore.wallpapersPath
                showDirs: false
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG"]
                sortField: FolderListModel.Name
            }

            Grid {
                id: thumbs
                readonly property int thumbWidth: theme.gridUnit * 24
                readonly property int thumbHeight: theme.gridUnit * 14

                width: parent.width
                columns: Math.max(1, Math.floor((width + spacing) / (thumbWidth + spacing)))
                spacing: theme.gridUnit * 2

                Repeater {
                    model: wallpapers

                    Rectangle {
                        id: thumb
                        required property int index
                        required property string fileName
                        required property string filePath

                        readonly property bool selected: filePath === ThemeStore.wallpaper

                        visible: index < ThemeStore.maxWallpapers
                        width: thumbs.thumbWidth
                        height: thumbs.thumbHeight
                        color: theme.colorBg
                        border.width: selected ? 2 : 1
                        border.color: ThemeStore.wallpaperBusy && thumbArea.containsMouse ? theme.colorYellow
                                    : selected ? theme.colorFocus
                                    : thumbArea.containsMouse ? theme.colorFg : theme.colorDim

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: thumb.visible ? "file://" + thumb.filePath : ""
                            asynchronous: true
                            cache: true
                            // Decode at thumbnail size: wallpapers are big.
                            sourceSize: Qt.size(thumbs.thumbWidth, thumbs.thumbHeight)
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            height: caption.implicitHeight + theme.gridUnit
                            visible: thumbArea.containsMouse || thumb.selected
                            color: theme.colorBg

                            Text {
                                id: caption
                                anchors.fill: parent
                                anchors.leftMargin: theme.gridUnit
                                anchors.rightMargin: theme.gridUnit
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideMiddle
                                text: thumb.fileName
                                color: thumb.selected ? theme.colorFocus : theme.colorFg
                                font.family: theme.fontFamily
                                font.pixelSize: theme.px(9)
                            }
                        }

                        MouseArea {
                            id: thumbArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeStore.setWallpaper(thumb.filePath)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: theme.gridUnit * 2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - clearButton.width - theme.gridUnit * 2
                    elide: Text.ElideMiddle
                    text: wallpapers.count === 0
                        ? "[ NO IMAGES IN " + ThemeStore.wallpapersPath.replace(Quickshell.env("HOME"), "~") + " ]"
                        : wallpapers.count > ThemeStore.maxWallpapers
                            ? "SHOWING " + ThemeStore.maxWallpapers + " OF " + wallpapers.count
                            : wallpapers.count + (wallpapers.count === 1 ? " WALLPAPER" : " WALLPAPERS")
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    id: clearButton
                    label: "CLEAR"
                    visible: ThemeStore.wallpaper.length > 0
                    onClicked: ThemeStore.clearWallpaper()
                }
            }

            // Whether picking an image also recolors everything after it.
            Row {
                spacing: theme.gridUnit * 2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ON PICK"
                    color: theme.colorDim
                    font.family: theme.fontFamily
                    font.pixelSize: theme.px(11)
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    label: "USE ITS COLORS"
                    selected: ThemeStore.themeFromWallpaper
                    onClicked: ThemeStore.setThemeFromWallpaper(true)
                }

                TerminalButton {
                    label: "KEEP THEME"
                    selected: !ThemeStore.themeFromWallpaper
                    onClicked: ThemeStore.setThemeFromWallpaper(false)
                }
            }

            Text {
                visible: ThemeStore.wallpaperError.length > 0
                text: ThemeStore.wallpaperError
                color: theme.colorFocus
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "BAR POSITION" }

            Row {
                spacing: theme.gridUnit * 2

                Repeater {
                    model: ThemeStore.barPositions

                    TerminalButton {
                        required property string modelData
                        label: modelData.toUpperCase()
                        selected: ThemeStore.barPosition === modelData
                        onClicked: ThemeStore.setBarPosition(modelData)
                    }
                }
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "SIZE" }

            Row {
                spacing: theme.gridUnit * 2

                Repeater {
                    model: ThemeStore.maxSizeMultiplier

                    TerminalButton {
                        required property int index
                        readonly property int factor: index + 1
                        label: factor + "X"
                        selected: ThemeStore.sizeMultiplier === factor
                        onClicked: ThemeStore.setSizeMultiplier(factor)
                    }
                }
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "GRID UNIT" }

            Row {
                spacing: theme.gridUnit * 2

                TerminalButton {
                    label: "-"
                    onClicked: ThemeStore.setGridUnit(ThemeStore.gridUnit - 1)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: theme.gridUnit * 10
                    horizontalAlignment: Text.AlignHCenter
                    text: ThemeStore.gridUnit + " PX"
                    color: theme.colorFocus
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSize
                    font.letterSpacing: theme.letterSpacing
                }

                TerminalButton {
                    label: "+"
                    onClicked: ThemeStore.setGridUnit(ThemeStore.gridUnit + 1)
                }
            }

            // Size and grid unit multiply into one effective unit, capped at
            // ThemeStore.maxEffectiveUnit — the readout makes a refused
            // click understandable.
            Text {
                text: "UNIT " + theme.gridUnit + "PX   BAR " + theme.barThickness + "PX   FONT " + theme.fontSize + "PX   (MAX UNIT " + ThemeStore.maxEffectiveUnit + "PX)"
                color: theme.colorDim
                font.family: theme.fontFamily
                font.pixelSize: theme.px(11)
                font.letterSpacing: theme.letterSpacing
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "FONT" }

            // Each option is drawn in its own face. The list is measured
            // on every open (ThemeStore.scanFonts), so fonts installed
            // since show up without a restart.
            Dropdown {
                width: parent.width
                current: ThemeStore.fontFamily
                options: ThemeStore.monoFontFamilies
                fontFor: family => family
                onOpenChanged: if (open) ThemeStore.scanFonts()
                onPicked: family => ThemeStore.setFontFamily(family)
            }

            Item { width: 1; height: theme.gridUnit }

            SectionHeader { text: "TERMINAL" }

            VolumeSlider {
                width: parent.width
                label: "OPACITY"
                value: ThemeStore.terminalOpacity / 100
                onMoved: v => ThemeStore.setTerminalOpacity(v * 100)
            }
        }
    }

    TerminalScrollBar { flickable: scroller }
}
