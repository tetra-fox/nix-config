import qs.components
import QtQuick
import QtQuick.Layouts

// Lock, Log out, Reboot, Shut down menu items.
ColumnLayout {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    signal lockRequested
    signal confirmRequested(string title, string body, string actionLabel, string cmd, string icon)

    Layout.fillWidth: true
    spacing: 0

    // ── session ──────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MenuItem {
            text: "Lock"
            icon: icons.lock
            shortcutHint: "Super+Esc"
            Layout.fillWidth: true
            onClicked: root.lockRequested()
        }

        MenuItem {
            text: "Log out"
            icon: icons.logout
            shortcutHint: "Super+Shift+Esc"
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Log out?", "Are you sure you want to log out?", "Log out", "exec hyprshutdown -p 'uwsm stop'", icons.logout)
        }
    }

    Separator {
        Layout.topMargin: 10
        Layout.bottomMargin: 10
    }

    // ── power ────────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MenuItem {
            text: "Reboot"
            icon: icons.restart
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Reboot?", "Are you sure you want to reboot?", "Reboot", "exec hyprshutdown -p 'uwsm stop; systemctl reboot'", icons.restart)
        }

        MenuItem {
            text: "Shut down"
            icon: icons.power
            textColor: theme.danger
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Shut down?", "Are you sure you want to shut down?", "Shut down", "exec hyprshutdown -p 'uwsm stop; systemctl poweroff'", icons.power)
        }
    }
}
