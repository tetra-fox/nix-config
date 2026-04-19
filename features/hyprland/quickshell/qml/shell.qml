import qs.dialogs
import qs.notifications

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit

// one bar per screen + single notification overlay + polkit agent
ShellRoot {

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
