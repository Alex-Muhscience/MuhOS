import QtQuick
import QtQuick.Window
import Quickshell.Wayland
import "../"

WlSessionLockSurface {
    id: lockSurface
    required property var sRoot
    required property var sRootLock
    required property var sPam
    required property var sLockUI
    required property var sSuspendProcess
    required property var sReloadProcess
    required property var sPoweroffProcess

    // MuhOS: the macOS-style lock screen in the MuhOS design. Both screens get
    // the same objects; authentication stays in Lock.qml either way.
    Loader {
        anchors.fill: parent
        focus: true
        sourceComponent: MuhosStyle.designActive ? muhosScreen : upstreamScreen
    }

    Component {
        id: upstreamScreen
        LockScreen {
            surface: lockSurface
            root: lockSurface.sRoot
            rootLock: lockSurface.sRootLock
            pam: lockSurface.sPam
            lockUI: lockSurface.sLockUI
            suspendProcess: lockSurface.sSuspendProcess
            reloadProcess: lockSurface.sReloadProcess
            poweroffProcess: lockSurface.sPoweroffProcess
        }
    }

    Component {
        id: muhosScreen
        MuhosLockScreen {
            surface: lockSurface
            root: lockSurface.sRoot
            rootLock: lockSurface.sRootLock
            pam: lockSurface.sPam
            lockUI: lockSurface.sLockUI
            suspendProcess: lockSurface.sSuspendProcess
            reloadProcess: lockSurface.sReloadProcess
            poweroffProcess: lockSurface.sPoweroffProcess
        }
    }
}
