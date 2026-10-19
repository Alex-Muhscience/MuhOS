pragma Singleton
// SPDX-License-Identifier: AGPL-3.0-or-later
// Opens shell popups from inside the shell. Upstream components go through
// scripts/qs_manager.sh, which starts bash and a second quickshell process
// for every click (0.12-0.29 s in the test VM); this path calls Main directly.
import QtQuick
import Quickshell
import "../"

QtObject {
    signal commandRequested(string cmd, string target, string arg)

    function toggle(target, arg) {
        // The wallpaper picker prepares thumbnails in the script first.
        if (target === "wallpaper" || arg) {
            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", target].concat(arg ? [arg] : []));
            return;
        }
        commandRequested("toggle", target, "");
        // Keep the launcher's "frequently used" ranking in step with the script.
        Quickshell.execDetached(["python3", Caching.serpantinumDir + "/quickshell/launcher/app_rank.py", "--log-launch", "--name", target]);
    }
}
