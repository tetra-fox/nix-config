import qs.components
import Quickshell.Wayland
import QtQuick

Text {
    id: root

    Theme {
        id: theme
    }

    property var screen

    property var lastToplevel: null

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (t && t.screens.includes(root.screen))
                root.lastToplevel = t;
        }
    }

    readonly property var toplevel: {
        const t = ToplevelManager.activeToplevel;
        if (t?.screens.includes(screen))
            return t;
        if (lastToplevel?.screens.includes(screen))
            return lastToplevel;
        return null;
    }

    readonly property var titleOverrides: ({
            "1password": "1Password",
            "org.telegram.desktop": "Telegram",
            "com.usebottles.bottles": "Bottles"
        })

    readonly property string windowClass: toplevel?.appId ?? ""
    readonly property string title: titleOverrides[windowClass] ?? windowClass.charAt(0).toUpperCase() + windowClass.slice(1)

    text: title
    visible: title.length > 0

    color: theme.textPrimary
    font.pixelSize: theme.fontMd
    font.family: theme.fontFamily

    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
