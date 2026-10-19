// SPDX-License-Identifier: AGPL-3.0-or-later
// GNOME-style pill toggle for the control centre: icon, title and state line.
// An optional arrow segment opens the related settings popup.
import QtQuick
import "../"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool hasMenu: false

    signal toggled()
    signal menuRequested()

    implicitHeight: MuhosStyle.toggleHeight
    readonly property color fg: checked ? MuhosStyle.textOnAccent : MuhosStyle.text

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: root.checked
            ? (main.pressed ? Qt.darker(MuhosStyle.accent, 1.15) : main.containsMouse ? Qt.lighter(MuhosStyle.accent, 1.08) : MuhosStyle.accent)
            : (main.pressed ? MuhosStyle.chipPressed : main.containsMouse ? MuhosStyle.chipHover : MuhosStyle.chip)
        Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
    }

    MouseArea {
        id: main
        anchors.fill: parent
        anchors.rightMargin: root.hasMenu ? arrow.width : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: MuhosStyle.s(16)
        anchors.right: arrow.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: MuhosStyle.s(12)

        AdwIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: MuhosStyle.iconLarge
            color: root.fg
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - MuhosStyle.iconLarge - parent.spacing
            Text {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                color: root.fg
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.textBody
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                elide: Text.ElideRight
                color: root.fg
                opacity: 0.8
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.textSmall
            }
        }
    }

    Item {
        id: arrow
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.hasMenu ? MuhosStyle.s(40) : 0
        visible: root.hasMenu

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.5
            color: root.checked ? MuhosStyle.tint(root.fg, 0.3) : MuhosStyle.hairline
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: MuhosStyle.s(4)
            radius: height / 2
            color: arrowArea.containsMouse ? MuhosStyle.tint(root.fg, 0.14) : "transparent"
        }
        AdwIcon {
            anchors.centerIn: parent
            name: "go-next"
            color: root.fg
        }
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menuRequested()
        }
    }
}
