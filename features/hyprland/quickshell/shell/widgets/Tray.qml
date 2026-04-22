pragma ComponentBehavior: Bound
import qs.lib

import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root

    property var panelWindow

    spacing: Theme.buttonGap

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
