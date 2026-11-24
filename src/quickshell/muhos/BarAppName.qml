// SPDX-License-Identifier: AGPL-3.0-or-later
// macOS-layout app menu: the focused app's name in bold beside the logo.
// Click opens its menu (full screen, quit).
import QtQuick
import Quickshell.Wayland
import "../"

GlassButton {
    id: root

    inBar: true
    padding: MuhosStyle.s(9)
    radius: MuhosStyle.s(7)

    property var barScreen: null
    readonly property color ink: MuhosStyle.barText(lightWallpaper)

    active: MuhosCommands.barMenu === "app"
    onClicked: MuhosCommands.toggleBarMenu("app", barScreen, mapToItem(null, 0, 0).x)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: MuhosState.appName(ToplevelManager.activeToplevel)
        color: root.ink
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.s(13)
        font.weight: Font.Bold
        elide: Text.ElideRight
        width: Math.min(implicitWidth, MuhosStyle.s(220))
    }
}
