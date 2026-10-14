import qs.lib
import Quickshell.Wayland
import QtQuick

Text {
    id: root

    property var screen

    // so the bar doesn't blank when focus moves to another monitor
    property var lastToplevel: null

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (t && t.screens.includes(root.screen)) // qmllint disable unresolved-type
                root.lastToplevel = t;
        }
    }

    // or the bar keeps a closed window's name until focus returns to this screen
    Connections {
        target: root.lastToplevel
        function onClosed() {
            root.lastToplevel = null;
        }
    }

    readonly property var toplevel: {
        const t = ToplevelManager.activeToplevel;
        if (t?.screens.includes(screen)) // qmllint disable unresolved-type
            return t;
        if (lastToplevel?.screens.includes(screen))
            return lastToplevel;
        return null;
    }

    readonly property string title: {
        Apps.rev;
        return Apps.name(toplevel?.appId);
    }

    text: title
    visible: title.length > 0

    color: Theme.textPrimary
    font.pixelSize: Theme.fontMd
    font.family: Theme.fontFamily

    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
