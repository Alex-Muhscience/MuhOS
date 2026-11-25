// SPDX-License-Identifier: AGPL-3.0-or-later
// App grid, like the Apps view (Launchpad) on macOS: every installed app as a
// large icon over the blurred desktop, in pages (swipe, scroll or the dots),
// with a search field. Type to filter, arrows and Enter to open, Escape to
// clear the search and then close. Press and hold an icon to move it, as in
// Launchpad: drop it where it should go (hover at a page's edge to turn the
// page); the order is kept in settings (appGrid.order) and new apps go last.
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
        MuhosState.launchEntry(e);
        Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", e.name]);
        close();
    }

    // The order the user arranged (desktop ids); apps not in it follow, by name.
    readonly property var savedOrder: (Config.getSetting("appGrid", {}) || {}).order || []
    readonly property var allApps: {
        const all = (DesktopEntries.applications && DesktopEntries.applications.values) || [];
        const order = savedOrder;
        // Not itself, as on macOS.
        return all.filter(e => !e.noDisplay && e.name && e.id !== "muhos-apps")
                  .sort((a, b) => {
                      const ia = order.indexOf(a.id), ib = order.indexOf(b.id);
                      if (ia !== -1 && ib !== -1) return ia - ib;
                      if (ia !== -1) return -1;
                      if (ib !== -1) return 1;
                      return a.name.localeCompare(b.name);
                  });
    }

    // Moving an icon. The pages keep their contents while dragging (rebuilding
    // them would destroy the icon being dragged); the other icons slide aside
    // to show where it will land, and the order is saved on release.
    property bool dragging: false
    property int dragFrom: -1
    property int dragTo: -1
    property var dragEntry: null
    property point dragPos: Qt.point(0, 0)
    property int edgeTurn: 0
    function displayIndex(i) {
        if (!dragging || i === dragFrom) return i;
        if (dragFrom < dragTo && i > dragFrom && i <= dragTo) return i - 1;
        if (dragFrom > dragTo && i >= dragTo && i < dragFrom) return i + 1;
        return i;
    }
    function startDrag(entry, index, x, y) {
        if (query) return false;
        dragEntry = entry;
        dragFrom = index;
        dragTo = index;
        dragging = true;
        updateDrag(x, y);
        return true;
    }
    function updateDrag(x, y) {
        dragPos = Qt.point(x, y);
        const p = pages.mapFromItem(null, x, y);
        const edge = area.cellW * 0.4;
        edgeTurn = p.x < edge ? -1 : p.x > pages.width - edge ? 1 : 0;
        const gridX = (pages.width - area.columns * area.cellW) / 2;
        const col = Math.max(0, Math.min(area.columns - 1, Math.floor((p.x - gridX) / area.cellW)));
        const row = Math.max(0, Math.min(area.rows - 1, Math.floor(p.y / area.cellH)));
        dragTo = Math.max(0, Math.min(apps.length - 1, pages.currentIndex * area.perPage + row * area.columns + col));
    }
    function finishDrag() {
        if (!dragging) return;
        const ids = apps.map(e => e.id);
        const moved = ids.splice(dragFrom, 1);
        ids.splice(dragTo, 0, moved[0]);
        dragging = false;
        edgeTurn = 0;
        Config.setSetting("appGrid", Object.assign({}, Config.getSetting("appGrid", {}) || {}, { order: ids }));
    }
    function cancelDrag() { dragging = false; edgeTurn = 0; }
    Timer {
        // Hovering at a page's edge while dragging turns the page.
        running: win.dragging && win.edgeTurn !== 0
        interval: 650
        repeat: true
        onTriggered: { win.goToPage(pages.currentIndex + win.edgeTurn); win.updateDrag(win.dragPos.x, win.dragPos.y); }
    }
    // Keyboard selection (shown while searching) and the page it is on.
    property int selected: 0
    function goToPage(n) { pages.currentIndex = Math.max(0, Math.min(area.pageCount - 1, n)); }
    function select(i) {
        if (apps.length === 0) return;
        selected = Math.max(0, Math.min(apps.length - 1, i));
        goToPage(Math.floor(selected / area.perPage));
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
            selected = 0;
            pages.positionViewAtBeginning();
            pages.currentIndex = 0;
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
    // The Top layer (above windows and the menu bar): the dock moves up to the
    // Overlay layer while the grid is open, so it is always drawn above the
    // grid (on one shared layer, whichever surface mapped last won).
    WlrLayershell.layer: WlrLayer.Top
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
                onTextChanged: { win.query = text; win.selected = 0; pages.currentIndex = 0; }
                Keys.onEscapePressed: { if (win.dragging) win.cancelDrag(); else if (text) text = ""; else win.close(); }
                Keys.onReturnPressed: win.launch(win.apps[win.selected])
                Keys.onEnterPressed: win.launch(win.apps[win.selected])
                // Without a search, left and right turn pages; while searching
                // they move the selection.
                Keys.onLeftPressed: win.query ? win.select(win.selected - 1) : win.goToPage(pages.currentIndex - 1)
                Keys.onRightPressed: win.query ? win.select(win.selected + 1) : win.goToPage(pages.currentIndex + 1)
                Keys.onUpPressed: win.select(win.selected - area.columns)
                Keys.onDownPressed: win.select(win.selected + area.columns)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: win.t("search", "Search")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font: search.font
                }
            }
        }

        // Pages of apps, as in Launchpad: as many columns and rows as fit,
        // swipe or scroll sideways (or use the dots, or the arrow keys) to
        // move between pages.
        Item {
            id: area
            anchors.top: searchBox.bottom
            anchors.topMargin: MuhosStyle.s(28)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: MuhosStyle.s(130)    // dots, then clear of the dock
            anchors.left: parent.left
            anchors.right: parent.right

            readonly property int cellW: MuhosStyle.s(140)
            readonly property int cellH: MuhosStyle.s(132)
            readonly property int columns: Math.max(3, Math.min(7, Math.floor((width - MuhosStyle.s(96)) / cellW)))
            readonly property int rows: Math.max(2, Math.min(5, Math.floor(height / cellH)))
            readonly property int perPage: columns * rows
            readonly property int pageCount: Math.max(1, Math.ceil(win.apps.length / perPage))
        }

        ListView {
            id: pages
            anchors.fill: area
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: MuhosStyle.slow
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: area.pageCount
            interactive: area.pageCount > 1 && !win.dragging
            // Keep the neighbouring pages: the icon being dragged lives in one.
            cacheBuffer: width * 3

            delegate: Item {
                id: page
                required property int index
                width: pages.width
                height: pages.height

                // A click between icons closes, as on macOS.
                MouseArea { anchors.fill: parent; onClicked: win.close() }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: area.columns
                    Repeater {
                        model: win.apps.slice(page.index * area.perPage, (page.index + 1) * area.perPage)

                        Item {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property int globalIndex: page.index * area.perPage + index
                            readonly property bool current: win.selected === globalIndex && win.query !== ""
                            width: area.cellW
                            height: area.cellH

                            // While another icon is dragged, slide to the place this one will take.
                            readonly property int shownAt: win.displayIndex(globalIndex)
                            opacity: win.dragging && globalIndex === win.dragFrom ? 0 : 1
                            transform: Translate {
                                x: ((cell.shownAt % area.perPage) % area.columns - cell.index % area.columns) * area.cellW
                                   + (Math.floor(cell.shownAt / area.perPage) - page.index) * pages.width
                                y: (Math.floor((cell.shownAt % area.perPage) / area.columns) - Math.floor(cell.index / area.columns)) * area.cellH
                                Behavior on x { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }
                                Behavior on y { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }
                            }

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
                                scale: cellArea.pressed ? 0.9 : cellArea.containsMouse ? 1.06 : 1
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
                                id: cellArea
                                anchors.fill: parent
                                anchors.margins: MuhosStyle.s(6)
                                hoverEnabled: true
                                cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                pressAndHoldInterval: 450
                                onClicked: win.launch(cell.modelData)
                                onPressAndHold: mouse => {
                                    const p = mapToItem(null, mouse.x, mouse.y);
                                    // Keep the press: the pages must not take it for a swipe.
                                    if (win.startDrag(cell.modelData, cell.globalIndex, p.x, p.y)) preventStealing = true;
                                }
                                onPositionChanged: mouse => {
                                    if (!win.dragging) return;
                                    const p = mapToItem(null, mouse.x, mouse.y);
                                    win.updateDrag(p.x, p.y);
                                }
                                onReleased: { if (win.dragging) win.finishDrag(); preventStealing = false; }
                                onCanceled: { win.cancelDrag(); preventStealing = false; }
                            }
                        }
                    }
                }
            }

            // The mouse wheel turns pages (one per notch, with a short pause).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    if (pageTurn.running) return;
                    const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
                    if (Math.abs(d) < 30) return;
                    win.goToPage(pages.currentIndex + (d < 0 ? 1 : -1));
                    pageTurn.start();
                }
            }
            Timer { id: pageTurn; interval: 350 }
        }

        // Page dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: area.bottom
            anchors.topMargin: MuhosStyle.s(14)
            spacing: MuhosStyle.s(10)
            visible: area.pageCount > 1
            Repeater {
                model: area.pageCount
                Rectangle {
                    required property int index
                    width: MuhosStyle.s(8)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, pages.currentIndex === index ? 0.95 : 0.35)
                    Behavior on color { ColorAnimation { duration: MuhosStyle.fast } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -MuhosStyle.s(6)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.goToPage(parent.index)
                    }
                }
            }
        }

        // The icon being moved, under the pointer.
        Image {
            visible: win.dragging
            x: win.dragPos.x - width / 2
            y: win.dragPos.y - height / 2
            z: 10
            width: MuhosStyle.s(84)
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: win.dragEntry ? win.iconFor(win.dragEntry) : ""
            opacity: 0.92
        }

        Text {
            anchors.centerIn: area
            visible: win.apps.length === 0
            text: win.t("none", "No apps match “%1”").arg(win.query)
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textTitle
        }
    }
}
