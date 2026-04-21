pragma ComponentBehavior: Bound
import qs.theme

import Quickshell.Hyprland
import QtQuick

Rectangle {
    id: root

    required property var workspace

    readonly property bool focused: Hyprland.focusedWorkspace?.id === workspace.id
    readonly property bool urgent: workspace.lastIpcObject?.urgent ?? false

    implicitWidth: label.implicitWidth + Theme.workspacePillHPad
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

    Text {
        id: label
        anchors.centerIn: parent
        text: root.workspace.name
        color: root.focused ? Theme.textActive : Theme.textInactive
        font.pixelSize: Theme.fontMd
        font.family: Theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("workspace " + root.workspace.id)
        cursorShape: Qt.PointingHandCursor
    }
}
