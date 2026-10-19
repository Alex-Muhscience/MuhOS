// SPDX-License-Identifier: AGPL-3.0-or-later
// A Material Symbols Rounded icon, chosen by ligature name ("wifi",
// "volume_up"). Filled by default, as in the MuhOS design.
import QtQuick
import "../"

Text {
    property bool filled: true
    property int size: MuhosStyle.symbol

    color: MuhosStyle.text
    font.family: MuhosStyle.symbolFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": Math.max(20, Math.min(48, size)) })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: MuhosStyle.normal } }
}
