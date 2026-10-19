// SPDX-License-Identifier: AGPL-3.0-or-later
// Status-notifier icons (apps in the background). Left click activates,
// right click opens the app's menu through the shell's tray menu.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../"

Row {
    id: root

    property var barWindow: null
    property bool atBottom: false

    spacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        GlassButton {
            id: item
            required property var modelData
            required property int index
            padding: MuhosStyle.s(6)

            function openMenu() {
                const pt = item.mapToItem(null, item.width / 2, root.atBottom ? 0 : item.height);
                const id = (item.modelData.id !== undefined && String(item.modelData.id).length > 0) ? String(item.modelData.id) : String(item.index);
                TrayMenuController.toggle(id, root.barWindow ? root.barWindow.screen : null, pt.x, pt.y, false, root.atBottom, false);
            }

            onClicked: item.modelData.onlyMenu ? openMenu() : item.modelData.activate()
            onRightClicked: item.modelData.menu ? openMenu() : item.modelData.secondaryActivate()

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: item.modelData.icon || ""
                sourceSize: Qt.size(MuhosStyle.s(18), MuhosStyle.s(18))
                width: MuhosStyle.s(18)
                height: MuhosStyle.s(18)
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
