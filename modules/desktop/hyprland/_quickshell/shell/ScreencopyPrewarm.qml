import Quickshell
import Quickshell.Wayland
import QtQuick

// the lock surface can't init the screencopy buffer manager itself, its screencopy would silently fail
PanelWindow { // qmllint disable uncreatable-type
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
