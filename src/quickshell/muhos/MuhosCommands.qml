pragma Singleton
// SPDX-License-Identifier: AGPL-3.0-or-later
// Opens shell popups from inside the shell. Upstream components go through
// scripts/qs_manager.sh, which starts bash and a second quickshell process
// for every click (0.12-0.29 s in the test VM); this path calls Main directly.
// Also owns the MuhOS control centre's open state.
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

QtObject {
    id: root

    signal commandRequested(string cmd, string target, string arg)

    property bool controlCentreOpen: false
    property bool notificationCentreOpen: false
    property var notificationCentreScreen: null
    property var controlCentreScreen: null

    function toggle(target, arg) {
        controlCentreOpen = false;
        notificationCentreOpen = false;
        // The wallpaper picker prepares thumbnails in the script first.
        if (target === "wallpaper" || arg) {
            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", target].concat(arg ? [arg] : []));
            return;
        }
        commandRequested("toggle", target, "");
        // Keep the launcher's "frequently used" ranking in step with the script.
        Quickshell.execDetached(["python3", Caching.serpantinumDir + "/quickshell/launcher/app_rank.py", "--log-launch", "--name", target]);
    }

    // `muhos ipc call muhos controlCentre` (also handy for a key binding).
    readonly property IpcHandler _ipc: IpcHandler {
        target: "muhos"
        function controlCentre(): void { root.toggleControlCentre(null); }
        function notificationCentre(): void { root.toggleNotificationCentre(null); }
    }

    function toggleControlCentre(screen) {
        if (!controlCentreOpen) {
            commandRequested("close", "", "");
            notificationCentreOpen = false;
            controlCentreScreen = screen || null;
        }
        controlCentreOpen = !controlCentreOpen;
    }

    // Notification centre (clock): notifications and a calendar, like GNOME's date menu.
    function toggleNotificationCentre(screen) {
        if (!notificationCentreOpen) {
            commandRequested("close", "", "");
            controlCentreOpen = false;
            notificationCentreScreen = screen || null;
        }
        notificationCentreOpen = !notificationCentreOpen;
    }
}
