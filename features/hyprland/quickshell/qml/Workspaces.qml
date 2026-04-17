import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// workspace pills for one screen. click to switch
Item {
    id: root

    // passed in from Bar.qml
    required property var screen

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Repeater {
            // filter to workspaces on this screen
            model: {
                const monitorWorkspaces = Hyprland.workspaces.values.filter(ws => {
                    const monitor = Hyprland.monitors.values.find(
                        m => m.name === root.screen.name
                    )
                    return monitor ? ws.monitor === monitor : true
                })
                return monitorWorkspaces
            }

            delegate: WorkspacePill {
                required property var modelData
                workspace: modelData
            }
        }
    }
}
