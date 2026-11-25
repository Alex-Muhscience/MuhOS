// SPDX-License-Identifier: AGPL-3.0-or-later
// GNOME-style window previews for the dock: left-clicking an app with
// several windows raises a strip of live window previews next to its icon.
// Clicking a preview focuses and raises that window (WindowTracker also
// dispatches bring_to_top on Hyprland). The strip closes on selection,
// shortly after the pointer leaves it, or when another app is clicked.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    screen: DockWindowPreviewsController.screen

    WlrLayershell.namespace: "dockwindowpreviews"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    onShownChanged: {
        if (shown) {
            leaveTimer.stop();
            autoCloseTimer.restart();
        }
    }

    readonly property bool shown: DockWindowPreviewsController.isVisible
    function close() { DockWindowPreviewsController.hide(); }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    readonly property real cardHeight: s(150)
    readonly property real cardGap: s(12)
    readonly property real captionH: s(26)
    readonly property real edgeMargin: s(12)

    // One preview card per window: live screencopy where the compositor
    // offers one (Hyprland), a titled placeholder elsewhere.
    readonly property var cards: DockWindowPreviewsController.windows

    readonly property real stripWidth: {
        if (cards.length === 0) return 0;
        let w = 0;
        for (let i = 0; i < cards.length; i++) w += cardItemWidth(cards[i]);
        return w + cardGap * (cards.length - 1);
    }
    readonly property real stripHeight: cardHeight + captionH

    function cardItemWidth(w) {
        let ipc = (w && w.native && w.native.lastIpcObject) ? w.native.lastIpcObject : null;
        let sw = (ipc && ipc.size && ipc.size[0]) || 1600;
        let sh = (ipc && ipc.size && ipc.size[1]) || 900;
        // Width that fills cardHeight at the window's aspect; clamped so very
        // wide or portrait windows still fit the card height.
        let fitW = cardHeight * (sw / Math.max(1, sh));
        return Math.min(Math.max(s(60), Math.min(s(280), fitW)), fitW);
    }

    readonly property real halfBtn: DockWindowPreviewsController.buttonSize > 0
        ? DockWindowPreviewsController.buttonSize / 2 : s(22)
    readonly property real offset: s(14)

    property real computedX: {
        let w = stripWidth;
        if (DockWindowPreviewsController.dockPosition === "left") {
            return DockWindowPreviewsController.targetX + halfBtn + offset;
        } else if (DockWindowPreviewsController.dockPosition === "right") {
            return DockWindowPreviewsController.targetX - halfBtn - w - offset;
        }
        return DockWindowPreviewsController.targetX - w / 2;
    }
    property real computedY: {
        let h = stripHeight;
        if (DockWindowPreviewsController.dockPosition === "top") {
            return DockWindowPreviewsController.targetY + halfBtn + offset;
        } else if (DockWindowPreviewsController.dockPosition === "bottom") {
            return DockWindowPreviewsController.targetY - halfBtn - h - offset;
        }
        return DockWindowPreviewsController.targetY - h / 2;
    }

    readonly property real clampedX: Math.max(edgeMargin, Math.min(win.width - stripWidth - edgeMargin, computedX))
    readonly property real clampedY: Math.max(edgeMargin, Math.min(win.height - stripHeight - edgeMargin, computedY))

    visible: shown || strip.opacity > 0.001

    mask: Region {
        item: (win.shown || strip.opacity > 0.001) ? strip : null
    }

    anchors { top: true; bottom: true; left: true; right: true }

    // The strip itself is the only interactive area; everything else passes
    // through to the desktop, like the app menu.
    Item {
        id: strip
        x: win.clampedX
        y: win.clampedY
        width: win.stripWidth
        height: win.stripHeight
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        transformOrigin: Item.Bottom

        Behavior on opacity { NumberAnimation { duration: win.shown ? 160 : 90; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: win.shown ? 200 : 90; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                if (hovered) {
                    autoCloseTimer.stop();
                    leaveTimer.stop();
                } else if (win.shown) {
                    leaveTimer.interval = 700;
                    leaveTimer.restart();
                }
            }
        }

        Row {
            spacing: win.cardGap

            Repeater {
                model: win.cards

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property var ipc: (modelData.native && modelData.native.lastIpcObject) ? modelData.native.lastIpcObject : ({})
                    readonly property real srcW: (ipc.size && ipc.size[0]) || 1600
                    readonly property real srcH: (ipc.size && ipc.size[1]) || 900
                    readonly property real cardW: win.cardItemWidth(modelData)
                    readonly property real frameY: (card.height - win.captionH - cardW * (srcH / srcW)) / 2
                    readonly property var waylandToplevel: (modelData.native && modelData.native.wayland) ? modelData.native.wayland : null

                    width: cardW
                    height: win.cardHeight + win.captionH

                    Rectangle {
                        id: frame
                        x: 0
                        y: card.frameY
                        width: card.cardW
                        height: card.cardW * (card.srcH / card.srcW)
                        radius: MuhosStyle.s(10)
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: cardHover.hovered ? MuhosStyle.s(2) : MuhosStyle.s(1)
                        border.color: cardHover.hovered ? MuhosStyle.accent : Qt.rgba(1, 1, 1, 0.18)
                        clip: true

                        Behavior on border.width { NumberAnimation { duration: 120 } }

                        ScreencopyView {
                            id: view
                            anchors.fill: parent
                            anchors.margins: frame.border.width
                            captureSource: win.shown ? card.waylandToplevel : null
                            live: win.shown
                        }

                        // No screencopy (other compositors): show a titled
                        // placeholder instead.
                        Rectangle {
                            anchors.fill: parent
                            visible: card.waylandToplevel === null
                            color: Qt.rgba(0.08, 0.09, 0.13, 0.85)

                            Column {
                                anchors.centerIn: parent
                                spacing: MuhosStyle.s(6)
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰖲"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.s(22)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(implicitWidth, frame.width - MuhosStyle.s(16))
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: card.modelData.title || ""
                                    color: "#ffffff"
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.s(12)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.top: frame.bottom
                        anchors.topMargin: MuhosStyle.s(6)
                        width: card.cardW
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        text: card.modelData.title || (card.ipc.class || "")
                        color: "#ffffff"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(12)
                        font.weight: Font.Medium
                    }

                    HoverHandler { id: cardHover }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx("reusables/iconbutton/click.wav");
                            }
                            if (typeof WindowTracker !== "undefined") {
                                WindowTracker.focusWindow(card.modelData);
                            }
                            win.close();
                        }
                    }
                }
            }
        }
    }

    // Close shortly after the pointer leaves the strip, like the app menu.
    Timer {
        id: leaveTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (!stripHover.hovered) win.close();
        }
    }
    Timer {
        id: autoCloseTimer
        interval: 4000
        repeat: false
        onTriggered: {
            if (!stripHover.hovered) win.close();
        }
    }
}
