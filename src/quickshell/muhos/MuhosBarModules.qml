// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS: the bar modules chosen in Settings > Bar (bar.modules.left, center or
// right), shown in the MuhOS menu bar with upstream's own BarModule faces.
// Modules the menu bar already shows its own way are left out (menu,
// workspaces, tray, keyboard, Wi-Fi, Bluetooth, volume, battery, clock), so
// nothing appears twice. Before this, every module placed in Settings was
// saved and then ignored, because the menu bar replaces upstream's bar.
import QtQuick
import Quickshell
import "../"
import "../bar"

Row {
    id: root

    // "left", "center" or "right"
    property string side: "center"
    property var barScreen: null
    property bool lightWallpaper: false

    readonly property var builtIn: ["left", "workspaces", "tray", "kb", "wifi", "bt", "vol", "bat", "timedate"]
    readonly property var moduleIds: {
        const modules = (MuhosStyle.barSettings.modules || {})[side] || [];
        const out = [];
        const add = id => {
            const n = BarModuleRegistry.normalizeId(id);
            if (n && builtIn.indexOf(n) === -1 && out.indexOf(n) === -1) out.push(n);
        };
        for (const entry of modules) {
            if (Array.isArray(entry)) entry.forEach(add);
            else add(entry);
        }
        return out;
    }

    spacing: MuhosStyle.s(4)
    height: MuhosStyle.barBand
    visible: moduleIds.length > 0

    // What upstream's modules expect from the bar window they sit in.
    QtObject {
        id: host
        readonly property var screen: root.barScreen
        readonly property string barPosition: MuhosStyle.barSettings.position === "bottom" ? "bottom" : "top"
        readonly property real barHeight: MuhosStyle.barBand
        readonly property real baseOffsetX: 0
        readonly property real baseOffsetY: 0
        readonly property bool distinctPills: false
        readonly property bool positionChanging: false
        readonly property bool isRevealed: true
        readonly property bool visible: true
        property bool isStartupReady: true
        property bool startupCascadeFinished: true
        property bool fastPollerLoaded: false
        property bool isDataReady: true
        function s(v) { return MuhosStyle.s(v); }
        function cs(v) { return MuhosStyle.s(v); }
    }

    Repeater {
        model: root.moduleIds

        Item {
            id: slot
            required property string modelData
            // effectiveVisible, not visible: a child reports itself visible
            // only while its parent is, which would keep both hidden.
            width: mod.effectiveVisible ? mod.width : 0
            height: root.height
            visible: mod.effectiveVisible

            BarModule {
                id: mod
                moduleId: slot.modelData
                barWindow: host
                // Drawn straight on the transparent menu bar, without upstream's pill.
                isSolid: true
                distinctPills: false
                targetX: 0
            }
        }
    }
}
