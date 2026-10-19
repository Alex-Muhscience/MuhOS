// SPDX-License-Identifier: AGPL-3.0-or-later
// Network, volume and battery in one pill. Each icon opens its own popup;
// scrolling anywhere on the pill changes the volume.
import QtQuick
import Quickshell.Networking
import Quickshell.Services.UPower
import "../"

Rectangle {
    id: root

    property string activeWidget: ""

    implicitWidth: row.implicitWidth
    implicitHeight: MuhosStyle.control
    radius: MuhosStyle.controlRadius
    color: MuhosStyle.fill

    // Network
    readonly property var devices: Networking.devices ? (Networking.devices.values || []) : []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNet: {
        const dev = devices.find(d => d.type === DeviceType.Wifi);
        if (!dev || !dev.networks) return null;
        return (dev.networks.values || []).find(n => n.connected) ?? null;
    }
    readonly property string netIcon: {
        if (wired) return "lan";
        if (!Networking.wifiEnabled) return "wifi_off";
        if (!wifiNet) return "signal_wifi_statusbar_not_connected";
        const sig = wifiNet.signalStrength <= 1 ? wifiNet.signalStrength * 100 : wifiNet.signalStrength;
        return sig >= 66 ? "wifi" : sig >= 33 ? "wifi_2_bar" : "wifi_1_bar";
    }

    // Volume
    readonly property var sinkAudio: Audio.defaultSink ? Audio.defaultSink.audio : null
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property string volIcon: (!sinkAudio || sinkAudio.muted || volume <= 0.001) ? "volume_off"
                                    : volume < 0.5 ? "volume_down" : "volume_up"

    // Battery (laptops only)
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat && bat.ready && bat.isLaptopBattery
    readonly property bool charging: hasBattery && (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged)
    readonly property string batIcon: {
        if (!hasBattery) return "";
        if (charging) return "battery_charging_full";
        const bars = Math.round(bat.percentage * 6);
        return bars >= 6 ? "battery_full" : ("battery_" + Math.max(0, bars) + "_bar");
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        GlassButton {
            padding: MuhosStyle.s(7)
            active: root.activeWidget === "network"
            onClicked: MuhosCommands.toggle("network")
            Symbol { text: root.netIcon }
        }
        GlassButton {
            padding: MuhosStyle.s(7)
            active: root.activeWidget === "volume"
            onClicked: MuhosCommands.toggle("volume")
            onRightClicked: if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
            Symbol { text: root.volIcon }
        }
        GlassButton {
            visible: root.hasBattery
            padding: MuhosStyle.s(7)
            spacing: MuhosStyle.s(2)
            active: root.activeWidget === "system"
            onClicked: MuhosCommands.toggle("system")
            Symbol {
                text: root.batIcon
                color: (!root.charging && root.bat.percentage < 0.15) ? MuhosStyle.danger : MuhosStyle.text
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            if (!root.sinkAudio) return;
            root.sinkAudio.muted = false;
            root.sinkAudio.volume = Math.max(0, Math.min(1, root.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)));
        }
    }
}
