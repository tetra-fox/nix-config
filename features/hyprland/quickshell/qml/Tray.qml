import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// row of system tray icons
Row {
    id: root

    property var panelWindow

    spacing: 6

    Repeater {
        model: SystemTray.items

        TrayIcon {
            required property var modelData
            item:        modelData
            panelWindow: root.panelWindow
        }
    }
}
