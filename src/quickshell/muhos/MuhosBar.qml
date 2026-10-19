// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS menu bar ("Hybrid"): transparent over the wallpaper like macOS, laid
// out like GNOME. Left: apps button and workspace dots. Centre: the clock
// island (expands into a player). Right: tray and the status button that
// opens the control centre. Replaces upstream's Bar while MuhosStyle.barActive.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool atBottom: MuhosStyle.barSettings.position === "bottom"
        property bool redacting: false
        readonly property bool hideInRedactor: MuhosStyle.barSettings.hideBarInRedactor !== false
        readonly property bool hidden: redacting && hideInRedactor
        property string activeWidget: ""

        // Bar text follows the wallpaper's brightness under the bar. Measured once
        // per wallpaper change with ImageMagick (still images only).
        readonly property string wallPath: (win.screen && Wallpaper.screenWallpaperPaths[win.screen.name]) || Matugen.lastWallpaper || ""
        property bool lightWallpaper: false
        onWallPathChanged: probeWallpaper()
        Component.onCompleted: probeWallpaper()
        function probeWallpaper() {
            if (!wallPath || /\.(mp4|mkv|mov|webm|gif)$/i.test(wallPath)) return;
            wallProbe.running = false;
            wallProbe.command = ["magick", wallPath.replace(/^file:\/\//, "") + "[0]", "-gravity", atBottom ? "South" : "North",
                "-crop", "100%x6%+0+0", "+repage", "-resize", "1x1!", "-colorspace", "Gray", "-format", "%[fx:mean]", "info:"];
            wallProbe.running = true;
        }
        Process {
            id: wallProbe
            stdout: StdioCollector {
                onStreamFinished: {
                    const v = parseFloat(this.text.trim());
                    if (!isNaN(v)) win.lightWallpaper = v > 0.6;
                }
            }
        }

        visible: Config.dataReady && !hidden
        color: "transparent"
        anchors {
            top: !atBottom
            bottom: atBottom
            left: true
            right: true
        }
        // Tall enough for the expanded island; only the bar band is reserved.
        implicitHeight: MuhosStyle.barBand + MuhosStyle.islandOpenHeight
        exclusiveZone: hidden ? 0 : MuhosStyle.barBand
        WlrLayershell.namespace: "muhos-bar"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region {
            Region { item: leftGroup }
            Region { item: island }
            Region { item: rightGroup }
        }

        // Same IPC surface as upstream's bar, which other parts of the shell call.
        IpcHandler {
            target: "topbar"
            function setRedactMode(active: string): void { win.redacting = (active === "true" || active === "1"); }
            function forceReload(): void { Quickshell.reload(true); }
            function queueReload(): void { Quickshell.reload(true); }
            function toggleUpdate(): void {}
        }

        // Which popup is open, so its button stays highlighted.
        FileView {
            path: Caching.runDir ? Caching.runDir + "/current_widget" : ""
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                let w = "";
                try {
                    const p = JSON.parse(text());
                    if (!p.screen || p.screen === (win.screen ? win.screen.name : "")) w = p.widget || "";
                } catch (e) {}
                win.activeWidget = (w === "hidden") ? "" : w;
            }
        }

        Item {
            id: band
            width: parent.width
            height: MuhosStyle.barBand
            y: win.atBottom ? parent.height - height : 0

            // Faint shade so text stays legible on bright wallpapers.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: win.atBottom ? 1 : 0; color: MuhosStyle.barShade(win.lightWallpaper) }
                    GradientStop { position: win.atBottom ? 0 : 1; color: "transparent" }
                }
            }

            Row {
                id: leftGroup
                anchors.left: parent.left
                anchors.leftMargin: MuhosStyle.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: MuhosStyle.s(2)

                GlassButton {
                    inBar: true
                    lightWallpaper: win.lightWallpaper
                    padding: MuhosStyle.s(8)
                    active: LauncherController.isVisible === true
                    onClicked: MuhosCommands.toggle("launcher")
                    onRightClicked: MuhosCommands.toggle("guide")

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: MuhosStyle.s(19)
                        height: width
                        radius: MuhosStyle.s(6)
                        color: MuhosStyle.accent

                        Image {
                            id: mark
                            anchors.centerIn: parent
                            width: MuhosStyle.s(13)
                            height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: Caching.serpantinumDir ? "file://" + Caching.serpantinumDir + "/assets/logo.svg" : ""
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: mark
                            source: mark
                            colorization: 1.0
                            colorizationColor: ThemeBackend.crust
                        }
                    }
                }
                BarWorkspaces { lightWallpaper: win.lightWallpaper }
            }

            Row {
                id: rightGroup
                anchors.right: parent.right
                anchors.rightMargin: MuhosStyle.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: MuhosStyle.s(2)

                BarTray {
                    anchors.verticalCenter: parent.verticalCenter
                    barWindow: win
                    atBottom: win.atBottom
                    lightWallpaper: win.lightWallpaper
                }
                BarStatus {
                    anchors.verticalCenter: parent.verticalCenter
                    barScreen: win.screen
                    lightWallpaper: win.lightWallpaper
                }
            }
        }

        BarIsland {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.atBottom ? parent.height - height - MuhosStyle.s(4) : MuhosStyle.s(4)
            onOpenCalendar: MuhosCommands.toggle("calendar")

            // Entrance: settle in from above.
            opacity: 0
            Component.onCompleted: enter.start()
            NumberAnimation { id: enter; target: island; property: "opacity"; to: 1; duration: MuhosStyle.slow; easing.type: MuhosStyle.easing }
        }
    }
}
