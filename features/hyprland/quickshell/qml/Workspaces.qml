import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// workspace pills for one screen
Item {
    id: root

    Theme { id: theme }

    required property var screen

    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: theme.workspacePillSpacing

        Repeater {
            model: {
                const monitor = Hyprland.monitors.values.find(m => m.name === root.screen.name)
                return Hyprland.workspaces.values.filter(ws => monitor ? ws.monitor === monitor : true)
            }

            delegate: WorkspacePill {
                required property var modelData
                workspace: modelData
            }
        }
    }
}
