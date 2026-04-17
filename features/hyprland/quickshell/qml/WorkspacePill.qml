import Quickshell
import Quickshell.Hyprland
import QtQuick

// single workspace pill. accent when focused, red when urgent
Rectangle {
    id: root

    Theme { id: theme }

    required property var workspace

    readonly property bool focused: Hyprland.focusedWorkspace?.id === workspace.id
    readonly property bool urgent: workspace.lastIpcObject?.urgent ?? false

    implicitWidth: label.implicitWidth + 15
    implicitHeight: 19

    radius: theme.radiusSm

    color: {
        if (urgent)  return theme.danger
        if (focused) return theme.accent
        return theme.inactiveBg
    }

    Behavior on color {
        ColorAnimation { duration: theme.animNormal }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: workspace.name
        color: root.focused ? theme.textActive : theme.textInactive
        font.pixelSize: theme.fontMd
        font.family: theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("workspace " + root.workspace.id)
        cursorShape: Qt.PointingHandCursor
    }
}
