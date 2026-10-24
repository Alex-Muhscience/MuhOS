pragma Singleton
// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS design tokens ("Hybrid"): GNOME structure, a transparent macOS-style
// menu bar, liquid-glass panels. Colours follow the active (wallpaper-derived)
// theme; sizes go through the shell's scaler.
import QtQuick
import Quickshell
import "../"

QtObject {
    id: root

    function s(v) { return Math.round(Scaler.s(v)); }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

    // The MuhOS bar is used unless the user picks the classic one, or a layout
    // it does not cover yet (side bars, autohide). Shell.qml and Main.qml read this.
    readonly property var barSettings: Config.getSetting("bar", {})
    // The MuhOS look (glass dock, panels) unless the user picks the classic design.
    readonly property bool designActive: barSettings.design !== "classic"
    readonly property bool barActive: barSettings.design !== "classic"
        && barSettings.position !== "left" && barSettings.position !== "right"
        && !barSettings.autohide

    // "Reduce transparency": solid panels instead of glass (no compositor blur).
    readonly property bool solid: Config.getSetting("muhos", {}).solidPanels === true

    // Colour
    readonly property bool dark: luminance(ThemeBackend.base) < 0.5
    readonly property color accent: ThemeBackend.mauve
    // Light accents (e.g. lavender from the wallpaper) need dark text.
    readonly property color textOnAccent: luminance(accent) > 0.55 ? "#1b1530" : "#ffffff"
    readonly property color text: dark ? "#f6f5f8" : "#1d1b24"
    readonly property color textDim: tint(text, 0.68)
    readonly property color danger: ThemeBackend.red
    readonly property color panel: solid ? (dark ? "#2b2b2f" : "#fafafb")
                                         : (dark ? tint(ThemeBackend.base, 0.58) : Qt.rgba(1, 1, 1, 0.66))
    // The dock is lighter glass than the panels so more of the blur shows through.
    readonly property color dockTint: solid ? panel : (dark ? tint(ThemeBackend.base, 0.42) : Qt.rgba(1, 1, 1, 0.46))
    readonly property color panelBorder: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color chip: dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color chipHover: dark ? Qt.rgba(1, 1, 1, 0.17) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color chipPressed: dark ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(0, 0, 0, 0.15)
    readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    // Menu bar: transparent over the wallpaper, so its colours follow the
    // wallpaper's brightness under the bar (as macOS does), not the theme.
    function barText(light) { return light ? "#1d1b24" : "#ffffff"; }
    function barShade(light) { return light ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.28); }
    function barHover(light) { return light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.16); }
    function barActiveFill(light) { return light ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.24); }
    readonly property color island: solid ? panel : (dark ? Qt.rgba(0.08, 0.07, 0.11, 0.62) : Qt.rgba(1, 1, 1, 0.72))

    // Type
    readonly property string font: ThemeBackend.fontFamily
    readonly property int textSmall: s(12)
    readonly property int textBody: s(14)
    readonly property int textTitle: s(16)
    readonly property int icon: s(16)
    readonly property int iconLarge: s(18)

    // Shape and spacing
    readonly property int barBand: s(34)       // exclusive zone; Main.qml leaves this hole
    readonly property int barItem: s(26)
    readonly property int islandOpenWidth: s(440)
    readonly property int islandOpenHeight: s(92)
    readonly property int panelRadius: s(28)
    readonly property int toggleHeight: s(52)
    readonly property int roundButton: s(40)
    readonly property int gap: s(10)

    // Motion
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int slow: 420
    readonly property int easing: Easing.OutCubic
    readonly property int easingEmphasis: Easing.OutQuint
    readonly property int easingSpring: Easing.OutBack
}
