// SPDX-License-Identifier: AGPL-3.0-or-later
// The clock "island" in the middle of the menu bar. Shows the date and time;
// while music plays it adds the cover and a small visualizer, and a click
// expands it into a player. Without music, a click opens the calendar.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../"

Item {
    id: root

    property bool expanded: false
    readonly property bool hasMedia: MprisController.hasActivePlayer && MprisController.trackTitle !== ""
    readonly property var player: MprisController.activePlayer

    signal openCalendar()

    onHasMediaChanged: if (!hasMedia) expanded = false

    width: expanded ? MuhosStyle.islandOpenWidth : collapsed.implicitWidth + MuhosStyle.s(28)
    height: expanded ? MuhosStyle.islandOpenHeight : MuhosStyle.barItem
    Behavior on width { NumberAnimation { duration: MuhosStyle.slow; easing.type: MuhosStyle.easingSpring; easing.overshoot: 0.8 } }
    Behavior on height { NumberAnimation { duration: MuhosStyle.slow; easing.type: MuhosStyle.easingSpring; easing.overshoot: 0.8 } }

    GlassPanel {
        anchors.fill: parent
        radius: root.expanded ? MuhosStyle.s(30) : height / 2
        tint: area.containsMouse && !root.expanded ? Qt.lighter(MuhosStyle.island, 1.15) : MuhosStyle.island
        elevation: root.expanded ? MuhosStyle.s(8) : MuhosStyle.s(2)
        Behavior on radius { NumberAnimation { duration: MuhosStyle.slow; easing.type: MuhosStyle.easing } }
        Behavior on tint { ColorAnimation { duration: MuhosStyle.fast } }
        Behavior on elevation { NumberAnimation { duration: MuhosStyle.slow; easing.type: MuhosStyle.easing } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton || !root.hasMedia) root.openCalendar();
            else root.expanded = !root.expanded;
        }
    }

    // Collapsed: date, time and, while music plays, cover plus visualizer.
    Row {
        id: collapsed
        anchors.centerIn: parent
        spacing: MuhosStyle.s(10)
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: MuhosStyle.fast } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (DateTime.dayNameShort ? DateTime.dayNameShort + " " : "") + DateTime.shortDate
            color: MuhosStyle.text
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textBody
            font.weight: Font.Bold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: DateTime.timeShort
            color: MuhosStyle.text
            font.family: MuhosStyle.font
            font.pixelSize: MuhosStyle.textBody
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasMedia
            spacing: MuhosStyle.s(6)

            Rectangle {
                width: 1
                height: MuhosStyle.s(14)
                anchors.verticalCenter: parent.verticalCenter
                color: MuhosStyle.hairline
            }
            Cover {
                size: MuhosStyle.s(16)
                radius: MuhosStyle.s(5)
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: MuhosStyle.s(14)
                spacing: MuhosStyle.s(2)
                Repeater {
                    model: 4
                    Rectangle {
                        id: eqBar
                        required property int index
                        anchors.bottom: parent.bottom
                        width: MuhosStyle.s(3)
                        radius: width / 2
                        color: MuhosStyle.accent
                        height: MuhosStyle.s(4)
                        // Only animates while music is actually playing.
                        SequentialAnimation on height {
                            running: MprisController.isPlaying && collapsed.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: MuhosStyle.s(14); duration: 380 + eqBar.index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: MuhosStyle.s(4); duration: 380 + eqBar.index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    // Expanded: a small player.
    Item {
        anchors.fill: parent
        anchors.leftMargin: MuhosStyle.s(16)
        anchors.rightMargin: MuhosStyle.s(14)
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }

        Cover {
            id: bigCover
            size: MuhosStyle.s(60)
            radius: MuhosStyle.s(16)
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            anchors.left: bigCover.right
            anchors.leftMargin: MuhosStyle.s(14)
            anchors.right: controls.left
            anchors.rightMargin: MuhosStyle.s(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: MuhosStyle.s(3)

            Text {
                width: parent.width
                text: MprisController.trackTitle
                elide: Text.ElideRight
                color: MuhosStyle.text
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.textTitle
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                text: MprisController.trackArtist
                elide: Text.ElideRight
                color: MuhosStyle.textDim
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(13)
            }
            Item { width: 1; height: MuhosStyle.s(4) }
            Rectangle {
                width: parent.width
                height: MuhosStyle.s(4)
                radius: height / 2
                color: MuhosStyle.hairline
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    color: MuhosStyle.accent
                    width: (root.player && root.player.length > 0)
                        ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                }
            }
        }
        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: MuhosStyle.s(2)

            GlassButton {
                padding: 0
                implicitWidth: MuhosStyle.s(36)
                implicitHeight: MuhosStyle.s(36)
                onClicked: if (root.player) root.player.previous()
                AdwIcon { name: "media-skip-backward"; size: MuhosStyle.iconLarge }
            }
            GlassButton {
                padding: 0
                filledAtRest: true
                implicitWidth: MuhosStyle.s(44)
                implicitHeight: MuhosStyle.s(44)
                onClicked: if (root.player) root.player.togglePlaying()
                AdwIcon { name: MprisController.isPlaying ? "media-playback-pause" : "media-playback-start"; size: MuhosStyle.s(22) }
            }
            GlassButton {
                padding: 0
                implicitWidth: MuhosStyle.s(36)
                implicitHeight: MuhosStyle.s(36)
                onClicked: if (root.player) root.player.next()
                AdwIcon { name: "media-skip-forward"; size: MuhosStyle.iconLarge }
            }
        }
    }

    // MPRIS positions are not pushed; refresh while the player is visible.
    Timer {
        interval: 1000
        repeat: true
        running: root.expanded && MprisController.isPlaying
        onTriggered: if (root.player) root.player.positionChanged()
    }

    component Cover: ClippingRectangle {
        id: cover
        property int size: 16
        width: size
        height: size
        color: MuhosStyle.accent
        Image {
            anchors.fill: parent
            source: MprisController.currentArtUrl || ""
            sourceSize: Qt.size(cover.size * 2, cover.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
