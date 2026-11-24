// SPDX-License-Identifier: AGPL-3.0-or-later
// Equaliser window in glass: presets, a ten-band graphic EQ drawn as its
// frequency response (drag a band's dot up or down), balance, mono, swap,
// dynamics and a speaker test. Drives media/equalizer.sh (PipeWire
// filter-chain) through MuhosState; opened from the control centre or
// `muhos ipc call muhos equalizer`.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: MuhosCommands.equalizerOpen
    readonly property var eq: MuhosState.eq
    readonly property bool on: eq.enabled !== false

    function close() { MuhosCommands.equalizerOpen = false; }
    function t(key, fallback) {
        const k = "muhos.eq." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }
    function presetName(p) { return t("preset_" + p.toLowerCase(), p); }

    screen: MuhosCommands.equalizerScreen || Quickshell.screens[0]
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

        readonly property int pad: MuhosStyle.s(20)
        width: Math.min(MuhosStyle.s(640), win.width - MuhosStyle.s(32))
        height: content.implicitHeight + pad * 2
        anchors.centerIn: parent

        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 150; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 150; easing.type: win.shown ? MuhosStyle.easingEmphasis : MuhosStyle.easing } }

        MouseArea { anchors.fill: parent }

        GlassPanel {
            anchors.fill: parent
            radius: MuhosStyle.s(24)
            elevation: MuhosStyle.s(12)
        }

        Column {
            id: content
            x: panel.pad
            y: panel.pad
            width: panel.width - panel.pad * 2
            spacing: MuhosStyle.s(16)

            // Title row: close, title, on/off
            Item {
                width: parent.width
                height: MuhosStyle.s(28)
                CloseButton {
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: win.close()
                }
                Text {
                    anchors.centerIn: parent
                    text: win.t("title", "Equaliser")
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textTitle
                    font.weight: Font.Bold
                }
                MuhosSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: win.on
                    onToggled: MuhosState.eqSetEnabled(!win.on)
                }
            }

            // Presets
            Flow {
                width: parent.width
                spacing: MuhosStyle.s(6)
                opacity: win.on ? 1 : 0.45
                Repeater {
                    model: MuhosState.eqPresets.concat(win.eq.preset === "Custom" ? ["Custom"] : [])
                    Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool selected: win.eq.preset === modelData
                        readonly property bool custom: modelData === "Custom"
                        height: MuhosStyle.s(30)
                        width: chipText.implicitWidth + MuhosStyle.s(24)
                        radius: height / 2
                        color: selected ? MuhosStyle.accent : chipArea.containsMouse && !custom ? MuhosStyle.chipHover : MuhosStyle.chip
                        Behavior on color { ColorAnimation { duration: MuhosStyle.fast } }
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.custom ? win.t("custom", "Custom") : win.presetName(chip.modelData)
                            color: chip.selected ? MuhosStyle.textOnAccent : MuhosStyle.text
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(13)
                            font.weight: chip.selected ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            enabled: !chip.custom
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MuhosState.eqSetPreset(chip.modelData)
                        }
                    }
                }
            }

            // Response graph with one draggable dot per band
            Rectangle {
                id: graphBox
                width: parent.width
                height: MuhosStyle.s(210)
                radius: MuhosStyle.s(16)
                color: MuhosStyle.chip
                opacity: win.on ? 1 : 0.45

                readonly property real maxDb: 12
                readonly property int padX: MuhosStyle.s(26)
                readonly property int padTop: MuhosStyle.s(14)
                readonly property int padBottom: MuhosStyle.s(30)
                readonly property real plotW: width - padX * 2
                readonly property real plotH: height - padTop - padBottom
                // Live gains while a dot is dragged, otherwise the state.
                property var dragGains: null
                readonly property var gains: dragGains || MuhosState.eqFreqs.map((f, i) => MuhosState.eqGain(i))

                function xOf(freq) {
                    const lo = Math.log(20), hi = Math.log(20000);
                    return padX + (Math.log(freq) - lo) / (hi - lo) * plotW;
                }
                function yOf(db) { return padTop + (1 - (db + maxDb) / (2 * maxDb)) * plotH; }
                function dbAt(y) { return Math.max(-maxDb, Math.min(maxDb, ((1 - (y - padTop) / plotH) * 2 - 1) * maxDb)); }

                // Sum of the ten peaking filters' responses (RBJ biquads, Q 1, 48 kHz).
                function response(freq) {
                    const fs = 48000, w = 2 * Math.PI * freq / fs;
                    const cw = Math.cos(w), sw = Math.sin(w), c2 = Math.cos(2 * w), s2 = Math.sin(2 * w);
                    let total = 0;
                    for (let i = 0; i < 10; i++) {
                        const g = gains[i];
                        if (!g) continue;
                        const A = Math.pow(10, g / 40), w0 = 2 * Math.PI * MuhosState.eqFreqs[i] / fs;
                        const alpha = Math.sin(w0) / 2, cos0 = Math.cos(w0);
                        const b0 = 1 + alpha * A, b1 = -2 * cos0, b2 = 1 - alpha * A;
                        const a0 = 1 + alpha / A, a1 = -2 * cos0, a2 = 1 - alpha / A;
                        const nr = b0 + b1 * cw + b2 * c2, ni = -(b1 * sw + b2 * s2);
                        const dr = a0 + a1 * cw + a2 * c2, di = -(a1 * sw + a2 * s2);
                        total += 10 * Math.log10((nr * nr + ni * ni) / (dr * dr + di * di));
                    }
                    return Math.max(-maxDb, Math.min(maxDb, total));
                }

                // Grid: 0 dB and ±6 dB
                Repeater {
                    model: [-6, 0, 6]
                    Rectangle {
                        required property int modelData
                        x: graphBox.padX
                        width: graphBox.plotW
                        y: graphBox.yOf(modelData)
                        height: 1
                        color: modelData === 0 ? MuhosStyle.hairline : Qt.alpha(MuhosStyle.hairline, 0.5)
                    }
                }
                Text {
                    x: MuhosStyle.s(6)
                    y: graphBox.yOf(6) - height / 2
                    text: "+6"
                    color: MuhosStyle.textDim
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(10)
                }
                Text {
                    x: MuhosStyle.s(6)
                    y: graphBox.yOf(-6) - height / 2
                    text: "−6"
                    color: MuhosStyle.textDim
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(10)
                }

                Canvas {
                    id: curve
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative
                    property var g: graphBox.gains
                    property color accent: MuhosStyle.accent
                    onGChanged: requestPaint()
                    onAccentChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const pts = [];
                        const steps = 120;
                        for (let k = 0; k <= steps; k++) {
                            const f = 20 * Math.pow(1000, k / steps);
                            pts.push([graphBox.xOf(f), graphBox.yOf(graphBox.response(f))]);
                        }
                        const zero = graphBox.yOf(0);
                        // Soft fill between the curve and 0 dB
                        ctx.beginPath();
                        ctx.moveTo(pts[0][0], zero);
                        pts.forEach(p => ctx.lineTo(p[0], p[1]));
                        ctx.lineTo(pts[pts.length - 1][0], zero);
                        ctx.closePath();
                        ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.16);
                        ctx.fill();
                        // Curve
                        ctx.beginPath();
                        pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
                        ctx.lineWidth = MuhosStyle.s(2.5);
                        ctx.lineJoin = "round";
                        ctx.strokeStyle = accent;
                        ctx.stroke();
                    }
                }

                Repeater {
                    model: MuhosState.eqFreqs
                    Item {
                        id: band
                        required property int index
                        required property int modelData
                        readonly property real gain: graphBox.gains[index]
                        x: graphBox.xOf(modelData) - width / 2
                        width: MuhosStyle.s(34)
                        height: graphBox.height

                        // Frequency label
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: graphBox.height - graphBox.padBottom + MuhosStyle.s(8)
                            text: band.modelData >= 1000 ? (band.modelData / 1000) + "k" : String(band.modelData)
                            color: MuhosStyle.textDim
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(11)
                            font.features: { "tnum": 1 }
                        }
                        // Dot
                        Rectangle {
                            id: dot
                            readonly property bool active: drag.pressed || drag.containsMouse
                            width: MuhosStyle.s(active ? 16 : 13)
                            height: width
                            radius: width / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: graphBox.yOf(band.gain) - height / 2
                            color: "#ffffff"
                            border.width: MuhosStyle.s(3)
                            border.color: MuhosStyle.accent
                            Behavior on width { NumberAnimation { duration: MuhosStyle.fast } }
                        }
                        // Value while dragging or hovering
                        Rectangle {
                            visible: dot.active
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.max(0, dot.y - height - MuhosStyle.s(6))
                            width: valueText.implicitWidth + MuhosStyle.s(12)
                            height: MuhosStyle.s(20)
                            radius: height / 2
                            color: MuhosStyle.accent
                            Text {
                                id: valueText
                                anchors.centerIn: parent
                                text: (band.gain > 0 ? "+" : band.gain < 0 ? "−" : "") + Math.abs(band.gain).toFixed(band.gain % 1 ? 1 : 0) + " dB"
                                color: MuhosStyle.textOnAccent
                                font.family: MuhosStyle.font
                                font.pixelSize: MuhosStyle.s(11)
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            id: drag
                            anchors.fill: parent
                            anchors.bottomMargin: graphBox.padBottom - MuhosStyle.s(8)
                            enabled: win.on
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            function setFrom(y) {
                                const g = Math.round(graphBox.dbAt(y) * 2) / 2;
                                const next = graphBox.gains.slice();
                                next[band.index] = g;
                                graphBox.dragGains = next;
                            }
                            onPressed: m => setFrom(m.y)
                            onPositionChanged: m => { if (pressed) setFrom(m.y); }
                            onReleased: {
                                if (graphBox.dragGains) MuhosState.eqSetBand(band.index, graphBox.dragGains[band.index]);
                                graphBox.dragGains = null;
                            }
                            onDoubleClicked: MuhosState.eqSetBand(band.index, 0)
                            onWheel: w => MuhosState.eqSetBand(band.index, band.gain + (w.angleDelta.y > 0 ? 0.5 : -0.5))
                        }
                    }
                }
            }

            // Sound options
            Rectangle {
                width: parent.width
                height: options.implicitHeight + MuhosStyle.s(24)
                radius: MuhosStyle.s(16)
                color: MuhosStyle.chip
                opacity: win.on ? 1 : 0.45

                Column {
                    id: options
                    x: MuhosStyle.s(16)
                    y: MuhosStyle.s(12)
                    width: parent.width - MuhosStyle.s(32)
                    spacing: MuhosStyle.s(12)

                    // Balance
                    Item {
                        width: parent.width
                        height: MuhosStyle.s(28)
                        Text {
                            id: balanceLabel
                            anchors.verticalCenter: parent.verticalCenter
                            width: MuhosStyle.s(96)
                            text: win.t("balance", "Balance")
                            color: MuhosStyle.text
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.textBody
                        }
                        Text {
                            id: lLabel
                            anchors.left: balanceLabel.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "L"
                            color: MuhosStyle.textDim
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(12)
                            font.weight: Font.DemiBold
                        }
                        Item {
                            id: balanceTrack
                            anchors.left: lLabel.right
                            anchors.right: rLabel.left
                            anchors.leftMargin: MuhosStyle.s(12)
                            anchors.rightMargin: MuhosStyle.s(12)
                            anchors.verticalCenter: parent.verticalCenter
                            height: MuhosStyle.s(28)
                            property real local: NaN
                            readonly property real value: isNaN(local) ? Number(win.eq.balance || 0) : local
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: MuhosStyle.s(4)
                                radius: height / 2
                                color: MuhosStyle.hairline
                            }
                            Rectangle {   // centre mark
                                anchors.centerIn: parent
                                width: 2
                                height: MuhosStyle.s(12)
                                radius: 1
                                color: MuhosStyle.textDim
                            }
                            Rectangle {
                                width: MuhosStyle.s(20)
                                height: width
                                radius: width / 2
                                x: (balanceTrack.value + 1) / 2 * (balanceTrack.width - width)
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#ffffff"
                                border.width: 1
                                border.color: MuhosStyle.hairline
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: win.on
                                cursorShape: Qt.PointingHandCursor
                                function valueAt(x) {
                                    const v = Math.max(-1, Math.min(1, x / width * 2 - 1));
                                    return Math.abs(v) < 0.06 ? 0 : v;    // snaps to the centre
                                }
                                onPressed: m => balanceTrack.local = valueAt(m.x)
                                onPositionChanged: m => { if (pressed) balanceTrack.local = valueAt(m.x); }
                                onReleased: { MuhosState.eqSetBalance(balanceTrack.local); balanceTrack.local = NaN; }
                                onDoubleClicked: MuhosState.eqSetBalance(0)
                            }
                        }
                        Text {
                            id: rLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "R"
                            color: MuhosStyle.textDim
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(12)
                            font.weight: Font.DemiBold
                        }
                    }

                    // Mono, swap
                    Row {
                        width: parent.width
                        spacing: MuhosStyle.s(28)
                        Repeater {
                            model: [
                                { key: "mono", label: win.t("mono", "Mono audio") },
                                { key: "swap", label: win.t("swap", "Swap left and right") }
                            ]
                            Row {
                                required property var modelData
                                spacing: MuhosStyle.s(10)
                                MuhosSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    enabled: win.on
                                    checked: win.eq[parent.modelData.key] === true
                                    onToggled: MuhosState.eqSetFlag(parent.modelData.key, !checked)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.modelData.label
                                    color: MuhosStyle.text
                                    font.family: MuhosStyle.font
                                    font.pixelSize: MuhosStyle.textBody
                                }
                            }
                        }
                    }

                    // Dynamics
                    Item {
                        width: parent.width
                        height: MuhosStyle.s(30)
                        Text {
                            id: dynLabel
                            anchors.verticalCenter: parent.verticalCenter
                            width: MuhosStyle.s(96)
                            text: win.t("dynamics", "Dynamics")
                            color: MuhosStyle.text
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.textBody
                        }
                        Rectangle {
                            id: segments
                            anchors.left: dynLabel.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.eq.dynamicsAvailable === true
                            width: segRow.implicitWidth + MuhosStyle.s(6)
                            height: MuhosStyle.s(30)
                            radius: height / 2
                            color: MuhosStyle.hairline
                            Row {
                                id: segRow
                                anchors.centerIn: parent
                                Repeater {
                                    model: [
                                        { key: "off", label: win.t("dyn_off", "Off") },
                                        { key: "balanced", label: win.t("dyn_balanced", "Even out") },
                                        { key: "night", label: win.t("dyn_night", "Night") }
                                    ]
                                    Rectangle {
                                        id: seg
                                        required property var modelData
                                        readonly property bool selected: (win.eq.dynamics || "off") === modelData.key
                                        width: segText.implicitWidth + MuhosStyle.s(24)
                                        height: MuhosStyle.s(24)
                                        radius: height / 2
                                        color: selected ? MuhosStyle.panel : "transparent"
                                        Text {
                                            id: segText
                                            anchors.centerIn: parent
                                            text: seg.modelData.label
                                            color: MuhosStyle.text
                                            font.family: MuhosStyle.font
                                            font.pixelSize: MuhosStyle.s(13)
                                            font.weight: seg.selected ? Font.DemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: win.on
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: MuhosState.eqSetDynamics(seg.modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.left: dynLabel.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.eq.dynamicsAvailable !== true
                            text: win.t("dyn_missing", "Needs the ladspa-swh-plugins package")
                            color: MuhosStyle.textDim
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(13)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Footer: speaker test, reset
            Item {
                width: parent.width
                height: MuhosStyle.roundButton
                GlassButton {
                    anchors.left: parent.left
                    filledAtRest: true
                    padding: MuhosStyle.s(16)
                    onClicked: MuhosState.eqRun(["test"])
                    AdwIcon { anchors.verticalCenter: parent.verticalCenter; name: "audio-speakers" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.t("test", "Test speakers")
                        color: MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textBody
                    }
                }
                GlassButton {
                    anchors.right: parent.right
                    filledAtRest: true
                    padding: MuhosStyle.s(16)
                    onClicked: MuhosState.eqReset()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.t("reset", "Reset all")
                        color: MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textBody
                    }
                }
            }
        }
    }
}
