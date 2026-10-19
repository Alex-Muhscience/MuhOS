// SPDX-License-Identifier: AGPL-3.0-or-later
// Now-playing pill. Appears only while a player is active; opens the music
// popup, middle-click and scroll are left to the popup itself.
import QtQuick
import "../"

GlassButton {
    id: root

    readonly property bool shown: MprisController.hasActivePlayer && MprisController.trackTitle !== ""

    filledAtRest: true
    visible: opacity > 0
    opacity: shown ? 1 : 0
    implicitWidth: shown ? Math.min(MuhosStyle.s(240), contentWidth) : 0
    clip: true
    readonly property real contentWidth: icon.implicitWidth + title.implicitWidth + spacing + padding * 2

    Behavior on opacity { NumberAnimation { duration: MuhosStyle.normal } }
    Behavior on implicitWidth { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easingEmphasis } }

    onClicked: MuhosCommands.toggle("music")

    Symbol {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        text: MprisController.isPlaying ? "music_note" : "pause"
        size: MuhosStyle.s(17)
        color: MuhosStyle.accent
    }
    Text {
        id: title
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, MuhosStyle.s(240) - icon.implicitWidth - root.spacing - root.padding * 2)
        text: MprisController.trackTitle
        elide: Text.ElideRight
        color: MuhosStyle.text
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.textBody
    }
}
