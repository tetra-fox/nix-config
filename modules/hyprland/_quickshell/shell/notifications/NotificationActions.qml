pragma ComponentBehavior: Bound
import qs.lib

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property Notification notif

    visible: (root.notif?.actions?.length ?? 0) > 0    // qmllint disable unresolved-type
    spacing: 6

    Repeater {
        model: root.notif?.actions ?? null    // qmllint disable unresolved-type

        Rectangle {
            id: actionBtn
            required property NotificationAction modelData

            Layout.fillWidth: true
            implicitHeight: Theme.popupItemHeight - 6
            radius: Theme.radiusMd
            color: actionArea.pressed ? Theme.pressedBg : actionArea.containsMouse ? Theme.hoverBg : Theme.withAlpha(Theme.hoverBg, 0)
            border.width: 1
            border.color: Theme.panelBorder
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                    easing.type: Easing.OutQuad
                }
            }

            IconImage {
                anchors.centerIn: parent
                visible: root.notif?.hasActionIcons ?? false    // qmllint disable unresolved-type
                source: visible ? Quickshell.iconPath(actionBtn.modelData.identifier) : ""
                asynchronous: true
                implicitSize: Theme.fontIcon
            }

            Text {
                anchors.centerIn: parent
                visible: !(root.notif?.hasActionIcons ?? false)    // qmllint disable unresolved-type
                text: actionBtn.modelData?.text ?? ""
                color: Theme.textPrimary
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
            }

            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: actionBtn.modelData.invoke()
            }
        }
    }
}
