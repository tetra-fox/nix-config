pragma ComponentBehavior: Bound
import qs.lib

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property var notifList

    screen: Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    margins.right: Theme.pillMargin    // qmllint disable missing-property unqualified
    // don't push other surfaces aside, just overlay on top
    exclusiveZone: 0

    implicitWidth: Theme.popupWidth + Theme.pillMargin * 2
    implicitHeight: notificationColumn.height + Theme.pillMargin * 2

    color: "transparent"

    visible: notifList.some(w => w.popup)

    Column {
        id: notificationColumn
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.pillMargin
            rightMargin: Theme.pillMargin
        }
        spacing: 8

        Repeater {
            // ScriptModel preserves delegate identity across array changes; a plain JS array
            // would have Repeater destroy+recreate every card on prepend, replaying enterAnim
            model: ScriptModel { // qmllint disable unresolved-type
                values: root.notifList.filter(w => w.popup)    // qmllint disable unqualified
            }

            NotificationCard {
                required property var modelData
                wrapper: modelData
            }
        }
    }
}
