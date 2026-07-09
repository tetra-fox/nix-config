pragma ComponentBehavior: Bound
import qs.lib

import Quickshell
import Quickshell.Wayland
import QtQuick

// fake "activate windows" watermark, bottom-right, click-through.
// one surface per screen so it shows wherever the cursor is.
Variants {
    model: Quickshell.screens

    PanelWindow { // qmllint disable uncreatable-type
        id: root

        property var modelData
        screen: modelData

        // overlay layer so it floats above fullscreen apps, like the real thing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-activate-windows"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.bottom: true
        anchors.right: true
        // the real watermark sits inset from the bottom-right, roughly this far at 1080p
        margins.bottom: 72    // qmllint disable unqualified unresolved-type
        margins.right: 72

        exclusiveZone: 0
        color: "transparent"

        visible: Theme.activateWindows    // qmllint disable unqualified

        // empty input region, all clicks pass through to whatever is underneath
        mask: Region {}

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        // segoe ui isn't free; selawik is microsoft's own metric-compatible clone, packaged
        // in modules/fonts. selawik ships semilight/regular as distinct fontconfig families,
        // and qt resolves a single family name here (not a css comma-list), so name each face
        Column {
            id: column

            // white-at-low-opacity rather than a fixed grey, so it reads correctly over
            // any wallpaper the way the real semi-transparent watermark does. both lines
            // sit at nearly the same faint level, heading only slightly bigger (~3:2)
            Text {
                text: "Activate Windows"
                color: "#ffffff"
                // heading is a touch more washed-out than the subtext on the real one.
                // semilight matches the thin segoe ui weight the real heading uses
                opacity: 0.38
                font.family: "Selawik Semilight"
                font.pixelSize: 22
            }
            Text {
                text: "Go to Settings to activate Windows."
                color: "#ffffff"
                opacity: 0.44
                font.family: "Selawik"
                font.pixelSize: 15
            }
        }
    }
}
