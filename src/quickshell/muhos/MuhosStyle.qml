pragma Singleton
// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS design tokens ("clean glass"). Colours follow the active theme so
// light and dark palettes both work; sizes go through the shell's scaler.
import QtQuick
import Quickshell
import "../"

QtObject {
    id: root

    function s(v) { return Math.round(Scaler.s(v)); }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // Colour
    readonly property color accent: ThemeBackend.mauve
    readonly property color onAccent: ThemeBackend.crust
    readonly property color text: ThemeBackend.text
    readonly property color textDim: tint(ThemeBackend.text, 0.70)
    readonly property color danger: ThemeBackend.red
    readonly property color glass: tint(ThemeBackend.base, 0.60)
    readonly property color glassStrong: tint(ThemeBackend.base, 0.70)
    readonly property color hairline: tint(ThemeBackend.text, 0.12)
    readonly property color fill: tint(ThemeBackend.text, 0.08)
    readonly property color fillHover: tint(ThemeBackend.text, 0.13)
    readonly property color fillPressed: tint(ThemeBackend.text, 0.18)

    // Type
    readonly property string font: ThemeBackend.fontFamily
    readonly property string symbolFont: "Material Symbols Rounded"
    readonly property int textBody: s(13)
    readonly property int textClock: s(15)
    readonly property int symbol: s(19)

    // Shape and spacing
    readonly property int barBand: s(48)      // must match the hole Main.qml leaves for the bar
    readonly property int barHeight: s(40)
    readonly property int barGap: s(8)
    readonly property int barRadius: s(16)
    readonly property int control: s(30)
    readonly property int controlRadius: s(10)
    readonly property int panelRadius: s(22)
    readonly property int gap: s(6)

    // Motion
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int slow: 420
    readonly property int easing: Easing.OutCubic
    readonly property int easingEmphasis: Easing.OutQuint
}
