pragma ComponentBehavior: Bound

import qs.dialogs
import qs.lockscreen
import qs.notifications
import qs.switcher
import qs.lib

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    GlobalShortcut {
        name: "toggle-dnd"
        description: "Toggle do-not-disturb"
        onPressed: NotifState.toggleDnd()
    }

    GlobalShortcut {
        name: "clear-notifications"
        description: "Clear all notifications"
        onPressed: root.clearAllNotifs()
    }

    ConfirmDialog {
        id: logoutDialog
        title: "Log out?"
        body: "Are you sure you want to log out?"
        actionLabel: "Log out"
        icon: Icons.logout
        onConfirmed: Hyprland.dispatch("exec hyprshutdown -p 'uwsm stop'")
    }

    // wrappers attach per-notif metadata (receive time, popup-suppression) that Quickshell's Notification doesn't carry
    property var notifList: []

    readonly property bool inFullscreen: Hyprland.focusedWorkspace?.hasFullscreen ?? false    // qmllint disable unresolved-type
    readonly property bool popupsEnabled: !NotifState.dnd && !root.inFullscreen

    function clearAllNotifs(): void {
        const notifs = root.notifList.map(w => w.notif);
        for (const n of notifs)
            n.dismiss();
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            root.clearAllNotifs();
        }
        function isDndEnabled(): bool {
            return NotifState.dnd;
        }
        function toggleDnd(): void {
            NotifState.toggleDnd();
        }
        function enableDnd(): void {
            NotifState.enableDnd();
        }
        function disableDnd(): void {
            NotifState.disableDnd();
        }
    }

    Component {
        id: notifDataComp
        QtObject {
            property Notification notif
            property real time
            property bool popupSuppressed
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notification => {
            // transient + popup suppressed = drop entirely (don't persist to center either)
            if (notification.transient && !root.popupsEnabled)
                return;
            notification.tracked = true;
            const wrapper = notifDataComp.createObject(root, {
                "notif": notification,
                "time": Date.now(),
                "popupSuppressed": !root.popupsEnabled
            });
            root.notifList = [wrapper, ...root.notifList];
            // history cap; dismiss oldest overflow. closed handler will filter notifList in place.
            while (root.notifList.length > 100) {
                root.notifList[root.notifList.length - 1].notif.dismiss();
            }
            notification.closed.connect(function () {
                root.notifList = root.notifList.filter(w => w.notif !== notification);
                wrapper.destroy();
            });
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
            notifList: root.notifList
        }
    }

    NotificationOverlay {
        notifList: root.notifList
    }

    PolkitDialog {
        agent: polkitAgent
    }

    Switcher {
        id: switcher
    }

    ScreencopyPrewarm {}
}
