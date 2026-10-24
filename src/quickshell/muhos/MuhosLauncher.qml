// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS launcher, in the style of macOS Spotlight: a centred glass panel with
// one search field. Empty, it suggests the apps you use most; as you type it
// shows a calculator answer, matching apps, system actions and files.
// Replaces upstream's launcher while the MuhOS design is active; opened by the
// same LauncherController (Super+D, the logo in the menu bar).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
    id: win

    readonly property bool shown: LauncherController.isVisible && MuhosStyle.designActive
    property string query: ""
    property int selected: 0
    property var usage: ({ focus: {}, launch: {}, context: {} })
    property var fileHits: []
    readonly property string home: Quickshell.env("HOME") || ""

    function t(key, fallback) {
        const k = "muhos.launcher." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }
    function close() { LauncherController.hide(); }

    onShownChanged: {
        if (!shown) return;
        input.text = "";
        fileHits = [];
        selected = 0;
        rankProc.running = true;
        refresh();
        focusTimer.restart();
    }

    screen: LauncherController.screen || Quickshell.screens[0]
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
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { width: win.shown ? win.width : 0; height: win.shown ? win.height : 0 }

    // --- Data ------------------------------------------------------------------

    // Usage ranking shared with upstream's launcher (focus time, launches, time of day).
    Process {
        id: rankProc
        command: ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.usage = JSON.parse(this.text); } catch (e) {}
                win.refresh();
            }
        }
    }

    function usageScore(e) {
        const u = win.usage || {};
        const focus = u.focus || {}, launch = u.launch || {}, context = u.context || {};
        const keys = [(e.startupClass || "").toLowerCase(), (e.id || "").toLowerCase().replace(".desktop", ""), (e.name || "").toLowerCase()];
        let f = 0, c = 0;
        for (const k of keys) { if (!f && focus[k]) f = focus[k]; if (!c && context[k]) c = context[k]; }
        return f + (launch[e.name] || 0) + 0.5 * c;
    }

    function apps() {
        const all = (DesktopEntries.applications && DesktopEntries.applications.values) || [];
        return all.filter(e => !e.noDisplay);
    }

    function isSubsequence(q, s) {
        let i = 0;
        for (let j = 0; j < s.length && i < q.length; j++) if (s[j] === q[i]) i++;
        return i === q.length;
    }

    // Apps matching q; loose matches only when allowLoose and nothing matches properly.
    function matchApps(q, allowLoose) {
        const ql = q.toLowerCase();
        const scored = [];
        for (const e of apps()) {
            const name = (e.name || "").toLowerCase();
            let s = 0;
            if (name.startsWith(ql)) s = 100;
            else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(ql))) s = 80;
            else if (name.includes(ql)) s = 60;
            else {
                const extra = [e.genericName || "", (e.keywords || []).join(" "), (e.categories || []).join(" "), e.id || ""].join(" ").toLowerCase();
                if (extra.includes(ql)) s = 40;
                else if (ql.length > 1 && isSubsequence(ql, name)) s = 20;
            }
            if (s > 0) scored.push({ e: e, s: s + Math.min(15, Math.log(1 + usageScore(e)) * 3) });
        }
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        // Loose "letters in order" matches only help when nothing matches properly.
        const strong = scored.filter(x => x.s >= 40);
        return (strong.length > 0 ? strong : (allowLoose ? scored.slice(0, 3) : [])).map(x => x.e);
    }

    function topApps(n) {
        const list = apps().map(e => ({ e: e, u: usageScore(e) }));
        list.sort((a, b) => b.u - a.u || a.e.name.localeCompare(b.e.name));
        return list.slice(0, n).map(x => x.e);
    }

    function appIcon(e) {
        return (e.icon && Quickshell.iconPath(e.icon, true)) || Quickshell.iconPath("application-x-executable", true) || "";
    }

    // System actions. Power actions need 3 typed letters, so a stray Enter
    // on a short query never restarts the machine.
    readonly property var actions: [
        { id: "settings", title: t("settings", "Settings"), words: "settings preferences configure muhos", icon: "emblem-system", run: () => MuhosCommands.toggle("guide") },
        { id: "wallpaper", title: t("wallpapers", "Wallpapers"), words: "wallpaper background picture", icon: "preferences-desktop-wallpaper", run: () => MuhosCommands.toggle("wallpaper") },
        { id: "cc", title: t("control_centre", "Control Centre"), words: "control center centre quick settings wifi bluetooth volume", icon: "view-grid", run: () => MuhosCommands.toggleControlCentre(null) },
        { id: "clipboard", title: t("clipboard", "Clipboard History"), words: "clipboard paste copy history", icon: "edit-paste", run: () => MuhosCommands.toggle("clipboard") },
        { id: "screenshot", title: t("screenshot", "Take Screenshot"), words: "screenshot capture screen grab", icon: "camera-photo", run: () => shotDelay.start() },
        { id: "nightlight", title: MuhosState.nightLight ? t("night_off", "Turn Night Light Off") : t("night_on", "Turn Night Light On"), words: "night light blue filter warm", icon: "night-light", run: () => MuhosState.setNightLight(!MuhosState.nightLight) },
        { id: "dark", title: MuhosState.darkStyle ? t("dark_off", "Turn Dark Style Off") : t("dark_on", "Turn Dark Style On"), words: "dark style mode light theme appearance", icon: "weather-clear-night", run: () => MuhosState.setDarkStyle(!MuhosState.darkStyle) },
        { id: "dnd", title: MuhosState.dnd ? t("dnd_off", "Turn Do Not Disturb Off") : t("dnd_on", "Turn Do Not Disturb On"), words: "do not disturb notifications silence focus", icon: "notifications-disabled", run: () => MuhosState.setDnd(!MuhosState.dnd) },
        { id: "lock", title: t("lock", "Lock Screen"), words: "lock screen", icon: "system-lock-screen", run: () => MuhosState.run("lock") },
        { id: "suspend", power: true, title: t("suspend", "Suspend"), words: "suspend sleep", icon: "media-playback-pause", run: () => MuhosState.run("suspend") },
        { id: "restart", power: true, title: t("restart", "Restart"), words: "restart reboot", icon: "system-reboot", run: () => MuhosState.run("reboot") },
        { id: "poweroff", power: true, title: t("power_off", "Power Off"), words: "power off shutdown shut down", icon: "system-shutdown", run: () => MuhosState.run("poweroff") },
        { id: "logout", power: true, title: t("log_out", "Log Out"), words: "log out logout sign out exit", icon: "system-log-out", run: () => MuhosState.run("logout") }
    ]

    function matchActions(q) {
        const ql = q.toLowerCase();
        return actions.filter(a => {
            if (a.power && ql.length < 3) return false;
            const hay = (a.title + " " + a.words).toLowerCase();
            return hay.split(/\s+/).some(w => w.startsWith(ql)) || (ql.length > 2 && hay.includes(ql));
        });
    }

    // Calculator: a small parser for + - * / % ^ and parentheses (no eval).
    function calculate(text) {
        const src = text.replace(/\s+/g, "").replace(/,/g, ".");
        if (!/^[\d.+\-*/%^()]+$/.test(src) || !/[+\-*/%^(]/.test(src) || !/\d/.test(src)) return null;
        let pos = 0;
        const peek = () => src[pos];
        function number() {
            const m = /^\d*\.?\d+(?:e[+-]?\d+)?|^\d+\./.exec(src.slice(pos));
            if (!m) throw "number";
            pos += m[0].length;
            return parseFloat(m[0]);
        }
        function factor() {
            if (peek() === "+") { pos++; return factor(); }
            if (peek() === "-") { pos++; return -factor(); }
            let v;
            if (peek() === "(") { pos++; v = expr(); if (peek() !== ")") throw "paren"; pos++; }
            else v = number();
            if (peek() === "^") { pos++; v = Math.pow(v, factor()); }
            return v;
        }
        function term() {
            let v = factor();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = src[pos++], r = factor();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        function expr() {
            let v = term();
            while (peek() === "+" || peek() === "-") { const op = src[pos++]; v = op === "+" ? v + term() : v - term(); }
            return v;
        }
        try {
            const v = expr();
            if (pos !== src.length || !isFinite(v)) return null;
            return Number.isInteger(v) ? String(v) : String(parseFloat(v.toPrecision(12)));
        } catch (e) { return null; }
    }

    // --- Results -----------------------------------------------------------------

    ListModel { id: results }

    function refresh() {
        const q = query.trim();
        const items = [];
        const add = (section, kind, title, subtitle, icon, symbolic, payload) =>
            items.push({ section, kind, title, subtitle: subtitle || "", icon: icon || "", symbolic, payload: payload || "" });
        if (q === "") {
            for (const e of topApps(6)) add(t("suggestions", "Suggestions"), "app", e.name, e.genericName || e.comment, appIcon(e), false, e.id);
        } else {
            const answer = calculate(q);
            const acts = matchActions(q).slice(0, 4);
            const loose = answer === null && acts.length === 0 && fileHits.length === 0;
            if (answer !== null) add(t("calculator", "Calculator"), "calc", answer, t("copy_hint", "Press Enter to copy"), "accessories-calculator", true, answer);
            for (const e of matchApps(q, loose).slice(0, 6)) add(t("applications", "Applications"), "app", e.name, e.genericName || e.comment, appIcon(e), false, e.id);
            for (const a of acts) add(t("system", "System"), "action", a.title, "", a.icon, true, a.id);
            for (const f of fileHits) add(t("files", "Files"), "file", f.name, f.path.replace(home, "~"), f.isDir ? "folder" : "text-x-generic", true, f.path);
            if (items.length === 0) add("", "none", t("no_results", "No results"), "", "edit-find", true, "");
        }
        results.clear();
        for (const it of items) results.append(it);
        selected = Math.max(0, Math.min(selected, results.count - 1));
    }

    function move(step) {
        if (results.count === 0) return;
        selected = (selected + step + results.count) % results.count;
        if (results.get(selected).kind === "none") selected = 0;
    }

    function activate(i) {
        const it = results.get(i);
        if (!it || it.kind === "none") return;
        close();
        if (it.kind === "app") {
            const e = DesktopEntries.byId(it.payload);
            if (!e) return;
            e.execute();
            Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", e.name]);
        } else if (it.kind === "calc") {
            Quickshell.execDetached(["wl-copy", it.payload]);
        } else if (it.kind === "file") {
            Quickshell.execDetached(["gio", "open", it.payload]);
        } else if (it.kind === "action") {
            const a = actions.find(x => x.id === it.payload);
            if (a) a.run();
        }
    }

    // File search runs in the background, shortly after typing stops.
    Timer {
        id: fileTimer
        interval: 160
        onTriggered: {
            const q = win.query.trim();
            if (q.length < 2) { win.fileHits = []; win.refresh(); return; }
            fileProc.running = false;
            fileProc.forQuery = q;
            fileProc.command = ["python3", "-I", Caching.qsDir + "/muhos/file_search.py", q, "5"];
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        property string forQuery: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (fileProc.forQuery !== win.query.trim()) return;
                try { win.fileHits = JSON.parse(this.text); } catch (e) { win.fileHits = []; }
                win.refresh();
            }
        }
    }

    Timer { id: focusTimer; interval: 30; onTriggered: input.forceActiveFocus() }
    Timer { id: shotDelay; interval: 250; onTriggered: MuhosState.run("screenshot") }

    // --- Interface -------------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Item {
        id: panel

        readonly property int rowHeight: MuhosStyle.s(50)
        readonly property int searchHeight: MuhosStyle.s(66)
        readonly property int listHeight: results.count === 0 ? 0
            : Math.min(list.contentHeight, MuhosStyle.s(470)) + MuhosStyle.s(10)

        width: Math.min(MuhosStyle.s(680), win.width - MuhosStyle.s(40))
        height: searchHeight + listHeight
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height * 0.18)

        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: win.shown ? MuhosStyle.normal : 140; easing.type: MuhosStyle.easing } }
        Behavior on scale { NumberAnimation { duration: win.shown ? MuhosStyle.slow : 140; easing.type: win.shown ? MuhosStyle.easingEmphasis : MuhosStyle.easing } }
        Behavior on height { NumberAnimation { duration: MuhosStyle.normal; easing.type: MuhosStyle.easing } }

        MouseArea { anchors.fill: parent }

        GlassPanel {
            anchors.fill: parent
            radius: MuhosStyle.s(24)
            elevation: MuhosStyle.s(14)
        }

        // Search field
        Item {
            id: searchRow
            width: parent.width
            height: panel.searchHeight

            AdwIcon {
                id: searchIcon
                x: MuhosStyle.s(22)
                anchors.verticalCenter: parent.verticalCenter
                name: "edit-find"
                size: MuhosStyle.s(22)
                color: MuhosStyle.textDim
            }
            TextInput {
                id: input
                anchors.left: searchIcon.right
                anchors.leftMargin: MuhosStyle.s(14)
                anchors.right: escHint.left
                anchors.rightMargin: MuhosStyle.s(12)
                anchors.verticalCenter: parent.verticalCenter
                color: MuhosStyle.text
                selectionColor: MuhosStyle.accent
                selectedTextColor: MuhosStyle.textOnAccent
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(22)
                clip: true
                focus: true

                onTextChanged: {
                    win.query = text;
                    win.selected = 0;
                    if (text.trim().length < 2) win.fileHits = [];
                    win.refresh();
                    fileTimer.restart();
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape) {
                        if (input.text !== "") input.text = "";
                        else win.close();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) {
                        win.move(1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) {
                        win.move(-1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        win.activate(win.selected);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: win.t("placeholder", "Search apps, files and settings")
                    color: MuhosStyle.textDim
                    font: input.font
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                id: escHint
                anchors.right: parent.right
                anchors.rightMargin: MuhosStyle.s(18)
                anchors.verticalCenter: parent.verticalCenter
                width: escText.implicitWidth + MuhosStyle.s(14)
                height: MuhosStyle.s(24)
                radius: MuhosStyle.s(7)
                color: "transparent"
                border.width: 1
                border.color: MuhosStyle.hairline
                Text {
                    id: escText
                    anchors.centerIn: parent
                    text: "esc"
                    color: MuhosStyle.textDim
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textSmall
                }
            }
        }

        Rectangle {
            anchors.top: searchRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: MuhosStyle.s(16)
            anchors.rightMargin: MuhosStyle.s(16)
            height: 1
            color: MuhosStyle.hairline
            visible: results.count > 0
        }

        ListView {
            id: list
            anchors.top: searchRow.bottom
            anchors.topMargin: MuhosStyle.s(6)
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(0, panel.listHeight - MuhosStyle.s(10))
            model: results
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: win.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            section.property: "section"
            section.delegate: Item {
                required property string section
                width: ListView.view.width
                height: section === "" ? 0 : MuhosStyle.s(28)
                Text {
                    x: MuhosStyle.s(22)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: MuhosStyle.s(4)
                    text: parent.section
                    color: MuhosStyle.textDim
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.textSmall
                    font.weight: Font.DemiBold
                }
            }

            delegate: Item {
                id: row
                required property int index
                required property string kind
                required property string title
                required property string subtitle
                required property string icon
                required property bool symbolic
                readonly property bool isSelected: index === win.selected && kind !== "none"
                readonly property color ink: isSelected ? MuhosStyle.textOnAccent : MuhosStyle.text

                width: ListView.view.width
                height: panel.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: MuhosStyle.s(8)
                    anchors.rightMargin: MuhosStyle.s(8)
                    radius: MuhosStyle.s(12)
                    color: MuhosStyle.accent
                    opacity: row.isSelected ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MuhosStyle.fast } }
                }

                Item {
                    id: iconBox
                    x: MuhosStyle.s(20)
                    anchors.verticalCenter: parent.verticalCenter
                    width: MuhosStyle.s(32)
                    height: width
                    Image {
                        anchors.fill: parent
                        visible: !row.symbolic
                        source: row.symbolic ? "" : row.icon
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }
                    AdwIcon {
                        anchors.centerIn: parent
                        visible: row.symbolic
                        name: row.symbolic ? row.icon : ""
                        size: MuhosStyle.s(20)
                        color: row.ink
                    }
                }

                Column {
                    anchors.left: iconBox.right
                    anchors.leftMargin: MuhosStyle.s(14)
                    anchors.right: enterHint.left
                    anchors.rightMargin: MuhosStyle.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: MuhosStyle.s(1)
                    Text {
                        width: parent.width
                        text: row.title
                        elide: Text.ElideRight
                        color: row.kind === "none" ? MuhosStyle.textDim : row.ink
                        font.family: MuhosStyle.font
                        font.pixelSize: row.kind === "calc" ? MuhosStyle.s(20) : MuhosStyle.s(15)
                        font.weight: row.kind === "calc" ? Font.DemiBold : Font.Medium
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.subtitle
                        elide: Text.ElideMiddle
                        color: row.ink
                        opacity: 0.7
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textSmall
                    }
                }

                Text {
                    id: enterHint
                    anchors.right: parent.right
                    anchors.rightMargin: MuhosStyle.s(22)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵"
                    color: row.ink
                    opacity: row.isSelected ? 0.85 : 0
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(16)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.kind === "none" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: if (row.kind !== "none") win.selected = row.index
                    onClicked: win.activate(row.index)
                }
            }
        }
    }
}
