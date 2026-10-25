// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS control centre (GNOME's system menu, in liquid glass): battery and
// session buttons, pill toggles, volume and brightness. Opened from the
// status button in the menu bar; closes on Escape or a click outside.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.controlCentreOpen
    property bool powerMenuOpen: false

    function close() { MuhosCommands.controlCentreOpen = false; }
    // Translated when the language files have the key, English otherwise.
    function t(key, fallback) {
        const k = "muhos.cc." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }

    onShownChanged: {
        if (shown) {
            powerMenuOpen = false;
            MuhosState.refreshBrightness();
        }
    }

    screen: MuhosCommands.controlCentreScreen || Quickshell.screens[0]
    visible: shown || panel.opacity > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "muhos-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // While closing, let clicks through so the desktop responds at once.
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    Shortcut {
        sequence: "Escape"
        enabled: win.shown
        onActivated: win.close()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Item {
        id: panel

        readonly property int pad: MuhosStyle.s(14)
        anchors.top: parent.top
        anchors.topMargin: MuhosStyle.barBand + MuhosStyle.s(6)
        anchors.right: parent.right
        anchors.rightMargin: MuhosStyle.s(10)
        width: MuhosStyle.s(384)
        height: content.implicitHeight + pad * 2

        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 150; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 150; easing.type: win.shown ? MuhosStyle.easingEmphasis : MuhosStyle.easing } }
        Behavior on height { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }

        // Swallow clicks on the panel itself.
        MouseArea { anchors.fill: parent }

        GlassPanel {
            anchors.fill: parent
            elevation: MuhosStyle.s(10)
        }

        Column {
            id: content
            x: panel.pad
            y: panel.pad
            width: panel.width - panel.pad * 2
            spacing: MuhosStyle.s(14)

            // Battery and session buttons
            Item {
                width: parent.width
                height: MuhosStyle.roundButton

                GlassButton {
                    anchors.left: parent.left
                    visible: MuhosState.hasBattery
                    filledAtRest: true
                    padding: MuhosStyle.s(14)
                    onClicked: { win.close(); MuhosCommands.toggle("system"); }
                    AdwIcon { anchors.verticalCenter: parent.verticalCenter; name: MuhosState.batIcon; size: MuhosStyle.iconLarge }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: MuhosState.batteryDetail
                        color: MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textBody
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: MuhosStyle.s(8)
                    GlassButton {
                        filledAtRest: true; padding: 0
                        onClicked: { win.close(); shotDelay.start(); }
                        AdwIcon { name: "camera-photo"; size: MuhosStyle.iconLarge }
                    }
                    GlassButton {
                        filledAtRest: true; padding: 0
                        onClicked: MuhosCommands.toggle("guide")
                        AdwIcon { name: "emblem-system"; size: MuhosStyle.iconLarge }
                    }
                    GlassButton {
                        filledAtRest: true; padding: 0
                        onClicked: { win.close(); MuhosState.run("lock"); }
                        AdwIcon { name: "system-lock-screen"; size: MuhosStyle.iconLarge }
                    }
                    GlassButton {
                        filledAtRest: true; padding: 0
                        active: win.powerMenuOpen
                        onClicked: win.powerMenuOpen = !win.powerMenuOpen
                        AdwIcon { name: "system-shutdown"; size: MuhosStyle.iconLarge }
                    }
                }
            }

            // Power menu (expands in place, as in GNOME)
            Column {
                width: parent.width
                visible: win.powerMenuOpen
                spacing: MuhosStyle.s(2)
                CcMenuItem { width: parent.width; icon: "media-playback-pause"; text: win.t("suspend", "Suspend"); onClicked: { win.close(); MuhosState.run("suspend"); } }
                CcMenuItem { width: parent.width; icon: "system-reboot"; text: win.t("restart", "Restart…"); onClicked: { win.close(); MuhosState.run("reboot"); } }
                CcMenuItem { width: parent.width; icon: "system-shutdown"; text: win.t("power_off", "Power Off…"); onClicked: { win.close(); MuhosState.run("poweroff"); } }
                CcMenuItem { width: parent.width; icon: "system-log-out"; text: win.t("log_out", "Log Out…"); onClicked: { win.close(); MuhosState.run("logout"); } }
            }

            // Toggles
            Grid {
                id: toggles
                width: parent.width
                columns: 2
                columnSpacing: MuhosStyle.s(10)
                rowSpacing: MuhosStyle.s(10)
                readonly property real cell: (width - columnSpacing) / 2

                CcToggle {
                    width: toggles.cell
                    visible: MuhosState.wifiDevice !== null
                    icon: MuhosState.wifiEnabled ? "network-wireless-signal-excellent" : "network-wireless-disabled"
                    title: win.t("wifi", "Wi-Fi")
                    subtitle: !MuhosState.wifiEnabled ? win.t("off", "Off") : (MuhosState.wifiName || win.t("not_connected", "Not connected"))
                    checked: MuhosState.wifiEnabled
                    hasMenu: true
                    onToggled: MuhosState.setWifi(!MuhosState.wifiEnabled)
                    onMenuRequested: MuhosCommands.toggle("network", "wifi")
                }
                CcToggle {
                    width: toggles.cell
                    visible: MuhosState.wifiDevice === null && MuhosState.wiredDevice !== null
                    icon: "network-wired"
                    title: win.t("wired", "Wired")
                    subtitle: MuhosState.wiredConnected ? win.t("connected", "Connected") : win.t("disconnected", "Disconnected")
                    checked: MuhosState.wiredConnected
                    hasMenu: true
                    onToggled: MuhosCommands.toggle("network")
                    onMenuRequested: MuhosCommands.toggle("network")
                }
                CcToggle {
                    width: toggles.cell
                    visible: MuhosState.btAdapter !== null
                    icon: MuhosState.btEnabled ? "bluetooth-active" : "bluetooth-disabled"
                    title: win.t("bluetooth", "Bluetooth")
                    subtitle: !MuhosState.btEnabled ? win.t("off", "Off") : (MuhosState.btDevice || win.t("on", "On"))
                    checked: MuhosState.btEnabled
                    hasMenu: true
                    onToggled: MuhosState.setBluetooth(!MuhosState.btEnabled)
                    onMenuRequested: MuhosCommands.toggle("network", "bt")
                }
                CcToggle {
                    width: toggles.cell
                    visible: MuhosState.hasPowerProfiles
                    icon: MuhosState.performance ? "power-profile-performance" : "power-profile-balanced"
                    title: win.t("power_mode", "Power Mode")
                    subtitle: MuhosState.performance ? win.t("performance", "Performance") : win.t("balanced", "Balanced")
                    checked: MuhosState.performance
                    onToggled: MuhosState.setPerformance(!MuhosState.performance)
                }
                CcToggle {
                    width: toggles.cell
                    icon: "night-light"
                    title: win.t("night_light", "Night Light")
                    subtitle: MuhosState.nightLight ? win.t("on", "On") : win.t("off", "Off")
                    checked: MuhosState.nightLight
                    onToggled: MuhosState.setNightLight(!MuhosState.nightLight)
                }
                CcToggle {
                    width: toggles.cell
                    icon: "weather-clear-night"
                    title: win.t("dark_style", "Dark Style")
                    subtitle: MuhosState.darkStyle ? win.t("on", "On") : win.t("off", "Off")
                    checked: MuhosState.darkStyle
                    onToggled: MuhosState.setDarkStyle(!MuhosState.darkStyle)
                }
                CcToggle {
                    width: toggles.cell
                    icon: "notifications-disabled"
                    title: win.t("dnd", "Do Not Disturb")
                    subtitle: MuhosState.dnd ? win.t("on", "On") : win.t("off", "Off")
                    checked: MuhosState.dnd
                    onToggled: MuhosState.setDnd(!MuhosState.dnd)
                }
            }

            // Sliders
            Rectangle {
                width: parent.width
                height: sliders.implicitHeight + MuhosStyle.s(12)
                radius: MuhosStyle.s(20)
                color: MuhosStyle.chip

                Column {
                    id: sliders
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: MuhosStyle.s(4)
                    anchors.rightMargin: MuhosStyle.s(6)
                    spacing: MuhosStyle.s(2)

                    CcSlider {
                        width: parent.width
                        icon: MuhosState.volIcon
                        value: MuhosState.muted ? 0 : MuhosState.volume
                        onMoved: v => MuhosState.setVolume(v)
                        onIconClicked: if (MuhosState.sinkAudio) MuhosState.sinkAudio.muted = !MuhosState.sinkAudio.muted
                        hasMenu: true
                        onMenuRequested: MuhosCommands.toggle("volume")
                    }
                    CcSlider {
                        width: parent.width
                        visible: MuhosState.hasBrightness
                        icon: "display-brightness"
                        value: MuhosState.brightness
                        onMoved: v => MuhosState.setBrightness(v)
                    }
                }
            }
        }
    }

    // Let the panel fade out before the screenshot is taken.
    Timer {
        id: shotDelay
        interval: 250
        onTriggered: MuhosState.run("screenshot")
    }
}
