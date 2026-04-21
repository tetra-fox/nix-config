import qs.theme
import Quickshell.Wayland
import QtQuick

Text {
    id: root

    property var screen

    // remember last focused toplevel on this screen so we don't blank
    // when focus moves to a different monitor
    property var lastToplevel: null

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (t && t.screens.includes(root.screen)) // qmllint disable unresolved-type
                root.lastToplevel = t;
        }
    }

    readonly property var toplevel: {
        const t = ToplevelManager.activeToplevel;
        if (t?.screens.includes(screen)) // qmllint disable unresolved-type
            return t;
        // fall back to last known toplevel on this screen
        if (lastToplevel?.screens.includes(screen))
            return lastToplevel;
        return null;
    }

    readonly property string title: Apps.name(toplevel?.appId ?? "")

    text: title
    visible: title.length > 0

    color: Theme.textPrimary
    font.pixelSize: Theme.fontMd
    font.family: Theme.fontFamily

    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
