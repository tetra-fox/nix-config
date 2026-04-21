import qs.theme
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var screen

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.workspacePillSpacing

        Repeater {
            model: Hyprland.workspaces.values.filter(ws => ws.monitor?.name === root.screen.name).sort((a, b) => a.id - b.id)

            delegate: WorkspacePill {
                required property var modelData
                workspace: modelData
            }
        }
    }
}
