// SPDX-License-Identifier: AGPL-3.0-or-later
// Time and date; opens the calendar.
import QtQuick
import "../"

GlassButton {
    id: root
    spacing: MuhosStyle.s(10)

    Text {
        anchors.baseline: date.baseline
        text: DateTime.timeShort
        color: MuhosStyle.text
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.textClock
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
    Text {
        id: date
        anchors.verticalCenter: parent.verticalCenter
        text: (DateTime.dayNameShort ? DateTime.dayNameShort + " " : "") + DateTime.shortDate
        color: MuhosStyle.textDim
        font.family: MuhosStyle.font
        font.pixelSize: MuhosStyle.textBody
    }
}
