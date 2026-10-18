// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS first-run welcome screen, loaded by FirstLaunch instead of Start.qml.
//
// Designed to cost nothing while it waits: the only animations are a short
// entrance and exit; while idle nothing changes, so nothing is redrawn. The
// wallpaper shows through a plain translucent layer (no blur, no shaders).
// Contract with FirstLaunch: start() is called once loaded; finished() is
// emitted once when the user continues. openedSettings tells FirstLaunch that
// the settings window was opened, so its hint is not needed.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: window

    signal finished()
    signal closed()

    property bool openedSettings: false
    property bool leaving: false
    property real reveal: 0.0

    WlrLayershell.namespace: "muhos-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Quickshell.primaryScreen || null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    function start() {
        if (typeof Sounds !== "undefined") Sounds.playSfx("start/start.wav", 0.6);
        enter.start();
    }

    function leave(openSettings) {
        if (window.leaving) return;
        window.leaving = true;
        window.openedSettings = openSettings;
        exit.start();
    }

    NumberAnimation {
        id: enter
        target: window; property: "reveal"; from: 0.0; to: 1.0
        duration: 450; easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: exit
        NumberAnimation { target: window; property: "reveal"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (window.openedSettings && typeof Caching !== "undefined")
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "open", "guide"]);
                window.visible = false;
                window.finished();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
        opacity: 0.88 * window.reveal
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: window.reveal
        focus: true

        Keys.onReturnPressed: window.leave(false)
        Keys.onEnterPressed: window.leave(false)
        Keys.onEscapePressed: window.leave(false)

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 24 * (1.0 - window.reveal)
            spacing: 28

            Image {
                id: logo
                anchors.horizontalCenter: parent.horizontalCenter
                width: 112; height: 112
                source: "file://" + Caching.serpantinumDir + "/assets/logo.svg"
                sourceSize: Qt.size(224, 224)
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
            }
            MultiEffect {
                anchors.horizontalCenter: parent.horizontalCenter
                width: logo.width; height: logo.height
                source: logo
                colorization: 1.0
                colorizationColor: ThemeBackend.mauve
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("muhos.welcome_title")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    color: ThemeBackend.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("muhos.based_on", { "author": "Illia Miroshnichenko" })
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 14
                    color: ThemeBackend.subtext0
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: tips.implicitWidth + 48
                height: tips.implicitHeight + 36
                radius: ThemeBackend.borderRadius * 1.5
                color: Qt.alpha(ThemeBackend.surface0, 0.6)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.surface1, 0.8)

                Grid {
                    id: tips
                    anchors.centerIn: parent
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 12
                    verticalItemAlignment: Grid.AlignVCenter

                    Repeater {
                        model: [
                            { keys: "Super + D", label: "muhos.tip_launcher" },
                            { keys: "Super + H", label: "muhos.tip_settings" },
                            { keys: "Super + W", label: "muhos.tip_wallpapers" },
                            { keys: "Super + Enter", label: "muhos.tip_terminal" }
                        ]
                        delegate: Item {
                            required property var modelData
                            required property int index
                            implicitWidth: 300
                            implicitHeight: 28

                            Rectangle {
                                id: keyChip
                                anchors.verticalCenter: parent.verticalCenter
                                width: keyText.implicitWidth + 16
                                height: 26
                                radius: 6
                                color: ThemeBackend.surface1
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.keys
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: ThemeBackend.text
                                }
                            }
                            Text {
                                anchors.left: keyChip.right
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t(modelData.label)
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 14
                                color: ThemeBackend.subtext1
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                WelcomeButton {
                    label: I18n.t("muhos.welcome_open_settings")
                    primary: false
                    onClicked: window.leave(true)
                }
                WelcomeButton {
                    label: I18n.t("muhos.welcome_start")
                    primary: true
                    onClicked: window.leave(false)
                }
            }
        }
    }

    component WelcomeButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        signal clicked()

        width: Math.max(150, buttonText.implicitWidth + 40)
        height: 42
        radius: ThemeBackend.borderRadius
        color: primary
            ? (mouse.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve)
            : (mouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: button.primary ? ThemeBackend.crust : ThemeBackend.text
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
