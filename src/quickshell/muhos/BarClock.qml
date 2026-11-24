// SPDX-License-Identifier: AGPL-3.0-or-later
// macOS-layout clock: day, date and time as plain menu-bar text at the right
// end. Click opens the notification centre; a dot marks unread notifications.
import QtQuick
import "../"

GlassButton {
    id: root

    inBar: true
    padding: MuhosStyle.s(9)
    spacing: MuhosStyle.s(7)

    property var barScreen: null
    readonly property color ink: MuhosStyle.barText(lightWallpaper)

    active: MuhosCommands.notificationCentreOpen
    onClicked: MuhosCommands.toggleNotificationCentre(barScreen)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: MuhosState.unreadNotifications > 0
        width: MuhosStyle.s(6)
        height: width
        radius: width / 2
        color: root.ink
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: (DateTime.dayNameShort ? DateTime.dayNameShort + " " : "") + DateTime.shortDate + "   " + DateTime.timeShort
        color: root.ink
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.s(13)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
