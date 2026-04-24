pragma ComponentBehavior: Bound
import qs.lib

import Quickshell.Hyprland
import QtQuick

Rectangle {
    id: root

    required property var workspace

    readonly property bool focused: Hyprland.focusedWorkspace?.id === workspace.id
    readonly property bool urgent: workspace.lastIpcObject?.urgent ?? false
    // cap at 3 so a hoarder workspace doesn't blow out the bar width
    readonly property int windowCount: Math.min(workspace.toplevels?.values?.length ?? 0, 3)

    implicitWidth: content.implicitWidth + Theme.workspacePillHPad
    implicitHeight: Theme.workspacePillHeight

    radius: Theme.radiusSm

    color: {
        if (urgent)
            return Theme.danger;
        if (focused)
            return Theme.accent;
        return Theme.inactiveBg;
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.animNormal
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.workspace.name
            color: root.focused ? Theme.textActive : Theme.textInactive
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.windowCount > 0
            spacing: 2

            Repeater {
                model: root.windowCount

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    anchors.verticalCenter: parent?.verticalCenter
                    color: root.focused ? Theme.textActive : Theme.textInactive
                    opacity: root.focused ? 0.7 : 0.5
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("workspace " + root.workspace.id)
        cursorShape: Qt.PointingHandCursor
    }
}
