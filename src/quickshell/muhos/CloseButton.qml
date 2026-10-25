// SPDX-License-Identifier: AGPL-3.0-or-later
// macOS-style close button (the red "traffic light"), with an × on hover.
// Used where a shell window has no other visible way out.
import QtQuick
import "../"

Rectangle {
    id: root

    property int size: MuhosStyle.s(14)
    signal clicked()

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    radius: size / 2
    color: area.pressed ? "#bf4943" : "#ff5f57"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.18)

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.size / 14
        text: "×"
        color: "#4d0000"
        font.pixelSize: root.size * 0.95
        font.bold: true
        opacity: area.containsMouse ? 0.9 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -root.size / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t("guide.close", "Close")
}
