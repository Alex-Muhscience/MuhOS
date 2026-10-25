// SPDX-License-Identifier: AGPL-3.0-or-later
// On-screen indicator in glass, as on macOS: a small pill at the top right for
// volume, microphone and brightness (icon, level bar, percentage) and for caps
// lock, num lock and airplane mode (name and state). Driven by upstream's
// OsdController, which decides when to show and hides after 1.8 s; replaces
// upstream's indicator while the MuhOS design is active. Hovering keeps it
// up, and the bar can be dragged or scrolled to adjust the level.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property string kind: OsdController.kind
    readonly property var osdSettings: Config.getSetting("osd", {})
    readonly property bool isToggle: kind === "capslock" || kind === "numlock" || kind === "airplane"
    readonly property bool allowed: {
        if (kind === "capslock") return osdSettings.showCapsLock !== false;
        if (kind === "numlock") return osdSettings.showNumLock !== false;
        if (kind === "airplane") return osdSettings.showAirplane !== false;
        return true;
    }
    readonly property bool shown: OsdController.isVisible && allowed
    readonly property bool toggleOn: ["on", "true", "1"].indexOf(OsdController.stateVal) !== -1

    // While muted the bar keeps the level (greyed), as on macOS.
    readonly property real level: kind === "volume" ? OsdController.sysVolume / 100
                                : kind === "mic" ? OsdController.sysMicVolume / 100
                                : kind === "brightness" ? OsdController.briVal / 100 : 0
    readonly property bool muted: (kind === "volume" && OsdController.sysMuted) || (kind === "mic" && OsdController.sysMicMuted)

    readonly property string icon: {
        if (kind === "volume") return MuhosState.volIcon;
        if (kind === "mic") return muted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high";
        if (kind === "brightness") return "display-brightness";
        if (kind === "airplane") return "airplane-mode";
        return "input-keyboard";
    }
    function t(key, fallback) {
        const k = "muhos.osd." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }
    readonly property string label: kind === "capslock" ? t("caps_lock", "Caps Lock")
                                  : kind === "numlock" ? t("num_lock", "Num Lock")
                                  : kind === "airplane" ? t("airplane", "Airplane Mode") : ""

    function setLevel(v) {
        v = Math.max(0, Math.min(1, v));
        if (kind === "volume" && OsdController.activeSink && OsdController.activeSink.audio) {
            OsdController.activeSink.audio.muted = false;
            OsdController.activeSink.audio.volume = v;
        } else if (kind === "mic" && OsdController.activeSource && OsdController.activeSource.audio) {
            OsdController.activeSource.audio.muted = false;
            OsdController.activeSource.audio.volume = v;
        } else if (kind === "brightness") {
            OsdController.briVal = Math.round(v * 100);
            MuhosState.setBrightness(v);
        }
        OsdController.restartTimer();
    }

    screen: OsdController.screen || LauncherController.getFocusedScreen() || Quickshell.screens[0]
    visible: shown || pill.opacity > 0
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: MuhosStyle.barBand
        right: MuhosStyle.s(4)
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "muhos-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: pill.width + MuhosStyle.s(28)
    implicitHeight: pill.height + MuhosStyle.s(36)
    mask: Region { item: win.shown ? pill : null }

    Item {
        id: pill
        x: MuhosStyle.s(12)
        y: MuhosStyle.s(6)
        width: MuhosStyle.s(300)
        height: MuhosStyle.s(54)

        opacity: win.shown ? 1 : 0
        transform: Translate { y: win.shown ? 0 : -MuhosStyle.s(10); Behavior on y { NumberAnimation { duration: MuhosStyle.slow; easing.type: MuhosStyle.easingEmphasis } } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 260; easing.type: MuhosStyle.easing } }

        GlassPanel {
            anchors.fill: parent
            radius: height / 2
            elevation: MuhosStyle.s(6)
        }

        HoverHandler {
            onHoveredChanged: {
                OsdController.isHovered = hovered;
                if (hovered) OsdController.cancelHide();
                else OsdController.requestHide();
            }
        }

        AdwIcon {
            id: kindIcon
            x: MuhosStyle.s(20)
            anchors.verticalCenter: parent.verticalCenter
            name: win.icon
            size: MuhosStyle.s(20)
            color: (win.isToggle && win.toggleOn) ? MuhosStyle.accent : MuhosStyle.text
        }

        // Level: bar and percentage
        Item {
            visible: !win.isToggle
            anchors.left: kindIcon.right
            anchors.leftMargin: MuhosStyle.s(14)
            anchors.right: percent.left
            anchors.rightMargin: MuhosStyle.s(12)
            anchors.verticalCenter: parent.verticalCenter
            height: MuhosStyle.s(24)

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: MuhosStyle.s(6)
                radius: height / 2
                color: MuhosStyle.hairline
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: Math.max(win.level > 0 ? height : 0, parent.width * Math.min(1, win.level))
                    color: win.muted ? MuhosStyle.textDim : MuhosStyle.accent
                    Behavior on width { NumberAnimation { duration: MuhosStyle.fast; easing.type: MuhosStyle.easing } }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -MuhosStyle.s(8)
                cursorShape: Qt.PointingHandCursor
                function apply(x) { win.setLevel((x - MuhosStyle.s(8)) / track.width); }
                onPressed: m => apply(m.x)
                onPositionChanged: m => { if (pressed) apply(m.x); }
                onWheel: w => win.setLevel(win.level + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
        Text {
            id: percent
            visible: !win.isToggle
            anchors.right: parent.right
            anchors.rightMargin: MuhosStyle.s(20)
            anchors.verticalCenter: parent.verticalCenter
            width: MuhosStyle.s(52)
            horizontalAlignment: Text.AlignRight
            text: win.muted ? win.t("muted", "Muted") : Math.round(win.level * 100) + "%"
            color: MuhosStyle.text
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textBody
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        // State: name and on/off
        Text {
            visible: win.isToggle
            anchors.left: kindIcon.right
            anchors.leftMargin: MuhosStyle.s(14)
            anchors.verticalCenter: parent.verticalCenter
            text: win.label
            color: MuhosStyle.text
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textBody
            font.weight: Font.DemiBold
        }
        Rectangle {
            visible: win.isToggle
            anchors.right: parent.right
            anchors.rightMargin: MuhosStyle.s(14)
            anchors.verticalCenter: parent.verticalCenter
            width: stateText.implicitWidth + MuhosStyle.s(20)
            height: MuhosStyle.s(26)
            radius: height / 2
            color: win.toggleOn ? MuhosStyle.accent : MuhosStyle.chip
            Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
            Text {
                id: stateText
                anchors.centerIn: parent
                text: win.toggleOn ? win.t("on", "On") : win.t("off", "Off")
                color: win.toggleOn ? MuhosStyle.textOnAccent : MuhosStyle.text
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(13)
                font.weight: Font.Bold
            }
        }
    }
}
