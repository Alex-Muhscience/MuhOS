// SPDX-License-Identifier: AGPL-3.0-or-later
// Frosted glass surface, as on macOS: a translucent tint over the compositor's
// blur (layer rules in packaging/fedora/hypr/muhos.lua), a faint sheen from the
// top, a light rim with a brighter top edge, and a soft drop shadow. The shadow
// stays below the blur rules' ignore_alpha (0.3), so the compositor does not
// blur around the panel.
import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: root

    property real radius: MuhosStyle.panelRadius
    property color tint: MuhosStyle.panel
    property bool shadow: true
    property real elevation: MuhosStyle.s(8)     // shadow offset; blur grows with it

    RectangularShadow {
        anchors.fill: body
        visible: root.shadow
        radius: root.radius
        offset.y: root.elevation
        blur: root.elevation * 3.5
        spread: 0
        color: Qt.rgba(0, 0, 0, MuhosStyle.dark ? 0.26 : 0.16)
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        clip: true

        // Light falls from above: a faint sheen over the top of the glass.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(parent.height, MuhosStyle.s(90))
            radius: root.radius
            visible: !MuhosStyle.solid
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, MuhosStyle.dark ? 0.06 : 0.22) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    // Rim: a hairline all round, brighter along the top edge.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: MuhosStyle.panelBorder
    }
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - root.radius * 1.4)
        height: 1
        visible: !MuhosStyle.solid
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, MuhosStyle.dark ? 0.32 : 0.9) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
