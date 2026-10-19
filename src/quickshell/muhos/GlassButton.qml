// SPDX-License-Identifier: AGPL-3.0-or-later
// Rounded hover/press surface for bar and panel controls. Children go in the
// content row.
import QtQuick
import "../"

Item {
    id: root

    property bool active: false        // its popup is open
    property bool filledAtRest: false  // show the resting fill (pill style)
    property bool inBar: false         // menu-bar colours instead of panel colours
    property bool lightWallpaper: false // in the bar: dark-on-light colours
    property real radius: height / 2
    property int padding: MuhosStyle.s(10)
    property alias spacing: row.spacing
    property alias hovered: mouse.containsMouse
    default property alias content: row.data

    signal clicked()
    signal rightClicked()
    signal wheel(int delta)

    implicitHeight: inBar ? MuhosStyle.barItem : MuhosStyle.roundButton
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + padding * 2)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.inBar
             ? (root.active ? MuhosStyle.barActiveFill(root.lightWallpaper) : (mouse.containsMouse || mouse.pressed) ? MuhosStyle.barHover(root.lightWallpaper) : "transparent")
             : mouse.pressed ? MuhosStyle.chipPressed
             : (mouse.containsMouse || root.active) ? MuhosStyle.chipHover
             : root.filledAtRest ? MuhosStyle.chip : "transparent"
        Behavior on color { ColorAnimation { duration: MuhosStyle.fast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: MuhosStyle.s(8)
        scale: mouse.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: MuhosStyle.fast; easing.type: MuhosStyle.easing } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
