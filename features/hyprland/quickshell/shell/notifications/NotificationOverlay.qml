pragma ComponentBehavior: Bound
import qs.theme

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property var notificationModel

    screen: Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    margins.top: 0    // qmllint disable missing-property unqualified unresolved-type
    margins.right: Theme.pillMargin    // qmllint disable missing-property unqualified
    // don't push other surfaces aside, just overlay on top
    exclusiveZone: 0

    implicitWidth: 320 + Theme.pillMargin * 2
    implicitHeight: notificationColumn.height + Theme.pillMargin * 2

    color: "transparent"

    visible: notificationModel.values.length > 0

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
            model: root.notificationModel

            NotificationCard {
                required property Notification modelData
                notif: modelData
            }
        }
    }
}
