import qs.components
import qs.lib
import Quickshell
import Quickshell.Wayland
import QtQuick

// overlay window hosting a centered DialogCard with the shared scale+fade
// open animation. the focus grab stays with the concrete dialogs; its
// lifecycle is the part that differs between them
PanelWindow { // qmllint disable uncreatable-type
    id: root

    default property alias content: card.content
    property alias cardWidth: card.width

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    implicitWidth: card.width
    implicitHeight: card.height

    visible: false
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            openAnim.restart();
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            PropertyAction {
                target: card
                property: "scale"
                value: Theme.dialogOpenScale
            }
            PropertyAction {
                target: card
                property: "opacity"
                value: 0
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "scale"
                to: 1.0
                duration: Theme.animDialogIn
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 1.0
                duration: Theme.animSettle
                easing.type: Easing.OutQuad
            }
        }
    }

    DialogCard {
        id: card
        anchors.centerIn: parent
    }
}
