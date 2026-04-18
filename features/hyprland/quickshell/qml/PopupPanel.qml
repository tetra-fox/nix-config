import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// overlay popup anchored to the bar - wraps layer-shell boilerplate and focus-grab
// set alignRight: false + horizontalMargin for left-anchored cases (e.g. tray menus)
PanelWindow {
    id: root

    Theme { id: theme }

    default property alias content: backdrop.data
    property var  panelWindow
    property bool alignRight:       true
    property real horizontalMargin: theme.pillMargin

    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"

    screen:        panelWindow?.screen
    anchors.top:   true
    anchors.right: alignRight
    anchors.left:  !alignRight
    margins.top:   0
    margins.right: alignRight ? horizontalMargin : 0
    margins.left:  alignRight ? 0 : horizontalMargin
    exclusiveZone: 0

    visible: false
    color:   "transparent"

    onVisibleChanged: if (visible) openAnim.restart()

    HyprlandFocusGrab {
        windows:   root.panelWindow ? [root, root.panelWindow] : [root]
        active:    root.visible
        onCleared: root.visible = false
    }

    // spring scale + slide down from bar on open; compositor handles fade
    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            PropertyAction  { target: backdrop; property: "scale"; value: 0.82 }
            PropertyAction  { target: slideY;   property: "y";     value: -16  }
        }
        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "scale"; to: 1.0; duration: 280; easing.type: Easing.OutExpo }
            NumberAnimation { target: slideY;   property: "y";     to: 0;   duration: 200; easing.type: Easing.OutExpo }
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill:    parent
        radius:          theme.radiusLg
        color:           theme.panelBg
        border.width:    1
        border.color:    theme.panelBorder
        clip:            true
        transformOrigin: Item.Top
        transform:       Translate { id: slideY; y: 0 }
    }
}
