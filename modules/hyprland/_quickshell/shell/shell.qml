pragma ComponentBehavior: Bound

import qs.dialogs
import qs.lockscreen
import qs.notifications
import qs.switcher
import qs.lib

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit

ShellRoot {
    id: root

    function lockSession() {
        sessionLock.locked = true;
    }

    // -- session lock --

    WlSessionLock {
        id: sessionLock

        signal unlock

        surface: Component {
            LockSurface {
                lock: sessionLock
                pam: pam // qmllint disable incompatible-type
            }
        }
    }

    Pam {
        id: pam
        lock: sessionLock
    }

    // -- global shortcuts --

    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "lock"
        description: "Lock session"
        onPressed: root.lockSession()
    }

    GlobalShortcut {
        name: "logout"
        description: "Log out"
        onPressed: logoutDialog.open()
    }

    GlobalShortcut {
        name: "switcher-next"
        description: "Window switcher: next"
        onPressed: switcher.next()
    }

    GlobalShortcut {
        name: "switcher-prev"
        description: "Window switcher: previous"
        onPressed: switcher.prev()
    }

    ConfirmDialog {
        id: logoutDialog
        title: "Log out?"
        body: "Are you sure you want to log out?"
        actionLabel: "Log out"
        icon: Icons.logout
        onConfirmed: Hyprland.dispatch("exec hyprshutdown -p 'uwsm stop'")
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    PolkitAgent {
        id: polkitAgent
    }

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
            lockSession: root.lockSession
        }
    }

    NotificationOverlay {
        notificationModel: notifServer.trackedNotifications
    }

    PolkitDialog {
        agent: polkitAgent
    }

    Switcher {
        id: switcher
    }

    ScreencopyPrewarm {}
}
