pragma ComponentBehavior: Bound

import qs.components
import qs.dialogs
import qs.lockscreen
import qs.notifications

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit

// one bar per screen + session lock + notification overlay + polkit agent
ShellRoot {
    id: root

    Icons {
        id: icons
    }

    function lockSession() {
        sessionLock.locked = true;
    }

    // -- session lock --------------------------------------------------------

    WlSessionLock {
        id: sessionLock

        signal unlock

        surface: Component {
            LockSurface {
                lock: sessionLock
                pam: pam
            }
        }
    }

    Pam {
        id: pam
        lock: sessionLock
    }

    // -- global shortcuts ----------------------------------------------------

    GlobalShortcut {
        // qmllint disable unresolved-type
        name: "lock"
        description: "Lock session"
        onPressed: root.lockSession()
    }

    GlobalShortcut {
        // qmllint disable unresolved-type
        name: "logout"
        description: "Log out"
        onPressed: logoutDialog.open()
    }

    ConfirmDialog {
        id: logoutDialog
        title: "Log out?"
        body: "Are you sure you want to log out?"
        actionLabel: "Log out"
        icon: icons.logout
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
}
