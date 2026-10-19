// SPDX-License-Identifier: AGPL-3.0-or-later
// A row in an expanded control-centre menu (e.g. Suspend, Restart).
import QtQuick
import "../"

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    signal clicked()

    implicitHeight: MuhosStyle.s(40)
    radius: MuhosStyle.s(12)
    color: area.pressed ? MuhosStyle.chipPressed : area.containsMouse ? MuhosStyle.chipHover : "transparent"
    Behavior on color { ColorAnimation { duration: MuhosStyle.fast } }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: MuhosStyle.s(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: MuhosStyle.s(12)
        AdwIcon { anchors.verticalCenter: parent.verticalCenter; name: root.icon }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: MuhosStyle.text
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textBody
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
