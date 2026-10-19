// SPDX-License-Identifier: AGPL-3.0-or-later
// An Adwaita symbolic icon ("network-wireless-signal-excellent"), looked up in
// the icon theme and drawn in any colour. Symbolic icons ship dark; the effect
// lifts them to white and then tints them.
import QtQuick
import QtQuick.Effects
import Quickshell
import "../"

Item {
    id: root

    property string name: ""
    property color color: MuhosStyle.text
    property int size: MuhosStyle.icon

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Quickshell.iconPath(root.name + "-symbolic", true) : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        visible: false
    }
    MultiEffect {
        anchors.fill: img
        source: img
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
        Behavior on colorizationColor { ColorAnimation { duration: MuhosStyle.normal } }
    }
}
