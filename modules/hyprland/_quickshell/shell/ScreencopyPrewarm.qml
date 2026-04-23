import Quickshell
import Quickshell.Wayland
import QtQuick

// prewarms screencopy buffer manager from a proxied window
// the lock surface can't init it on its own, so its screencopy would silently fail
PanelWindow {
    // qmllint disable uncreatable-type
    anchors {
        top: true
        left: true
    }
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"

    WlrLayershell.namespace: "quickshell-screencopy-prewarm"
    WlrLayershell.exclusiveZone: 0

    ScreencopyView {
        visible: false
        anchors.fill: parent
    }
}
