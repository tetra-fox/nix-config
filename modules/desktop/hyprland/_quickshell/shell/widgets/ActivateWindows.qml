pragma ComponentBehavior: Bound
import qs.lib

import Quickshell
import Quickshell.Wayland
import QtQuick

// fake "activate windows" watermark
Variants {
    model: Quickshell.screens

    PanelWindow { // qmllint disable uncreatable-type
        id: root

        property var modelData
        screen: modelData

        // above fullscreen apps, like the real thing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-activate-windows"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.bottom: true
        anchors.right: true
        // roughly the real watermark's inset at 1080p
        margins.bottom: 72    // qmllint disable unqualified unresolved-type
        margins.right: 72

        exclusiveZone: 0
        color: "transparent"

        visible: Theme.activateWindows    // qmllint disable unqualified

        // click-through
        mask: Region {}

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        // selawik is microsoft's free segoe ui clone. its faces are separate fontconfig
        // families and qt takes a single family name, so each face is named
        Column {
            id: column

            // translucent white, not grey, so it reads over any wallpaper
            Text {
                text: "Activate Windows"
                color: Theme.white
                opacity: 0.38
                font.family: "Selawik Semilight"
                font.pixelSize: 22
            }
            Text {
                text: "Go to Settings to activate Windows."
                color: Theme.white
                opacity: 0.44
                font.family: "Selawik"
                font.pixelSize: 15
            }
        }
    }
}
