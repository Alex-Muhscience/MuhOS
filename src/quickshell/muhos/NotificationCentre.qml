// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS notification centre, opened from the clock (GNOME's date menu in
// glass): notifications on the left, today's date and a month calendar on the
// right. Notification data comes from upstream's NotificationManager.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.notificationCentreOpen
    readonly property var history: NotificationManager.globalNotificationHistory

    function close() { MuhosCommands.notificationCentreOpen = false; }
    function t(key, fallback) {
        const k = "muhos.notifications." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }

    onShownChanged: {
        // While open, new notifications land in the list instead of as banners.
        NotificationManager.sysPanelOpen = shown;
        if (shown) {
            MuhosState.markAllNotificationsRead();
            calendar.reset();
        }
    }

    screen: MuhosCommands.notificationCentreScreen || LauncherController.getFocusedScreen() || Quickshell.screens[0]
    visible: shown || panel.opacity > 0
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
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    Shortcut {
        sequence: "Escape"
        enabled: win.shown
        onActivated: win.close()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Item {
        id: panel

        readonly property int pad: MuhosStyle.s(16)
        width: Math.min(MuhosStyle.s(760), win.width - MuhosStyle.s(24))
        height: MuhosStyle.s(500)
        x: Math.round((win.width - width) / 2)
        y: MuhosStyle.barBand + MuhosStyle.s(6)

        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.95
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 150; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 150; easing.type: win.shown ? MuhosStyle.easingEmphasis : MuhosStyle.easing } }

        MouseArea { anchors.fill: parent }

        GlassPanel {
            anchors.fill: parent
            elevation: MuhosStyle.s(12)
        }

        // --- Notifications ---------------------------------------------------
        Item {
            id: notifColumn
            x: panel.pad
            y: panel.pad
            width: panel.width - calendarColumn.width - panel.pad * 3 - 1
            height: panel.height - panel.pad * 2

            Item {
                id: notifHeader
                width: parent.width
                height: MuhosStyle.s(32)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.t("title", "Notifications")
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textTitle
                    font.weight: Font.Bold
                }
                GlassButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.history.count > 0
                    filledAtRest: true
                    implicitHeight: MuhosStyle.s(30)
                    padding: MuhosStyle.s(12)
                    spacing: MuhosStyle.s(6)
                    onClicked: NotificationManager.clearNotifications()
                    AdwIcon { anchors.verticalCenter: parent.verticalCenter; name: "edit-clear-all"; size: MuhosStyle.s(14) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.t("clear_all", "Clear all")
                        color: MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(13)
                    }
                }
            }

            ListView {
                id: notifList
                anchors.top: notifHeader.bottom
                anchors.topMargin: MuhosStyle.s(10)
                anchors.bottom: dndRow.top
                anchors.bottomMargin: MuhosStyle.s(10)
                width: parent.width
                model: win.history
                spacing: MuhosStyle.s(8)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Only animate while open: hidden views can leave animations half-done.
                remove: Transition {
                    enabled: win.shown
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 160 }
                        NumberAnimation { property: "x"; to: MuhosStyle.s(60); duration: 180; easing.type: MuhosStyle.easing }
                    }
                }
                displaced: Transition { enabled: win.shown; NumberAnimation { properties: "y"; duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }

                delegate: Rectangle {
                    id: item
                    required property var model
                    readonly property var resolved: NotificationManager.resolveApp(model)
                    readonly property string iconUrl: MuhosState.notifIcon([resolved && resolved.icon, model.iconPath, model.image], model.appName)

                    width: ListView.view.width
                    height: body.implicitHeight + MuhosStyle.s(24)
                    radius: MuhosStyle.s(14)
                    color: itemHover.hovered ? MuhosStyle.chipHover : MuhosStyle.chip
                    Behavior on color { ColorAnimation { duration: MuhosStyle.fast } }

                    HoverHandler { id: itemHover }
                    // A MouseArea (not a TapHandler) so the close button on top
                    // takes its own clicks without also activating the item.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MuhosState.notifActivate(item.model.uid);
                            NotificationManager.dismissNotification(item.model.uid);
                            win.close();
                        }
                    }

                    Row {
                        id: body
                        x: MuhosStyle.s(12)
                        y: MuhosStyle.s(12)
                        width: parent.width - MuhosStyle.s(24)
                        spacing: MuhosStyle.s(12)

                        Item {
                            width: MuhosStyle.s(32)
                            height: width
                            Image {
                                id: icon
                                anchors.fill: parent
                                source: item.iconUrl
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            AdwIcon {
                                anchors.centerIn: parent
                                visible: icon.status !== Image.Ready
                                name: "preferences-system-notifications"
                                size: MuhosStyle.s(20)
                            }
                        }
                        Column {
                            width: parent.width - MuhosStyle.s(44)
                            spacing: MuhosStyle.s(2)
                            Item {
                                width: parent.width
                                height: app.implicitHeight
                                Text {
                                    id: app
                                    width: parent.width - stamp.implicitWidth - MuhosStyle.s(30)
                                    text: (item.resolved && item.resolved.displayName) || item.model.appName || ""
                                    elide: Text.ElideRight
                                    color: MuhosStyle.textDim
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.textSmall
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    id: stamp
                                    anchors.right: parent.right
                                    anchors.rightMargin: MuhosStyle.s(26)
                                    text: MuhosState.relativeTime(item.model.timestamp)
                                    color: MuhosStyle.textDim
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.textSmall
                                }
                            }
                            Text {
                                width: parent.width
                                text: item.model.summary || ""
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                color: MuhosStyle.text
                                font.family: MuhosStyle.font
                                font.pixelSize: MuhosStyle.textBody
                                font.weight: Font.Bold
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: item.model.body || ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                color: MuhosStyle.text
                                opacity: 0.85
                                font.family: MuhosStyle.font
                                font.pixelSize: MuhosStyle.s(13)
                            }
                        }
                    }

                    GlassButton {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: MuhosStyle.s(6)
                        padding: 0
                        implicitWidth: MuhosStyle.s(26)
                        implicitHeight: MuhosStyle.s(26)
                        opacity: itemHover.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: MuhosStyle.fast } }
                        onClicked: NotificationManager.dismissNotification(item.model.uid)
                        AdwIcon { name: "window-close"; size: MuhosStyle.s(12) }
                    }
                }

                // Nothing to show
                Column {
                    anchors.centerIn: parent
                    visible: win.history.count === 0
                    spacing: MuhosStyle.s(10)
                    AdwIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "preferences-system-notifications"
                        size: MuhosStyle.s(40)
                        color: MuhosStyle.textDim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.t("empty", "No notifications")
                        color: MuhosStyle.textDim
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textBody
                    }
                }
            }

            // Do not disturb
            Rectangle {
                id: dndRow
                anchors.bottom: parent.bottom
                width: parent.width
                height: MuhosStyle.s(44)
                radius: MuhosStyle.s(14)
                color: MuhosStyle.chip

                AdwIcon {
                    id: dndIcon
                    x: MuhosStyle.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications-disabled"
                }
                Text {
                    anchors.left: dndIcon.right
                    anchors.leftMargin: MuhosStyle.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.t("dnd", "Do Not Disturb")
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textBody
                }
                MuhosSwitch {
                    anchors.right: parent.right
                    anchors.rightMargin: MuhosStyle.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    checked: MuhosState.dnd
                    onToggled: MuhosState.setDnd(!MuhosState.dnd)
                }
            }
        }

        Rectangle {
            x: notifColumn.x + notifColumn.width + panel.pad
            y: panel.pad
            width: 1
            height: panel.height - panel.pad * 2
            color: MuhosStyle.hairline
        }

        // --- Date and calendar -------------------------------------------------
        Column {
            id: calendarColumn
            x: panel.width - width - panel.pad
            y: panel.pad + MuhosStyle.s(4)
            width: MuhosStyle.s(272)
            spacing: MuhosStyle.s(14)

            Column {
                spacing: MuhosStyle.s(2)
                Text {
                    text: Qt.formatDate(new Date(DateTime.now), "dddd")
                    color: MuhosStyle.accent
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textBody
                    font.weight: Font.Bold
                }
                Text {
                    text: Qt.formatDate(new Date(DateTime.now), "d MMMM yyyy")
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(22)
                    font.weight: Font.Bold
                }
            }

            MonthCalendar {
                id: calendar
                width: parent.width
            }

            GlassButton {
                width: parent.width
                filledAtRest: true
                implicitHeight: MuhosStyle.s(36)
                spacing: MuhosStyle.s(8)
                onClicked: MuhosCommands.toggle("calendar")
                AdwIcon { anchors.verticalCenter: parent.verticalCenter; name: "x-office-calendar"; size: MuhosStyle.s(15) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.t("open_calendar", "Calendar and weather")
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(13)
                }
            }
        }
    }

    // A small on/off switch in the MuhOS style.
    component MuhosSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: MuhosStyle.s(42)
        height: MuhosStyle.s(24)
        radius: height / 2
        color: checked ? MuhosStyle.accent : MuhosStyle.chipPressed
        Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
        Rectangle {
            width: parent.height - MuhosStyle.s(6)
            height: width
            radius: width / 2
            y: MuhosStyle.s(3)
            x: sw.checked ? parent.width - width - MuhosStyle.s(3) : MuhosStyle.s(3)
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easingEmphasis } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    // Month grid with today marked; arrows page through months.
    component MonthCalendar: Column {
        id: cal
        property int year: new Date().getFullYear()
        property int month: new Date().getMonth()
        readonly property var loc: Qt.locale()
        readonly property int firstDay: loc.firstDayOfWeek % 7       // 0 = Sunday
        readonly property int offset: (new Date(year, month, 1).getDay() - firstDay + 7) % 7
        readonly property int days: new Date(year, month + 1, 0).getDate()
        readonly property int cell: Math.floor(width / 7)

        function reset() { const d = new Date(); year = d.getFullYear(); month = d.getMonth(); }
        function step(n) { const d = new Date(year, month + n, 1); year = d.getFullYear(); month = d.getMonth(); }

        spacing: MuhosStyle.s(6)

        Item {
            width: parent.width
            height: MuhosStyle.s(30)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cal.loc.standaloneMonthName(cal.month, Locale.LongFormat) + " " + cal.year
                color: MuhosStyle.text
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.textBody
                font.weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                GlassButton {
                    padding: 0
                    implicitWidth: MuhosStyle.s(28)
                    implicitHeight: MuhosStyle.s(28)
                    onClicked: cal.step(-1)
                    AdwIcon { name: "go-previous"; size: MuhosStyle.s(14) }
                }
                GlassButton {
                    padding: 0
                    implicitWidth: MuhosStyle.s(28)
                    implicitHeight: MuhosStyle.s(28)
                    onClicked: cal.step(1)
                    AdwIcon { name: "go-next"; size: MuhosStyle.s(14) }
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: cal.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: cal.loc.standaloneDayName((cal.firstDay + index) % 7, Locale.NarrowFormat)
                    color: MuhosStyle.textDim
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textSmall
                    font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: 42
                Item {
                    id: day
                    required property int index
                    readonly property int date: index - cal.offset + 1
                    readonly property bool inMonth: date >= 1 && date <= cal.days
                    readonly property bool isToday: {
                        DateTime.now;
                        const d = new Date();
                        return inMonth && date === d.getDate() && cal.month === d.getMonth() && cal.year === d.getFullYear();
                    }
                    width: cal.cell
                    height: cal.cell * 0.86
                    visible: index < 35 || cal.offset + cal.days > 35
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - MuhosStyle.s(4)
                        height: width
                        radius: width / 2
                        color: MuhosStyle.accent
                        visible: day.isToday
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: day.inMonth
                        text: day.date
                        color: day.isToday ? MuhosStyle.textOnAccent : MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(13)
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
