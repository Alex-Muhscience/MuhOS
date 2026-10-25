// SPDX-License-Identifier: AGPL-3.0-or-later
// Notification banners in glass, at the top right as on macOS. They read
// upstream's NotificationManager (pop-up and history models) and replace its
// pop-up window while the MuhOS design is active.
//
// A banner times out after the app's chosen delay (5 s by default, never for
// critical ones), pausing while the pointer is over it. Timing out keeps the
// notification in the history; clicking runs its default action and the close
// button or a swipe to the right dismisses it. Do not disturb holds back all
// but critical notifications, which still reach the notification centre.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../"

PanelWindow {
    id: win

    readonly property var notifSettings: Config.getSetting("notifications", {})
    readonly property bool dnd: notifSettings.dnd === true
    readonly property int bannerWidth: MuhosStyle.s(372)
    readonly property int pad: MuhosStyle.s(12)     // room for the shadow

    screen: LauncherController.getFocusedScreen() || Quickshell.screens[0]
    visible: NotificationManager.activePopupsModel.count > 0
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: MuhosStyle.barBand
        right: MuhosStyle.s(4)
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "muhos-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: bannerWidth + pad * 2
    implicitHeight: Math.min(list.contentHeight + pad * 3, (screen ? screen.height : 1000) * 0.8)
    mask: Region { item: list }

    // Sound and do not disturb, as upstream's pop-ups handle them.
    Connections {
        target: NotificationManager
        function onPopupAdded(uid, notif) {
            const critical = notif && notif.urgency === 2;
            if (win.dnd && !critical) {
                NotificationManager.removePopup(uid);
                return;
            }
            const cfg = win.notifSettings;
            if (cfg.sound !== false && cfg.soundFile)
                Sounds.play(cfg.soundFile);
        }
    }

    ListView {
        id: list
        x: win.pad
        y: win.pad
        width: win.bannerWidth
        height: Math.max(0, win.height - win.pad * 2)
        model: NotificationManager.activePopupsModel
        spacing: MuhosStyle.s(8)
        interactive: false

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MuhosStyle.normal; easing.type: MuhosStyle.easing }
                NumberAnimation { property: "x"; from: MuhosStyle.s(60); to: 0; duration: MuhosStyle.slow; easing.type: MuhosStyle.easingEmphasis }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: MuhosStyle.easing }
                NumberAnimation { property: "x"; to: MuhosStyle.s(80); duration: 200; easing.type: MuhosStyle.easing }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: MuhosStyle.normal; easing.type: MuhosStyle.easing }
        }

        delegate: Item {
            id: banner

            required property int index
            required property var model
            readonly property int uid: model.uid || model.latestUid
            readonly property var notif: NotificationManager.liveNotifs[uid] || null
            readonly property bool critical: model.urgency === 2
            readonly property int timeout: {
                if (critical) return 0;
                const t = notif && typeof notif.expireTimeout === "number" ? notif.expireTimeout : -1;
                return t > 0 ? t : (t === 0 ? 0 : 5000);
            }
            readonly property var extraActions: {
                try {
                    return JSON.parse(model.actionsJson || "[]").filter(a => a.id !== "default" && a.text).slice(0, 3);
                } catch (e) { return []; }
            }
            readonly property string iconUrl: MuhosState.notifIcon([model.icon, model.iconPath, model.image], model.appName)
            readonly property string imageUrl: MuhosState.notifPicture(model.image)
            readonly property bool hovered: hover.hovered

            width: ListView.view.width
            height: card.height

            function dismiss() {
                NotificationManager.dismissNotification(uid);
                NotificationManager.removePopup(uid);
            }

            Timer {
                interval: banner.timeout > 0 ? banner.timeout : 5000
                running: banner.timeout > 0 && !banner.hovered && !dragHandler.active
                onTriggered: NotificationManager.removePopup(banner.uid)
            }

            Item {
                id: card
                width: parent.width
                height: content.implicitHeight + MuhosStyle.s(28)
                x: dragHandler.active ? Math.max(0, dragHandler.translation.x) : 0
                opacity: 1 - Math.max(0, x) / (width * 1.2)
                Behavior on x { enabled: !dragHandler.active; NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }

                GlassPanel {
                    anchors.fill: parent
                    radius: MuhosStyle.s(18)
                    elevation: MuhosStyle.s(6)
                }
                Rectangle {
                    anchors.fill: parent
                    visible: banner.critical
                    radius: MuhosStyle.s(18)
                    color: "transparent"
                    border.width: 2
                    border.color: MuhosStyle.danger
                }

                HoverHandler { id: hover }
                // Swipe right to dismiss; the card follows the pointer (target: null).
                DragHandler {
                    id: dragHandler
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: if (!active && translation.x > card.width * 0.35) banner.dismiss()
                }
                // A MouseArea (not a TapHandler) so action and close buttons on top
                // take their own clicks without also activating the notification.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        MuhosState.notifActivate(banner.uid);
                        banner.dismiss();
                    }
                }

                Column {
                    id: content
                    x: MuhosStyle.s(14)
                    y: MuhosStyle.s(14)
                    width: parent.width - MuhosStyle.s(28)
                    spacing: MuhosStyle.s(10)

                    Row {
                        width: parent.width
                        spacing: MuhosStyle.s(12)

                        Item {
                            width: MuhosStyle.s(36)
                            height: width
                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: banner.iconUrl
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            AdwIcon {
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                name: "preferences-system-notifications"
                                size: MuhosStyle.s(22)
                            }
                        }

                        Column {
                            width: parent.width - MuhosStyle.s(48) - (thumb.visible ? thumb.width + MuhosStyle.s(12) : 0)
                            spacing: MuhosStyle.s(2)

                            Item {
                                width: parent.width
                                height: appName.implicitHeight
                                Text {
                                    id: appName
                                    width: parent.width - when.implicitWidth - MuhosStyle.s(8)
                                    text: banner.model.displayName || banner.model.appName || ""
                                    elide: Text.ElideRight
                                    color: MuhosStyle.textDim
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.textSmall
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    id: when
                                    anchors.right: parent.right
                                    text: MuhosState.relativeTime(banner.model.timestamp)
                                    color: MuhosStyle.textDim
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.textSmall
                                }
                            }
                            Text {
                                width: parent.width
                                text: banner.model.summary || ""
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                color: MuhosStyle.text
                                font.family: MuhosStyle.font
                                font.pixelSize: MuhosStyle.textBody
                                font.weight: Font.Bold
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: banner.model.body || ""
                                elide: Text.ElideRight
                                maximumLineCount: banner.hovered ? 8 : 3
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                                color: MuhosStyle.text
                                opacity: 0.85
                                font.family: MuhosStyle.font
                                font.pixelSize: MuhosStyle.s(13)
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }
                        }

                        ClippingRectangle {
                            id: thumb
                            visible: banner.imageUrl !== ""
                            width: MuhosStyle.s(48)
                            height: width
                            radius: MuhosStyle.s(10)
                            color: "transparent"
                            Image {
                                anchors.fill: parent
                                source: banner.imageUrl
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }

                    // Action buttons (the default action is the click itself).
                    Row {
                        visible: banner.extraActions.length > 0
                        width: parent.width
                        spacing: MuhosStyle.s(8)
                        Repeater {
                            model: banner.extraActions
                            GlassButton {
                                required property var modelData
                                filledAtRest: true
                                implicitHeight: MuhosStyle.s(32)
                                width: (parent.width - MuhosStyle.s(8) * (banner.extraActions.length - 1)) / banner.extraActions.length
                                onClicked: {
                                    MuhosState.notifAction(banner.uid, modelData.id);
                                    banner.dismiss();
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.text
                                    color: MuhosStyle.text
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.s(13)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // Close button, shown on hover at the top-left corner (macOS).
                Rectangle {
                    x: -MuhosStyle.s(6)
                    y: -MuhosStyle.s(6)
                    width: MuhosStyle.s(22)
                    height: width
                    radius: width / 2
                    color: closeMa.containsMouse ? MuhosStyle.chipPressed : MuhosStyle.panel
                    border.width: 1
                    border.color: MuhosStyle.panelBorder
                    opacity: banner.hovered ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: MuhosStyle.fast } }
                    AdwIcon {
                        anchors.centerIn: parent
                        name: "window-close"
                        size: MuhosStyle.s(12)
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: banner.dismiss()
                    }
                }
            }
        }
    }
}
