// SPDX-License-Identifier: AGPL-3.0-or-later
// Network, volume and battery in one menu-bar button (GNOME's system menu).
// Click opens the control centre; scrolling changes the volume.
import QtQuick
import "../"

GlassButton {
    id: root

    inBar: true
    padding: MuhosStyle.s(11)
    spacing: MuhosStyle.s(9)

    property var barScreen: null
    readonly property color ink: MuhosStyle.barText(lightWallpaper)

    active: MuhosCommands.controlCentreOpen
    onClicked: MuhosCommands.toggleControlCentre(barScreen)
    onWheel: delta => {
        const a = MuhosState.sinkAudio;
        if (!a) return;
        a.muted = false;
        a.volume = Math.max(0, Math.min(1, MuhosState.volume + (delta > 0 ? 0.05 : -0.05)));
    }

    AdwIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: MuhosState.netIcon
        color: root.ink
    }
    AdwIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: MuhosState.volIcon
        color: root.ink
    }
    AdwIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: MuhosState.hasBattery
        name: MuhosState.batIcon
        color: MuhosState.batteryLow ? MuhosStyle.danger : root.ink
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: MuhosState.hasBattery
        text: MuhosState.batteryPercent + "%"
        color: root.ink
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.s(13)
        font.weight: Font.Bold
    }
}
