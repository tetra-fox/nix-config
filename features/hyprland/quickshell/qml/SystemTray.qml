import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

/// Row of system tray icons. Requires a reference to the containing PanelWindow
/// so QsMenuAnchor can position context menus correctly.
Row {
    id: root

    property var panelWindow

    spacing: 6

    Repeater {
        model: SystemTray.items

        TrayIcon {
            required property var modelData
            item: modelData
            panelWindow: root.panelWindow
        }
    }
}
