// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS bar ("clean glass"): a floating translucent strip that Hyprland blurs
// behind (layer rule for "muhos-*"). Left: logo and workspaces. Centre: clock.
// Right: tray, now playing, status pill, power. Replaces upstream's Bar unless
// bar.design is "classic"; see Shell.qml.
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

        readonly property bool atBottom: Config.getSetting("bar", {}).position === "bottom"
        property bool redacting: false
        readonly property bool hideInRedactor: Config.getSetting("bar", {}).hideBarInRedactor !== false
        readonly property bool hidden: redacting && hideInRedactor
        property string activeWidget: ""

        visible: Config.dataReady && !hidden
        color: "transparent"
        anchors {
            top: !atBottom
            bottom: atBottom
            left: true
            right: true
        }
        implicitHeight: MuhosStyle.barBand
        exclusiveZone: hidden ? 0 : MuhosStyle.barBand
        WlrLayershell.namespace: "muhos-bar"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region { item: glass }

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

        Rectangle {
            id: glass

            x: MuhosStyle.s(12)
            y: win.atBottom ? 0 : MuhosStyle.barGap
            width: win.width - x * 2
            height: MuhosStyle.barHeight
            radius: MuhosStyle.barRadius
            color: MuhosStyle.glass
            border.width: 1
            border.color: MuhosStyle.hairline

            // Entrance: fade in and settle from a few pixels away.
            opacity: 0
            transform: Translate { id: drift; y: win.atBottom ? MuhosStyle.s(6) : -MuhosStyle.s(6) }
            Component.onCompleted: enter.start()
            ParallelAnimation {
                id: enter
                NumberAnimation { target: glass; property: "opacity"; to: 1; duration: MuhosStyle.slow; easing.type: MuhosStyle.easing }
                NumberAnimation { target: drift; property: "y"; to: 0; duration: MuhosStyle.slow; easing.type: MuhosStyle.easingEmphasis }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: MuhosStyle.s(5)
                anchors.verticalCenter: parent.verticalCenter
                spacing: MuhosStyle.s(6)

                GlassButton {
                    id: logoButton
                    padding: 0
                    implicitWidth: MuhosStyle.control
                    active: LauncherController.isVisible === true
                    onClicked: MuhosCommands.toggle("launcher")
                    onRightClicked: MuhosCommands.toggle("guide")

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: MuhosStyle.s(24)
                        height: width
                        radius: MuhosStyle.s(8)
                        color: MuhosStyle.accent

                        Image {
                            id: mark
                            anchors.centerIn: parent
                            width: MuhosStyle.s(16)
                            height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: Caching.serpantinumDir ? "file://" + Caching.serpantinumDir + "/assets/logo.svg" : ""
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: mark
                            source: mark
                            colorization: 1.0
                            colorizationColor: MuhosStyle.onAccent
                        }
                    }
                }

                BarWorkspaces {}
            }

            BarClock {
                anchors.centerIn: parent
                active: win.activeWidget === "calendar"
                onClicked: MuhosCommands.toggle("calendar")
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: MuhosStyle.s(5)
                anchors.verticalCenter: parent.verticalCenter
                spacing: MuhosStyle.s(4)

                BarTray {
                    anchors.verticalCenter: parent.verticalCenter
                    barWindow: win
                    atBottom: win.atBottom
                }
                BarMedia {
                    anchors.verticalCenter: parent.verticalCenter
                    active: win.activeWidget === "music"
                }
                BarStatus {
                    anchors.verticalCenter: parent.verticalCenter
                    activeWidget: win.activeWidget
                }
                GlassButton {
                    anchors.verticalCenter: parent.verticalCenter
                    padding: 0
                    implicitWidth: MuhosStyle.control
                    active: win.activeWidget === "system"
                    onClicked: MuhosCommands.toggle("system")
                    Symbol {
                        text: "power_settings_new"
                        color: MuhosStyle.danger
                    }
                }
            }
        }
    }
}
