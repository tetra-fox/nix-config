import Quickshell
import Quickshell.Hyprland
import QtQuick

Text {
    id: root

    Theme { id: theme }

    property var screen

    readonly property var monitor: Hyprland.monitorFor(screen)

    property var lastToplevel: null

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel
            if (t && t.monitor === root.monitor)
                root.lastToplevel = t
        }
    }

    readonly property var toplevel: {
        const t = Hyprland.activeToplevel
        if (t?.monitor === monitor) return t
        if (lastToplevel?.workspace === monitor?.activeWorkspace) return lastToplevel
        return null
    }

    readonly property string title: toplevel?.lastIpcObject?.initialTitle ?? toplevel?.lastIpcObject?.class ?? ""

    text: title
    visible: title.length > 0

    color: theme.textPrimary
    font.pixelSize: theme.fontMd
    font.family: theme.fontFamily

    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
