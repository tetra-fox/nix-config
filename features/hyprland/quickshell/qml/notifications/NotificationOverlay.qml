pragma ComponentBehavior: Bound

import qs.components

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// notification overlay — anchored top-right on primary screen, below the bar
PanelWindow { // qmllint disable uncreatable-type
    id: root

    Theme {
        id: theme
    }

    required property var notificationModel

    screen: theme.primaryScreen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    margins.top: 0    // qmllint disable missing-property unqualified unresolved-type
    margins.right: theme.pillMargin    // qmllint disable missing-property unqualified
    exclusiveZone: 0

    implicitWidth: 320 + theme.pillMargin * 2
    implicitHeight: (root.screen?.height ?? 1080) * 0.9

    color: "transparent"

    visible: notificationModel.values.length > 0

    Column {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: theme.pillMargin
            rightMargin: theme.pillMargin
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
