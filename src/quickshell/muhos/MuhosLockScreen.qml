// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS lock screen, in the style of macOS: the wallpaper blurred, a large
// clock with the date, recent notifications as glass cards (titles only),
// what is playing, and at the bottom the user's picture, name and a glass
// password field, with sleep, restart and shut down at the corner.
//
// Only the look is MuhOS's. Authentication stays in upstream's lock/Lock.qml
// (PAM through /etc/pam.d/serpantinum); this screen talks to it exactly as
// upstream's LockScreen does: it answers PAM's prompt with pam.respond(), and
// once Lock.qml reports success (root.isUnlocking) it plays its exit and
// calls root.completeUnlock(). It is loaded by lock/LockSurface.qml in the
// MuhOS design.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../"

FocusScope {
    id: screenRoot

    required property var surface
    required property var root
    required property var rootLock
    required property var pam
    required property var lockUI
    required property var suspendProcess
    required property var reloadProcess
    required property var poweroffProcess

    anchors.fill: parent
    focus: true

    function t(key, fallback) {
        const k = "muhos.lock." + key;
        const v = I18n.t(k);
        return (v && v !== k) ? v : fallback;
    }

    readonly property string screenName: (surface.screen && surface.screen.name) ? surface.screen.name : ""
    readonly property string wallpaperSource: {
        const dir = Caching.getCacheDir("wallpaper");
        return "file://" + dir + (screenName !== "" ? "/current_wallpaper_" + screenName + ".png" : "/current_wallpaper.png");
    }
    readonly property string freezeSource: root.freezeTimestamp === "" ? ""
        : "file://" + Caching.getRunDir("screenshot") + "/lock_freeze_" + (screenName || "default") + "_" + root.freezeTimestamp + ".png"
    readonly property string userName: SystemInfo.username !== "" ? SystemInfo.username : t("user", "User")
    readonly property string avatar: SystemInfo.avatarPath !== ""
        ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : ""

    readonly property bool failed: lockUI.failed
    property real reveal: 0

    Component.onCompleted: {
        enter.start();
        focusTimer.start();
    }
    Timer { id: focusTimer; interval: 50; onTriggered: password.forceActiveFocus() }

    // Lock.qml sets isUnlocking once PAM accepts the password.
    readonly property bool unlocking: root.isUnlocking
    onUnlockingChanged: if (unlocking) leave.restart()

    onFailedChanged: {
        if (!failed) return;
        password.text = "";
        shake.restart();
    }

    function submit() {
        if (password.text.length === 0 || !pam.responseRequired || lockUI.authenticating) return;
        lockUI.authenticating = true;
        lockUI.statusText = I18n.t("lock.status.authenticating");
        lockUI.failed = false;
        pam.respond(password.text);
    }

    NumberAnimation { id: enter; target: screenRoot; property: "reveal"; from: 0; to: 1; duration: 480; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: leave
        NumberAnimation { target: screenRoot; property: "reveal"; to: 0; duration: 320; easing.type: Easing.InCubic }
        ScriptAction { script: screenRoot.root.completeUnlock() }
    }

    // --- Background: the wallpaper, blurred and dimmed ----------------------------
    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
    }
    // Larger than the screen, so the blur's darker edges fall outside it.
    Image {
        id: wall
        anchors.fill: parent
        anchors.margins: -MuhosStyle.s(80)
        source: screenRoot.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Error && screenRoot.freezeSource !== "") source = screenRoot.freezeSource
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        blurEnabled: true
        blurMax: 64
        blur: 0.85
        saturation: 0.15
        brightness: -0.06
        opacity: 0.35 + 0.65 * screenRoot.reveal
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.18) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.32) }
        }
    }

    // Any key typed anywhere goes to the password field.
    Keys.onPressed: event => {
        if (event.text.length > 0 && !password.activeFocus) {
            password.forceActiveFocus();
            password.insert(password.cursorPosition, event.text);
            event.accepted = true;
        }
    }

    Item {
        anchors.fill: parent
        opacity: screenRoot.reveal
        scale: 0.97 + 0.03 * screenRoot.reveal

        // --- Date and clock ----------------------------------------------------------
        Column {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.09
            spacing: MuhosStyle.s(2)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(DateTime.now, "dddd d MMMM")
                color: "#ffffff"
                opacity: 0.9
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(22)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: DateTime.timeShort
                color: "#ffffff"
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(112)
                font.weight: Font.DemiBold
                font.letterSpacing: -MuhosStyle.s(3)
                font.features: { "tnum": 1 }
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.25); shadowBlur: 0.6; shadowVerticalOffset: 2 }
            }
        }

        // --- Now playing and recent notifications (titles only) ------------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clock.bottom
            anchors.topMargin: MuhosStyle.s(26)
            width: MuhosStyle.s(380)
            spacing: MuhosStyle.s(8)

            Item {
                visible: MprisController.hasActivePlayer && MprisController.trackTitle !== ""
                width: parent.width
                height: MuhosStyle.s(64)
                GlassPanel { anchors.fill: parent; radius: MuhosStyle.s(18); elevation: MuhosStyle.s(4) }
                ClippingRectangle {
                    id: cover
                    x: MuhosStyle.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: MuhosStyle.s(44)
                    height: width
                    radius: MuhosStyle.s(10)
                    color: MuhosStyle.accent
                    Image {
                        anchors.fill: parent
                        source: MprisController.currentArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Column {
                    anchors.left: cover.right
                    anchors.leftMargin: MuhosStyle.s(12)
                    anchors.right: playButton.left
                    anchors.rightMargin: MuhosStyle.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: MprisController.trackTitle
                        elide: Text.ElideRight
                        color: MuhosStyle.text
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textBody
                        font.weight: Font.Bold
                    }
                    Text {
                        width: parent.width
                        text: MprisController.trackArtist
                        elide: Text.ElideRight
                        color: MuhosStyle.textDim
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textSmall
                    }
                }
                GlassButton {
                    id: playButton
                    anchors.right: parent.right
                    anchors.rightMargin: MuhosStyle.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    padding: 0
                    implicitWidth: MuhosStyle.s(36)
                    implicitHeight: MuhosStyle.s(36)
                    onClicked: if (MprisController.activePlayer) MprisController.activePlayer.togglePlaying()
                    AdwIcon { name: MprisController.isPlaying ? "media-playback-pause" : "media-playback-start"; size: MuhosStyle.s(18) }
                }
            }

            Repeater {
                model: Math.min(3, NotificationManager.globalNotificationHistory.count)
                Item {
                    required property int index
                    readonly property var n: NotificationManager.globalNotificationHistory.get(index)
                    width: parent.width
                    height: MuhosStyle.s(52)
                    GlassPanel { anchors.fill: parent; radius: MuhosStyle.s(16); elevation: MuhosStyle.s(4) }
                    Image {
                        id: nIcon
                        x: MuhosStyle.s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: MuhosStyle.s(28)
                        height: width
                        sourceSize: Qt.size(width * 2, height * 2)
                        source: n ? MuhosState.notifIcon([n.iconPath, n.image], n.appName) : ""
                        asynchronous: true
                    }
                    Column {
                        anchors.left: nIcon.right
                        anchors.leftMargin: MuhosStyle.s(12)
                        anchors.right: parent.right
                        anchors.rightMargin: MuhosStyle.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: n ? (n.appName || "") : ""
                            elide: Text.ElideRight
                            color: MuhosStyle.textDim
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.textSmall
                            font.weight: Font.DemiBold
                        }
                        // Titles only: message bodies stay private while locked.
                        Text {
                            width: parent.width
                            text: n ? (n.summary || "") : ""
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: MuhosStyle.text
                            font.family: MuhosStyle.font
                            font.pixelSize: MuhosStyle.s(13)
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        // --- User and password -------------------------------------------------------
        Column {
            id: login
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.1
            spacing: MuhosStyle.s(12)

            transform: Translate { id: shakeX; x: 0 }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeX; property: "x"; to: -MuhosStyle.s(14); duration: 60 }
                NumberAnimation { target: shakeX; property: "x"; to: MuhosStyle.s(12); duration: 70 }
                NumberAnimation { target: shakeX; property: "x"; to: -MuhosStyle.s(8); duration: 70 }
                NumberAnimation { target: shakeX; property: "x"; to: MuhosStyle.s(4); duration: 70 }
                NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
            }

            ClippingRectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: MuhosStyle.s(76)
                height: width
                radius: width / 2
                color: MuhosStyle.accent
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.5)
                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: screenRoot.userName.charAt(0).toUpperCase()
                    color: MuhosStyle.textOnAccent
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(32)
                    font.weight: Font.Bold
                }
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: screenRoot.avatar
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: screenRoot.userName
                color: "#ffffff"
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(17)
                font.weight: Font.Bold
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: MuhosStyle.s(260)
                height: MuhosStyle.s(40)

                GlassPanel {
                    anchors.fill: parent
                    radius: height / 2
                    elevation: MuhosStyle.s(3)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: screenRoot.failed ? 2 : 0
                    border.color: MuhosStyle.danger
                }
                TextInput {
                    id: password
                    anchors.left: parent.left
                    anchors.leftMargin: MuhosStyle.s(18)
                    anchors.right: submitButton.left
                    anchors.rightMargin: MuhosStyle.s(6)
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: MuhosStyle.text
                    font.family: MuhosStyle.font
                    font.pixelSize: MuhosStyle.s(15)
                    font.letterSpacing: MuhosStyle.s(2)
                    clip: true
                    focus: true
                    enabled: !screenRoot.unlocking
                    onAccepted: screenRoot.submit()
                    onTextChanged: if (text.length > 0 && screenRoot.lockUI.failed) screenRoot.lockUI.failed = false
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text === ""
                        text: screenRoot.t("enter_password", "Enter Password")
                        color: MuhosStyle.textDim
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.s(15)
                    }
                }
                GlassButton {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: MuhosStyle.s(5)
                    anchors.verticalCenter: parent.verticalCenter
                    padding: 0
                    implicitWidth: MuhosStyle.s(30)
                    implicitHeight: MuhosStyle.s(30)
                    filledAtRest: true
                    opacity: password.text.length > 0 || screenRoot.lockUI.authenticating ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MuhosStyle.fast } }
                    onClicked: screenRoot.submit()
                    AdwIcon {
                        name: "go-next"
                        size: MuhosStyle.s(15)
                        RotationAnimation on rotation {
                            running: screenRoot.lockUI.authenticating
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }
                }
            }

            // Status: wrong password, caps lock, fingerprint.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: screenRoot.failed ? screenRoot.t("wrong_password", "Incorrect password, try again")
                    : OsdController.lastCapsLock === 1 ? screenRoot.t("caps_lock", "Caps Lock is on")
                    : screenRoot.root.fingerprintAvailable ? screenRoot.lockUI.fpLabel
                    : " "
                color: screenRoot.failed ? "#ffb4b4" : Qt.rgba(1, 1, 1, 0.8)
                font.family: MuhosStyle.font
                font.pixelSize: MuhosStyle.s(13)
                font.weight: Font.DemiBold
            }
        }

        // --- Sleep, restart, shut down -------------------------------------------------
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: MuhosStyle.s(28)
            spacing: MuhosStyle.s(14)

            Repeater {
                model: [
                    { icon: "media-playback-pause", label: screenRoot.t("sleep", "Sleep"), run: () => screenRoot.suspendProcess.running = true },
                    { icon: "system-reboot", label: screenRoot.t("restart", "Restart"), run: () => screenRoot.reloadProcess.running = true },
                    { icon: "system-shutdown", label: screenRoot.t("shut_down", "Shut Down"), run: () => screenRoot.poweroffProcess.running = true }
                ]
                Column {
                    required property var modelData
                    spacing: MuhosStyle.s(6)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: MuhosStyle.s(44)
                        height: width
                        GlassPanel { anchors.fill: parent; radius: width / 2; elevation: MuhosStyle.s(3); tint: powerMa.containsMouse ? MuhosStyle.panelBorder : MuhosStyle.panel }
                        AdwIcon { anchors.centerIn: parent; name: modelData.icon; size: MuhosStyle.s(18) }
                        MouseArea {
                            id: powerMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.run()
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: "#ffffff"
                        opacity: 0.85
                        font.family: MuhosStyle.font
                        font.pixelSize: MuhosStyle.textSmall
                    }
                }
            }
        }
    }
}
