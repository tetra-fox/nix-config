import qs.notifications

import Quickshell
import Quickshell.Services.Notifications

// one bar per screen + single notification overlay
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
}
