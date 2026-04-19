import qs.components
import Quickshell.Hyprland
import QtQuick

Text {
    id: root

    Theme {
        id: theme
    }

    property var screen

    readonly property var monitor: Hyprland.monitorFor(screen)

    property var lastToplevel: null

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (t && t.monitor === root.monitor)
                root.lastToplevel = t;
        }
    }

    readonly property var toplevel: {
        const t = Hyprland.activeToplevel;
        if (t?.monitor === monitor)
            return t;
        if (lastToplevel?.workspace === monitor?.activeWorkspace)
            return lastToplevel;
        return null;
    }

    readonly property var titleOverrides: ({
            "discord": "Discord",
            "1password": "1Password",
            "org.telegram.desktop": "Telegram"
        })

    readonly property string windowClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: titleOverrides[windowClass] ?? toplevel?.lastIpcObject?.initialTitle ?? windowClass

    text: title
    visible: title.length > 0

    color: theme.textPrimary
    font.pixelSize: theme.fontMd
    font.family: theme.fontFamily

    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
