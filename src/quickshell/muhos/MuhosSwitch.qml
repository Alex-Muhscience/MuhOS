// SPDX-License-Identifier: AGPL-3.0-or-later
// A small on/off switch in the MuhOS style.
import QtQuick
import "../"

Rectangle {
    id: sw
    property bool checked: false
    signal toggled()
    width: MuhosStyle.s(42)
    height: MuhosStyle.s(24)
    radius: height / 2
    color: checked ? MuhosStyle.accent : MuhosStyle.chipPressed
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
    Rectangle {
        width: parent.height - MuhosStyle.s(6)
        height: width
        radius: width / 2
        y: MuhosStyle.s(3)
        x: sw.checked ? parent.width - width - MuhosStyle.s(3) : MuhosStyle.s(3)
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easingEmphasis } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
