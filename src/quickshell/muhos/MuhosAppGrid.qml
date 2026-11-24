// SPDX-License-Identifier: AGPL-3.0-or-later
// App grid, like the Apps view (Launchpad) on macOS: every installed app as a
// large icon over the blurred desktop, with a search field. Type to filter,
// arrows and Enter to open, Escape to clear the search and then close.
// Opened from the "Apps" entry in the dock or `muhos ipc call muhos appGrid`.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.appGridOpen
    property string query: ""

    function close() { MuhosCommands.appGridOpen = false; }
    function t(key, fallback) {
        const k = "muhos.apps." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }
    function iconFor(e) { return MuhosState.appIcon(e); }
    function launch(e) {
        if (!e) return;
        e.execute();
        Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", e.name]);
        close();
    }

    readonly property var allApps: {
        const all = (DesktopEntries.applications && DesktopEntries.applications.values) || [];
        // Not itself, as on macOS.
        return all.filter(e => !e.noDisplay && e.name && e.id !== "muhos-apps")
                  .sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var apps: {
        const q = query.trim().toLowerCase();
        if (!q) return allApps;
        return allApps.filter(e => [e.name, e.genericName, (e.keywords || []).join(" ")]
                                   .join(" ").toLowerCase().indexOf(q) !== -1);
    }

    // An app opened from the dock while the grid is open: get out of its way.
    // (The grid holds keyboard focus, so the new window does not become the
    // active one until the grid closes; watch for new windows instead.)
    property int windowCount: ToplevelManager.toplevels.values.length
    property int _lastCount: 0
    onWindowCountChanged: {
        const opened = windowCount > _lastCount;
        _lastCount = windowCount;
        if (!shown || !opened) return;
        close();
        const all = ToplevelManager.toplevels.values;
        const newest = all[all.length - 1];
        if (newest) Qt.callLater(() => newest.activate());   // it opened behind the grid's focus
    }

    onShownChanged: {
        if (shown) {
            query = "";
            search.text = "";
            grid.currentIndex = 0;
            Qt.callLater(() => grid.contentY = grid.originY);   // once laid out
            search.forceActiveFocus();
        }
    }

    screen: MuhosCommands.appGridScreen || Quickshell.screens[0]
    visible: shown || content.opacity > 0
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
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    // Dims and blurs (through the compositor) everything behind. Dark in light
    // mode too, as on macOS, so the white labels read on any wallpaper.
    readonly property color ink: "#ffffff"
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.05, 0.09, MuhosStyle.dark ? 0.55 : 0.45)
        opacity: content.opacity
    }
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 1.06
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 160; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 160; easing.type: MuhosStyle.easingEmphasis } }

        // Search
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: MuhosStyle.barBand + MuhosStyle.s(28)
            width: Math.min(MuhosStyle.s(320), parent.width - MuhosStyle.s(48))
            height: MuhosStyle.s(38)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)

            MouseArea { anchors.fill: parent; onClicked: search.forceActiveFocus() }
            AdwIcon {
                id: searchIcon
                x: MuhosStyle.s(14)
                anchors.verticalCenter: parent.verticalCenter
                name: "system-search"
                color: Qt.rgba(1, 1, 1, 0.75)
            }
            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: MuhosStyle.s(10)
                anchors.right: parent.right
                anchors.rightMargin: MuhosStyle.s(14)
                anchors.verticalCenter: parent.verticalCenter
                color: win.ink
                selectionColor: MuhosStyle.accent
                selectedTextColor: MuhosStyle.textOnAccent
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(15)
                clip: true
                onTextChanged: { win.query = text; grid.currentIndex = 0; }
                Keys.onEscapePressed: { if (text) text = ""; else win.close(); }
                Keys.onReturnPressed: win.launch(win.apps[grid.currentIndex])
                Keys.onEnterPressed: win.launch(win.apps[grid.currentIndex])
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: win.t("search", "Search")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font: search.font
                }
            }
        }

        // Grid
        GridView {
            id: grid
            readonly property int columns: Math.max(3, Math.min(7, Math.floor((parent.width - MuhosStyle.s(96)) / MuhosStyle.s(140))))
            width: columns * cellWidth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: searchBox.bottom
            anchors.topMargin: MuhosStyle.s(36)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: MuhosStyle.s(110)    // clear of the dock
            cellWidth: MuhosStyle.s(140)
            cellHeight: MuhosStyle.s(132)
            clip: true
            // Scrolls only when the apps do not fit; otherwise a click between
            // icons reaches the backdrop and closes the grid, as on macOS.
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: win.apps
            keyNavigationEnabled: false
            highlightFollowsCurrentItem: false

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool current: GridView.isCurrentItem && win.query !== ""
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.centerIn: icon
                    width: icon.width + MuhosStyle.s(20)
                    height: width
                    radius: MuhosStyle.s(22)
                    color: Qt.rgba(1, 1, 1, 0.18)
                    visible: cell.current
                }
                Image {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: MuhosStyle.s(10)
                    width: MuhosStyle.s(72)
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: win.iconFor(cell.modelData)
                    asynchronous: true
                    smooth: true
                    scale: area.pressed ? 0.9 : area.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: MuhosStyle.fast; easing.type: MuhosStyle.easing } }
                }
                Text {
                    anchors.top: icon.bottom
                    anchors.topMargin: MuhosStyle.s(8)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - MuhosStyle.s(12)
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData.name
                    color: win.ink
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(13)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.margins: MuhosStyle.s(6)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.launch(cell.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: grid
            visible: win.apps.length === 0
            text: win.t("none", "No apps match “%1”").arg(win.query)
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textTitle
        }
    }
}
