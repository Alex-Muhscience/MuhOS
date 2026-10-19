pragma Singleton
// SPDX-License-Identifier: AGPL-3.0-or-later
// System state shared by the MuhOS bar and control centre: network, sound,
// battery, Bluetooth, power mode, night light, do-not-disturb, dark style,
// brightness. Reads come from Quickshell services and the shell's existing
// singletons; writes reuse the same mechanisms as upstream's system panel.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import "../"

QtObject {
    id: root

    // Network
    readonly property var devices: Networking.devices ? (Networking.devices.values || []) : []
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredConnected: !!(wiredDevice && wiredDevice.connected)
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiNetwork: (wifiDevice && wifiDevice.networks)
        ? ((wifiDevice.networks.values || []).find(n => n.connected) ?? null) : null
    readonly property string wifiName: wifiNetwork ? (wifiNetwork.name || "") : ""
    readonly property real wifiSignal: wifiNetwork
        ? (wifiNetwork.signalStrength <= 1 ? wifiNetwork.signalStrength * 100 : wifiNetwork.signalStrength) : 0
    readonly property string netIcon: {
        if (wiredConnected) return "network-wired";
        if (!wifiDevice) return "network-offline";
        if (!wifiEnabled) return "network-wireless-disabled";
        if (!wifiNetwork) return "network-wireless-offline";
        return wifiSignal >= 75 ? "network-wireless-signal-excellent"
             : wifiSignal >= 50 ? "network-wireless-signal-good"
             : wifiSignal >= 25 ? "network-wireless-signal-ok" : "network-wireless-signal-weak";
    }
    function setWifi(on) { Networking.wifiEnabled = on; }

    // Sound
    readonly property var sinkAudio: Audio.defaultSink ? Audio.defaultSink.audio : null
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool muted: !sinkAudio || sinkAudio.muted
    readonly property string volIcon: (muted || volume <= 0.001) ? "audio-volume-muted"
                                    : volume < 0.34 ? "audio-volume-low"
                                    : volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
    function setVolume(v) {
        if (!sinkAudio) return;
        sinkAudio.muted = false;
        sinkAudio.volume = Math.max(0, Math.min(1, v));
    }

    // Battery (laptops only)
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!(battery && battery.ready && battery.isLaptopBattery)
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging
                                                 || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batteryLow: hasBattery && !charging && batteryPercent < 15
    readonly property string batIcon: {
        if (!hasBattery) return "ac-adapter";
        if (battery.state === UPowerDeviceState.FullyCharged) return "battery-level-100-charged";
        const level = Math.min(100, Math.round(batteryPercent / 10) * 10);
        return "battery-level-" + level + (charging ? "-charging" : "");
    }
    readonly property string batteryDetail: {
        if (!hasBattery) return "";
        const secs = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!secs || secs <= 0) return batteryPercent + "%";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return batteryPercent + "% · " + (h > 0 ? h + " h " : "") + m + " min" + (charging ? " to full" : " left");
    }

    // Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: !!(btAdapter && btAdapter.enabled)
    readonly property string btDevice: {
        if (!btAdapter || !btAdapter.devices) return "";
        const d = (btAdapter.devices.values || []).find(x => x.connected);
        return d ? (d.name || d.deviceName || "") : "";
    }
    function setBluetooth(on) { if (btAdapter) btAdapter.enabled = on; }

    // Power mode (power-profiles-daemon)
    readonly property bool hasPowerProfiles: PowerProfiles.hasPerformanceProfile
    readonly property bool performance: PowerProfiles.profile === PowerProfile.Performance
    function setPerformance(on) { PowerProfiles.profile = on ? PowerProfile.Performance : PowerProfile.Balanced; }

    // Night light (upstream BlueLight, all monitors)
    property bool nightLight: BlueLight.isAnyEnabled()
    readonly property Connections _blueLightWatch: Connections {
        target: BlueLight
        ignoreUnknownSignals: true
        function onSettingsChanged() { root.nightLight = BlueLight.isAnyEnabled(); }
    }
    function setNightLight(on) {
        const screens = Quickshell.screens || [];
        if (screens.length === 0) BlueLight.setEnabled("", on);
        for (let i = 0; i < screens.length; i++) BlueLight.setEnabled(screens[i].name, on);
        nightLight = on;
    }

    // Do not disturb (same setting upstream's notification centre uses)
    readonly property bool dnd: Config.getSetting("notifications", {}).dnd === true
    function setDnd(on) { Config.setSetting("notifications.dnd", on); }

    // Dark style: the theme mode, regenerated from the current wallpaper.
    readonly property bool darkStyle: (Config.getSetting("theme", {}).mode || "dark") === "dark"
    function setDarkStyle(on) {
        const mode = on ? "dark" : "light";
        Config.setSetting("theme.mode", mode);
        let wall = Matugen.lastWallpaper;
        if (!wall) {
            const paths = Wallpaper.screenWallpaperPaths || {};
            for (const k in paths) { if (paths[k]) { wall = paths[k]; break; } }
        }
        if (wall) Matugen.generate(wall, mode);
    }

    // Brightness (upstream scripts/brightness.sh; hidden without a backlight or DDC)
    property bool hasBrightness: false
    property real brightness: 0
    readonly property string _briScript: Caching.serpantinumDir + "/scripts/brightness.sh"
    readonly property Process _briBackend: Process {
        running: Caching.serpantinumDir !== ""
        command: ["bash", root._briScript, "backend"]
        stdout: StdioCollector {
            onStreamFinished: {
                // A backend is not enough (ddcutil may be installed without a DDC display):
                // show brightness only once a value has actually been read.
                const b = this.text.trim();
                if (b !== "none" && b !== "") root._briGet.running = true;
            }
        }
    }
    readonly property Process _briGet: Process {
        command: ["bash", root._briScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim());
                if (!isNaN(v)) {
                    root.brightness = v / 100;
                    root.hasBrightness = true;
                }
            }
        }
    }
    function refreshBrightness() { if (hasBrightness && !_briGet.running) _briGet.running = true; }
    readonly property Timer _briThrottle: Timer {
        interval: 60
        onTriggered: Quickshell.execDetached(["bash", root._briScript, "set", String(Math.round(root.brightness * 100))])
    }
    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));
        _briThrottle.restart();
    }

    // Session actions (upstream scripts)
    function run(action) {
        const dir = Caching.serpantinumDir + "/scripts/";
        const path = action === "lock" ? dir + "lock.sh"
                   : action === "screenshot" ? dir + "screenshot.sh"
                   : dir + "system/" + (action === "suspend" ? "suspend" : action === "logout" ? "exit" : action) + ".sh";
        Quickshell.execDetached(["bash", path]);
    }
}
