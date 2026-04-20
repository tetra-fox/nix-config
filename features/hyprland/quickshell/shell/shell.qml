import qs.components
import qs.dialogs
import qs.notifications

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit

// one bar per screen + single notification overlay + polkit agent
ShellRoot {

    Icons {
        id: icons
    }

    // ── global shortcuts ────────────────────────────────────────────────────

    GlobalShortcut {
        // qmllint disable unresolved-type
        name: "lock"
        description: "Lock session"
        onPressed: Hyprland.dispatch("exec hyprlock")
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
        }
    }

    NotificationOverlay {
        notificationModel: notifServer.trackedNotifications
    }

    PolkitDialog {
        agent: polkitAgent
    }
}
