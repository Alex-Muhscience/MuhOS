//@ pragma NativeTextRendering
import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false
    readonly property bool muhosBar: MuhosStyle.barActive
    // The control centre is created on first use and kept, so it can animate out.
    property bool controlCentreUsed: false
    property bool notificationCentreUsed: false
    property bool equalizerUsed: false
    property bool appGridUsed: false
    Connections {
        target: MuhosCommands
        function onControlCentreOpenChanged() { if (MuhosCommands.controlCentreOpen) controlCentreUsed = true; }
        function onNotificationCentreOpenChanged() { if (MuhosCommands.notificationCentreOpen) notificationCentreUsed = true; }
        function onEqualizerOpenChanged() { if (MuhosCommands.equalizerOpen) equalizerUsed = true; }
        function onAppGridOpenChanged() { if (MuhosCommands.appGridOpen) appGridUsed = true; }
    }

    // MuhOS: bring back the equaliser (PipeWire filter-chain) saved last time;
    // it does nothing when the equaliser is off or flat.
    Process {
        running: Caching.qsDir !== ""
        command: ["bash", Caching.qsDir + "/media/equalizer.sh", "restore"]
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }
    }

    Main {}
    Loader {
        active: muhosBar
        sourceComponent: MuhosBar {}
    }
    LazyLoader {
        active: muhosBar && controlCentreUsed
        ControlCentre {}
    }
    LazyLoader {
        active: muhosBar && MuhosStyle.macLayout
        MacMenu {}
    }
    LazyLoader {
        active: muhosBar && equalizerUsed
        MuhosEqualizer {}
    }
    LazyLoader {
        active: appGridUsed
        MuhosAppGrid {}
    }
    Loader {
        active: !muhosBar
        sourceComponent: Bar {}
    }
    Lock {}
    WidgetRedactor {}

    Launcher {}
    LazyLoader {
        active: MuhosStyle.designActive
        MuhosLauncher {}
    }
    LazyLoader {
        active: MuhosStyle.designActive
        MuhosBanners {}
    }
    LazyLoader {
        active: MuhosStyle.designActive
        MuhosOsd {}
    }
    LazyLoader {
        active: MuhosStyle.designActive && notificationCentreUsed
        NotificationCentre {}
    }
    Clipboard {}    

    Polkit {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "serpantinum";
        Qt.application.domain = "serpantinum.org";
        Qt.application.name = "serpantinum";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
    }
}
