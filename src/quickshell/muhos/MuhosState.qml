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

    // Equaliser (media/equalizer.sh, PipeWire filter-chain). The script keeps
    // the state in a file; local changes show at once and the file catches up.
    readonly property var eqFreqs: [32, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var eqPresets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    readonly property var eqPresetGains: ({
        "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6], "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2], "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3], "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })
    property var eq: ({ b1: 0, b2: 0, b3: 0, b4: 0, b5: 0, b6: 0, b7: 0, b8: 0, b9: 0, b10: 0,
                        preset: "Flat", balance: 0, mono: false, swap: false, dynamics: "off",
                        enabled: true, active: false, dynamicsAvailable: false })
    property real _eqLocalAt: 0
    function eqGain(i) { return Number(eq["b" + (i + 1)] || 0); }
    function _eqLocal(changes) {
        eq = Object.assign({}, eq, changes);
        _eqLocalAt = Date.now();
    }
    function eqRun(args) {
        Quickshell.execDetached(["bash", Caching.qsDir + "/media/equalizer.sh"].concat(args));
    }
    function eqSetBand(i, gain) {
        const g = Math.round(Math.max(-12, Math.min(12, gain)) * 2) / 2;
        const c = { preset: "Custom" };
        c["b" + (i + 1)] = g;
        _eqLocal(c);
        eqRun(["set_band_live", String(i + 1), String(g)]);
    }
    function eqSetPreset(name) {
        const c = { preset: name };
        (eqPresetGains[name] || []).forEach((g, i) => c["b" + (i + 1)] = g);
        _eqLocal(c);
        eqRun(["preset", name]);
    }
    function eqSetEnabled(on) { _eqLocal({ enabled: on }); eqRun(["enable", on ? "true" : "false"]); }
    function eqSetBalance(b) {
        const v = Math.round(Math.max(-1, Math.min(1, b)) * 20) / 20;
        _eqLocal({ balance: v });
        eqRun(["set_balance", String(v)]);
    }
    function eqSetFlag(name, on) { const c = {}; c[name] = on; _eqLocal(c); eqRun(["set_" + name, on ? "true" : "false"]); }
    function eqSetDynamics(mode) { _eqLocal({ dynamics: mode }); eqRun(["set_dynamics", mode]); }
    function eqReset() {
        _eqLocal({ balance: 0, mono: false, swap: false, dynamics: "off" });
        eqRun(["reset_audio"]);
        eqSetPreset("Flat");
    }
    readonly property FileView _eqFile: FileView {
        path: Caching.stateDir ? Caching.stateDir + "/music/eq_state.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: eqReread.restart()
        // On a fresh install the file appears only after equalizer.sh first
        // runs (at shell start); keep looking until it does.
        onLoadFailed: eqReread.restart()
        onLoaded: {
            // Our own writes arrive here too; let them settle first.
            if (Date.now() - root._eqLocalAt < 1200) { eqReread.restart(); return; }
            try { root.eq = Object.assign({}, root.eq, JSON.parse(text())); } catch (e) {}
        }
    }
    readonly property Timer _eqReread: Timer {
        id: eqReread
        interval: 1300
        onTriggered: root._eqFile.reload()
    }

    // Wallpaper from any picture or folder on any disk, through the desktop's
    // file chooser (muhos/pick_file.py). A picture is applied straight away,
    // the same way the wallpaper picker does, and its folder becomes the
    // picker's folder; a folder only becomes the picker's folder.
    property string _wpPickKind: ""
    function pickWallpaper(kind) {
        if (_wpPick.running) return;
        // The picker and Settings sit above normal windows; get them out of the
        // file chooser's way.
        MuhosCommands.commandRequested("close", "", "");
        _wpPickKind = kind === "folder" ? "folder" : "picture";
        const start = Config.getSetting("wallpaperDir", "") || (Quickshell.env("HOME") + "/Pictures");
        _wpPick.command = ["python3", "-I", Caching.qsDir + "/muhos/pick_file.py", _wpPickKind, start];
        _wpPick.running = true;
    }
    readonly property Process _wpPick: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (!path) return;
                if (root._wpPickKind === "folder") {
                    Config.setSetting("wallpaperDir", path);
                    return;
                }
                Wallpaper.setWallpaper("all", path, "fade");
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") Matugen.generate(path);
                Config.setSetting("wallpaperDir", path.substring(0, path.lastIndexOf("/")));
            }
        }
    }

    // Minimize and restore (Hyprland config: window.minimize moves a window to
    // the hidden workspace "special:minimized").
    function minimizeWindow(toplevel) { if (toplevel) toplevel.minimized = true; }
    function restoreWindow(address) {
        if (!address) return;
        const a = String(address).startsWith("0x") ? String(address) : "0x" + address;
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = "e+0", window = "address:' + a + '" })']);
    }

    // An app's icon: a theme icon name or a file path (some apps, e.g. ones in
    // /opt, give a path), falling back to a generic app icon.
    function appIcon(entry) {
        const icon = entry ? String(entry.icon || "") : "";
        if (icon.startsWith("/")) return "file://" + icon;
        return (icon && Quickshell.iconPath(icon, true))
            || Quickshell.iconPath("application-x-executable", true)
            || "file:///usr/share/icons/Adwaita/scalable/mimetypes/application-x-executable.svg";
    }

    // Focused app's display name for the macOS-layout menu bar ("MuhOS" on
    // the bare desktop, as macOS shows Finder there).
    function appName(toplevel) {
        if (!toplevel) return "MuhOS";
        // Re-evaluate once the app list has loaded (it is empty at startup).
        const apps = DesktopEntries.applications.values;
        const id = toplevel.appId || "";
        const entry = id ? DesktopEntries.heuristicLookup(id) : null;
        if (entry && entry.name) return entry.name;
        if (id) {
            const last = id.split(".").pop();
            return last.charAt(0).toUpperCase() + last.slice(1);
        }
        return toplevel.title || "MuhOS";
    }

    // Dark style: the theme mode, regenerated from the current wallpaper.
    readonly property bool darkStyle: (Config.getSetting("theme", {}).mode || "dark") === "dark"
    function setDarkStyle(on) {
        const mode = on ? "dark" : "light";
        Config.setSetting("theme.mode", mode);
        // Apps follow too, but only through MuhOS's own dconf profile (set by
        // muhos-session), never the user's GNOME settings, and only while no
        // GTK_THEME is forced: WhiteSur breaks under the dark colour scheme, so
        // a session started light switches its apps at the next login.
        if (Quickshell.env("DCONF_PROFILE") === "muhos" && !Quickshell.env("GTK_THEME"))
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", on ? "prefer-dark" : "default"]);
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

    // Notifications (data lives in upstream's NotificationManager)
    // Ticks every 30 s so relative times ("5 min ago") stay current.
    property int clockTick: 0
    readonly property Timer _tick: Timer { interval: 30000; running: true; repeat: true; onTriggered: root.clockTick++ }

    function relativeTime(ts) {
        clockTick;
        const mins = Math.floor((Date.now() - ts) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + " min";
        const d = new Date(ts), today = new Date();
        const time = Qt.formatTime(d, Locale.ShortFormat);
        return d.toDateString() === today.toDateString() ? time : Qt.formatDate(d, "d MMM") + " " + time;
    }

    // An icon name ("firefox"), file path or URL, as an image source.
    function iconSource(icon) {
        const s = icon ? String(icon) : "";
        if (s === "") return "";
        if (s.startsWith("/")) return "file://" + s;
        if (s.indexOf("://") > 0 || s.startsWith("image:")) return s;
        // Glyphs and other non-names are not icons.
        if (!/^[A-Za-z0-9._+-]+$/.test(s)) return "";
        return Quickshell.iconPath(s, true) || "";
    }

    // Notifications carry their icon and any picture in a few shapes:
    // "image://icon/<name>" (an icon), "image://icon//<path>" (a file, i.e. a
    // picture such as a screenshot), plain names, paths or URLs.
    function isPictureSource(src) {
        const s = src ? String(src) : "";
        return s.startsWith("image://icon//") || s.startsWith("/") || s.startsWith("file://") || s.startsWith("http");
    }
    // Best icon: the first candidate that is an icon and resolves; else an
    // icon named after the app.
    function notifIcon(candidates, appName) {
        for (const c of candidates) {
            if (!c || isPictureSource(c)) continue;
            const src = iconSource(c);
            if (src) return src;
        }
        return appName ? iconSource(String(appName).toLowerCase().replace(/\s+/g, "-")) : "";
    }
    // A picture sent with the notification (a photo, a screenshot), not an icon.
    function notifPicture(image) {
        const s = image ? String(image) : "";
        if (s.startsWith("image://icon//")) return "file://" + s.slice("image://icon/".length);
        return isPictureSource(s) ? iconSource(s) : "";
    }

    function notifActions(uid) {
        const n = NotificationManager.liveNotifs[uid];
        return (n && n.actions) ? n.actions : [];
    }
    // Run the notification's default action (what clicking it means).
    function notifActivate(uid) {
        const acts = notifActions(uid);
        const a = acts.find(x => x.identifier === "default") || acts[0];
        if (a && typeof a.invoke === "function") a.invoke();
    }
    function notifAction(uid, identifier) {
        const a = notifActions(uid).find(x => x.identifier === identifier);
        if (a && typeof a.invoke === "function") a.invoke();
    }
    // Bumped when items are marked read, since ListModel.get() is not observed.
    property int notifReadRevision: 0
    function markAllNotificationsRead() {
        const h = NotificationManager.globalNotificationHistory;
        for (let i = 0; i < h.count; i++) if (!h.get(i).read) h.setProperty(i, "read", true);
        notifReadRevision++;
    }
    readonly property int unreadNotifications: {
        notifReadRevision;
        const h = NotificationManager.globalNotificationHistory;
        let n = 0;
        for (let i = 0; i < h.count; i++) if (!h.get(i).read) n++;
        return n;
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
