pragma Singleton
import QtQuick
import Quickshell
import "../../"

// GNOME-style window previews for the dock: left-clicking an app with
// several windows raises a strip of live previews above its icon; clicking
// one focuses and raises that window. DockWindowPreviews.qml renders it.
Item {
    id: controller

    property bool isVisible: false
    property var screen: null
    property real targetX: 0
    property real targetY: 0
    property string dockPosition: "bottom"
    property string desktopId: ""
    property real buttonSize: 0
    property var windows: []

    function isSameApp(idA, idB) {
        if (!idA || !idB) return false;
        if (idA === idB) return true;
        if (typeof AppMatcher !== "undefined") {
            return AppMatcher.canonicalId(idA) === AppMatcher.canonicalId(idB);
        }
        let a = String(idA).toLowerCase().replace(/\.desktop$/, "");
        let b = String(idB).toLowerCase().replace(/\.desktop$/, "");
        return a === b;
    }

    function show(scr, posX, posY, dockPos, dId, winList, btnSize) {
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.dockPosition = dockPos || "bottom";
        controller.desktopId = dId || "";
        controller.windows = winList || [];
        controller.buttonSize = btnSize || 0;
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
        controller.windows = [];
    }

    function toggle(scr, posX, posY, dockPos, dId, winList, btnSize) {
        if (controller.isVisible && isSameApp(controller.desktopId, dId)) {
            controller.hide();
        } else {
            controller.show(scr, posX, posY, dockPos, dId, winList, btnSize);
        }
    }
}
