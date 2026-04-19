import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// overlay popup anchored to the bar - wraps layer-shell boilerplate and focus-grab
// set alignRight: false + horizontalMargin for left-anchored cases (e.g. tray menus)
PanelWindow { // qmllint disable uncreatable-type
    id: root

    Theme {
        id: theme
    }

    default property alias content: backdrop.data
    property var panelWindow
    property bool alignRight: true
    property real horizontalMargin: theme.pillMargin

    // contentHeight must be set by the caller (e.g. implicitHeight: col.implicitHeight + padding)
    // The window itself is oversized so the compositor never needs to resize it, eliminating jitter.
    property real contentWidth: 200
    property real contentHeight: 200

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    screen: panelWindow?.screen
    anchors.top: true
    anchors.right: alignRight
    anchors.left: !alignRight
    margins.top: 0    // qmllint disable missing-property unqualified unresolved-type
    margins.right: alignRight ? horizontalMargin : 0    // qmllint disable missing-property unqualified
    margins.left: alignRight ? 0 : horizontalMargin    // qmllint disable missing-property unqualified
    exclusiveZone: 0

    // Window is fixed at a generous max size — never resized by content changes.
    implicitWidth: contentWidth
    implicitHeight: (screen?.height ?? 1080) * 0.9

    visible: false
    color: "transparent"

    onVisibleChanged: if (visible)
        openAnim.restart()

    HyprlandFocusGrab {
        windows: root.panelWindow ? [root, root.panelWindow] : [root]
        active: root.visible
        onCleared: root.visible = false
    }

    // spring scale + slide down from bar on open; compositor handles fade
    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            PropertyAction {
                target: backdrop
                property: "scale"
                value: 0.82
            }
            PropertyAction {
                target: slideY
                property: "y"
                value: -16
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "scale"
                to: 1.0
                duration: 280
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: slideY
                property: "y"
                to: 0
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
    }

    Rectangle {
        id: backdrop
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        opacity: Hyprland.focusedMonitor === Hyprland.monitorFor(root.screen) ? 1.0 : theme.barInactiveOpacity
        Behavior on opacity {
            NumberAnimation {
                duration: theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }
        // Height driven by content, not window size. Animated here so the
        // compositor surface never resizes — only this rectangle grows/shrinks.
        height: root.contentHeight
        radius: theme.radiusLg
        color: theme.panelBg
        border.width: 1
        border.color: theme.panelBorder
        clip: true
        transformOrigin: Item.Top
        transform: Translate {
            id: slideY
            y: 0
        }
    }
}
