// SPDX-License-Identifier: AGPL-3.0-or-later
// Menu-bar menus in the macOS layout: the logo menu (About, System Settings,
// sleep/restart/shut down, lock, log out) and the focused app's menu (full
// screen, quit). A glass list under the item that opened it; clicking outside
// or Escape closes it. MuhosCommands holds which menu is open and where.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.barMenu !== ""
    // Last menu shown, kept while the closing fade runs.
    property string kind: ""
    onShownChanged: if (shown) kind = MuhosCommands.barMenu
    Connections {
        target: MuhosCommands
        function onBarMenuChanged() { if (MuhosCommands.barMenu !== "") win.kind = MuhosCommands.barMenu; }
    }

    function close() { MuhosCommands.barMenu = ""; }
    function t(key, fallback) {
        const k = "muhos.menu." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string appName: MuhosState.appName(toplevel)

    readonly property var items: kind === "logo" ? [
        { text: t("about", "About MuhOS"), run: () => MuhosCommands.toggle("guide") },
        { sep: true },
        { text: t("settings", "System Settings…"), run: () => MuhosCommands.toggle("guide") },
        { text: t("search", "Search…"), shortcut: "⌘D", run: () => MuhosCommands.toggle("launcher") },
        { sep: true },
        { text: t("sleep", "Sleep"), run: () => MuhosState.run("suspend") },
        { text: t("restart", "Restart"), run: () => MuhosState.run("reboot") },
        { text: t("shut_down", "Shut Down"), run: () => MuhosState.run("poweroff") },
        { sep: true },
        { text: t("lock", "Lock Screen"), shortcut: "⌘L", run: () => MuhosState.run("lock") },
        { text: t("log_out", "Log Out"), run: () => MuhosState.run("logout") }
    ] : kind === "app" ? [
        { text: (toplevel && toplevel.fullscreen) ? t("exit_full_screen", "Exit Full Screen") : t("full_screen", "Enter Full Screen"),
          enabled: !!toplevel, run: () => { if (win.toplevel) win.toplevel.fullscreen = !win.toplevel.fullscreen; } },
        { sep: true },
        { text: t("quit", "Quit %1").arg(appName), shortcut: "⌘Q", enabled: !!toplevel, run: () => { if (win.toplevel) win.toplevel.close(); } }
    ] : []

    screen: MuhosCommands.barMenuScreen || Quickshell.screens[0]
    visible: shown || menu.opacity > 0
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
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    Shortcut {
        sequence: "Escape"
        enabled: win.shown
        onActivated: win.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.close()
    }

    Item {
        id: menu

        readonly property int pad: MuhosStyle.s(5)
        x: Math.max(MuhosStyle.s(6), Math.min(MuhosCommands.barMenuX, win.width - width - MuhosStyle.s(6)))
        y: MuhosStyle.barBand + MuhosStyle.s(2)
        width: Math.max(MuhosStyle.s(220), list.implicitWidth + pad * 2)
        height: list.implicitHeight + pad * 2

        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.fast : 120; easing.type: MuhosStyle.easing } }

        MouseArea { anchors.fill: parent }

        GlassPanel {
            anchors.fill: parent
            radius: MuhosStyle.s(12)
            elevation: MuhosStyle.s(8)
        }

        Column {
            id: list
            x: menu.pad
            y: menu.pad
            width: menu.width - menu.pad * 2

            Repeater {
                model: win.items

                Item {
                    id: row
                    required property var modelData
                    readonly property bool sep: modelData.sep === true
                    readonly property bool enabled: !sep && modelData.enabled !== false
                    width: list.width
                    height: sep ? MuhosStyle.s(11) : MuhosStyle.s(26)
                    implicitWidth: sep ? 0 : label.implicitWidth + keys.implicitWidth + MuhosStyle.s(48)

                    Rectangle {
                        visible: row.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: MuhosStyle.s(10)
                        width: parent.width - MuhosStyle.s(20)
                        height: 1
                        color: MuhosStyle.hairline
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: !row.sep
                        radius: MuhosStyle.s(7)
                        color: area.containsMouse && row.enabled ? MuhosStyle.accent : "transparent"
                    }
                    Text {
                        id: label
                        visible: !row.sep
                        anchors.left: parent.left
                        anchors.leftMargin: MuhosStyle.s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text || ""
                        color: !row.enabled ? MuhosStyle.textDim : area.containsMouse ? MuhosStyle.textOnAccent : MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(13)
                    }
                    Text {
                        id: keys
                        visible: !row.sep && !!row.modelData.shortcut
                        anchors.right: parent.right
                        anchors.rightMargin: MuhosStyle.s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.shortcut || ""
                        color: area.containsMouse && row.enabled ? MuhosStyle.textOnAccent : MuhosStyle.textDim
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(13)
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        enabled: !row.sep
                        hoverEnabled: true
                        onClicked: {
                            if (!row.enabled) return;
                            const run = row.modelData.run;
                            win.close();
                            run();
                        }
                    }
                }
            }
        }
    }
}
