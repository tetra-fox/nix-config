import qs.components
import qs.lib
import Quickshell
import Quickshell.Wayland
import QtQuick

// the focus grab stays with each dialog, its lifecycle differs between them
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
