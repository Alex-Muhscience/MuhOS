// SPDX-License-Identifier: AGPL-3.0-or-later
// Workspace dots (GNOME-style): the focused one stretches into a pill, ones
// with windows are brighter than empty ones. Click to switch, scroll to step.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"

Item {
    id: root

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property int count: {
        let n = Math.max(5, focusedId);
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > n && ws.id <= 10) n = ws.id;
        return Math.min(10, n);
    }
    readonly property int dot: MuhosStyle.s(8)
    property int wheelAccumulator: 0
    property bool lightWallpaper: false
    readonly property color ink: MuhosStyle.barText(lightWallpaper)

    function occupied(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        return !!(ws && ws.toplevels && ws.toplevels.values.length > 0);
    }
    function focusWorkspace(id) {
        if (id >= 1 && id <= 10 && id !== focusedId)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    implicitWidth: pills.implicitWidth + MuhosStyle.s(8)
    implicitHeight: MuhosStyle.barItem

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: MuhosStyle.s(6)

        Repeater {
            model: root.count

            Item {
                id: slot
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isFocused: wsId === root.focusedId

                width: isFocused ? MuhosStyle.s(26) : root.dot
                height: MuhosStyle.barItem
                Behavior on width { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easingEmphasis } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: root.dot
                    radius: height / 2
                    color: slot.isFocused ? root.ink
                         : MuhosStyle.tint(root.ink, hit.containsMouse ? 0.8 : (root.occupied(slot.wsId) ? 0.62 : 0.28))
                    Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    anchors.leftMargin: -pills.spacing / 2
                    anchors.rightMargin: -pills.spacing / 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(slot.wsId)
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            root.wheelAccumulator += e.angleDelta.y;
            if (Math.abs(root.wheelAccumulator) < 120) return;
            const step = root.wheelAccumulator > 0 ? -1 : 1;
            root.wheelAccumulator = 0;
            root.focusWorkspace(Math.max(1, Math.min(root.count, root.focusedId + step)));
        }
    }
}
