import qs.components
import qs.theme
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    signal lockRequested
    signal confirmRequested(string title, string body, string actionLabel, string cmd, string icon)

    Layout.fillWidth: true
    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MenuItem {
            text: "Lock"
            icon: Icons.lock
            shortcutHint: "Super+Esc"
            Layout.fillWidth: true
            onClicked: root.lockRequested()
        }

        MenuItem {
            text: "Log out"
            icon: Icons.logout
            shortcutHint: "Super+Shift+Esc"
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Log out?", "Are you sure you want to log out?", "Log out", "exec hyprshutdown -p 'uwsm stop'", Icons.logout)
        }
    }

    Separator {
        Layout.topMargin: 10
        Layout.bottomMargin: 10
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MenuItem {
            text: "Reboot"
            icon: Icons.restart
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Reboot?", "Are you sure you want to reboot?", "Reboot", "exec hyprshutdown -p 'uwsm stop; systemctl reboot'", Icons.restart)
        }

        MenuItem {
            text: "Shut down"
            icon: Icons.power
            textColor: Theme.danger
            Layout.fillWidth: true
            onClicked: root.confirmRequested("Shut down?", "Are you sure you want to shut down?", "Shut down", "exec hyprshutdown -p 'uwsm stop; systemctl poweroff'", Icons.power)
        }
    }
}
