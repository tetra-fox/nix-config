import qs.theme
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// bar popup — layer-shell overlay with focus-grab
PanelWindow { // qmllint disable uncreatable-type
    id: root

    default property alias content: backdrop.data
    property var panelWindow
    property Item anchorItem: null

    property real contentWidth: 200
    property real contentHeight: 200
    property bool animateSize: false

    property real _margin: Theme.pillMargin

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    screen: panelWindow?.screen
    anchors.top: true
    anchors.left: true
    margins.top: 0    // qmllint disable missing-property unqualified unresolved-type
    margins.left: _margin    // qmllint disable missing-property unqualified
    exclusiveZone: 0

    implicitWidth: contentWidth
    // oversized so compositor never resizes — no jitter
    implicitHeight: (screen?.height ?? 1080) * 0.9

    // restrict input to the visible backdrop so the transparent area doesn't steal clicks
    // (can't use item: backdrop — mapToScene bakes in the open animation's scale/translate
    // and Region doesn't re-evaluate when transforms change, so the mask stays undersized)
    mask: Region {
        width: root.contentWidth
        height: root.contentHeight
    }

    visible: false
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            return;
        if (root.anchorItem && root.panelWindow) {
            const mapped = root.anchorItem.mapToItem(root.panelWindow.contentItem, 0, 0);
            const screenW = root.screen?.width ?? 1920;
            root._margin = Math.max(Theme.pillMargin, Math.min(mapped.x, screenW - root.contentWidth - Theme.pillMargin));
        }
        openAnim.restart();
    }

    HyprlandFocusGrab {
        // qmllint disable unresolved-type
        windows: root.panelWindow ? [root, root.panelWindow] : [root]
        active: root.visible
        onCleared: root.visible = false
    }

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
        opacity: Hyprland.focusedMonitor === Hyprland.monitorFor(root.screen) ? 1.0 : Theme.barInactiveOpacity
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }
        // content-driven height; animated so compositor surface stays fixed
        height: root.contentHeight
        Behavior on height {
            enabled: root.animateSize
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
        radius: Theme.radiusLg
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder
        clip: true
        transformOrigin: Item.Top
        transform: Translate {
            id: slideY
            y: 0
        }
    }
}
