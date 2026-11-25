// SPDX-License-Identifier: AGPL-3.0-or-later
// Mission Control, as on macOS: every window on the current workspace, live
// and scaled down side by side over the dimmed desktop. Click a window to
// bring it forward; click the background or press Escape to go back. Arrow
// keys and Enter work too. Opened with Super+G, a three-finger swipe up, or
// `muhos ipc call muhos missionControl`.
// Minimised windows (on special:minimized) are not shown, as on macOS.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.missionControlOpen
    function close() { MuhosCommands.missionControlOpen = false; }
    function t(key, fallback) {
        const k = "muhos.mission." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }

    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property var windows: {
        const all = (Hyprland.toplevels && Hyprland.toplevels.values) || [];
        const ws = workspace ? workspace.id : null;
        return all.filter(t => t.wayland && t.workspace && t.workspace.id === ws);
    }
    property int selected: 0

    function open(t) {
        if (!t || !t.wayland) return;
        close();
        t.wayland.activate();
        Quickshell.execDetached(["hyprctl", "dispatch",
            'hl.dsp.window.bring_to_top({ window = "address:0x' + String(t.address).replace(/^0x/, "") + '" })']);
    }

    onShownChanged: {
        if (shown) {
            selected = 0;
            Hyprland.refreshToplevels();
            keys.forceActiveFocus();
        }
    }

    screen: {
        const name = workspace && workspace.monitor ? workspace.monitor.name : "";
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
    }
    visible: shown || content.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "muhos-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.05, 0.09, 0.55)
        opacity: content.opacity
    }
    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: win.close()
        Keys.onLeftPressed: win.selected = Math.max(0, win.selected - 1)
        Keys.onRightPressed: win.selected = Math.min(win.windows.length - 1, win.selected + 1)
        Keys.onUpPressed: win.selected = Math.max(0, win.selected - layout.columns)
        Keys.onDownPressed: win.selected = Math.min(win.windows.length - 1, win.selected + layout.columns)
        Keys.onReturnPressed: win.open(win.windows[win.selected])
        Keys.onEnterPressed: win.open(win.windows[win.selected])
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: MuhosStyle.barBand + MuhosStyle.s(32)
        anchors.bottomMargin: MuhosStyle.s(110)
        anchors.leftMargin: MuhosStyle.s(48)
        anchors.rightMargin: MuhosStyle.s(48)
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 1.04
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 140; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 140; easing.type: MuhosStyle.easingEmphasis } }

        // As many columns as keep the windows large; each cell keeps its
        // window's shape.
        QtObject {
            id: layout
            readonly property int count: win.windows.length
            readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(count * (content.width / Math.max(1, content.height)) / 1.6)))
            readonly property int rows: Math.max(1, Math.ceil(count / columns))
            readonly property real gap: MuhosStyle.s(36)
            readonly property real cellW: (content.width - gap * (columns - 1)) / columns
            readonly property real cellH: (content.height - gap * (rows - 1)) / rows
        }

        Repeater {
            model: win.windows

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property int col: index % layout.columns
                readonly property int row: Math.floor(index / layout.columns)
                // Centre a short last row.
                readonly property int inRow: row === layout.rows - 1 ? layout.count - row * layout.columns : layout.columns
                readonly property real rowOffset: (layout.columns - inRow) * (layout.cellW + layout.gap) / 2
                x: rowOffset + col * (layout.cellW + layout.gap)
                y: row * (layout.cellH + layout.gap)
                width: layout.cellW
                height: layout.cellH

                readonly property var ipc: modelData.lastIpcObject || {}
                readonly property real srcW: (ipc.size && ipc.size[0]) || view.sourceSize.width || 16
                readonly property real srcH: (ipc.size && ipc.size[1]) || view.sourceSize.height || 10
                readonly property real titleH: MuhosStyle.s(30)
                readonly property real fit: Math.min((width) / srcW, (height - titleH) / srcH, 1)
                readonly property bool current: win.selected === index || hover.containsMouse

                Rectangle {
                    id: frame
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (cell.height - cell.titleH - height) / 2
                    width: cell.srcW * cell.fit
                    height: cell.srcH * cell.fit
                    radius: MuhosStyle.s(10)
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: cell.current ? MuhosStyle.s(3) : 0
                    border.color: MuhosStyle.accent
                    clip: true
                    scale: hover.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: MuhosStyle.fast } }

                    ScreencopyView {
                        id: view
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        captureSource: win.shown ? cell.modelData.wayland : null
                        live: win.shown
                    }
                }
                Text {
                    anchors.top: frame.bottom
                    anchors.topMargin: MuhosStyle.s(8)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, cell.width)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.title || (cell.ipc.class || "")
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(13)
                    font.weight: Font.Medium
                    opacity: cell.current ? 1 : 0.75
                }
                MouseArea {
                    id: hover
                    x: frame.x
                    y: frame.y
                    width: frame.width
                    height: frame.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.selected = cell.index
                    onClicked: win.open(cell.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: win.windows.length === 0
            text: win.t("none", "No open windows")
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textTitle
        }
    }
}
