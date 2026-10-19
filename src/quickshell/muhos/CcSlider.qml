// SPDX-License-Identifier: AGPL-3.0-or-later
// Control-centre slider: icon button (e.g. mute) plus a rounded track.
import QtQuick
import "../"

Item {
    id: root

    property string icon: ""
    property real value: 0          // 0..1
    signal moved(real value)
    signal iconClicked()

    implicitHeight: MuhosStyle.s(36)

    GlassButton {
        id: iconButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        padding: 0
        implicitWidth: MuhosStyle.s(36)
        implicitHeight: MuhosStyle.s(36)
        onClicked: root.iconClicked()
        AdwIcon { name: root.icon; size: MuhosStyle.iconLarge }
    }

    Item {
        id: track
        anchors.left: iconButton.right
        anchors.leftMargin: MuhosStyle.s(10)
        anchors.right: parent.right
        anchors.rightMargin: MuhosStyle.s(6)
        anchors.verticalCenter: parent.verticalCenter
        height: MuhosStyle.s(24)

        readonly property real shown: drag.pressed ? drag.localValue : root.value

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: MuhosStyle.s(6)
            radius: height / 2
            color: MuhosStyle.hairline
            Rectangle {
                height: parent.height
                radius: height / 2
                width: Math.max(height, parent.width * track.shown)
                color: MuhosStyle.accent
            }
        }
        Rectangle {
            id: knob
            width: MuhosStyle.s(20)
            height: width
            radius: width / 2
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.12)
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) * track.shown
            scale: drag.pressed ? 1.12 : (drag.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: MuhosStyle.fast } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -MuhosStyle.s(6)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real localValue: 0
            function update(x) {
                localValue = Math.max(0, Math.min(1, (x - MuhosStyle.s(6)) / track.width));
                root.moved(localValue);
            }
            onPressed: m => update(m.x)
            onPositionChanged: m => { if (pressed) update(m.x); }
            onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
}
