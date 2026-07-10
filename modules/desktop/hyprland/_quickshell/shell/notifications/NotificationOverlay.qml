pragma ComponentBehavior: Bound
import qs.lib

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property var notifList

    // deliberately pinned to one monitor; popups following focus was considered
    // and rejected
    screen: Quickshell.screens[0]

    WlrLayershell.namespace: "quickshell-notifications"

    anchors.top: true
    anchors.right: true
    margins.right: Theme.pillMargin    // qmllint disable unqualified unresolved-type
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
