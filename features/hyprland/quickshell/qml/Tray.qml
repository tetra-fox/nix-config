pragma ComponentBehavior: Bound

import Quickshell.Services.SystemTray
import QtQuick

// row of system tray icons
Row {
    id: root

    Theme {
        id: theme
    }

    property var panelWindow

    spacing: theme.traySpacing

    Repeater {
        model: SystemTray.items

        TrayIcon {
            id: trayIconDelegate
            required property var modelData
            item: trayIconDelegate.modelData
            panelWindow: root.panelWindow
        }
    }
}
