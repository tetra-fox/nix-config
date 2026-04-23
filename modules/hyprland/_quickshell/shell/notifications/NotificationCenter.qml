pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: root

    required property var notificationModel

    readonly property int count: notificationModel?.values?.length ?? 0

    contentWidth: 380
    contentHeight: column.implicitHeight + Theme.pillHPad * 2
    animateSize: true

    function clearAll(): void {
        const notifs = [...root.notificationModel.values];
        for (const n of notifs)
            n.dismiss();
    }

    ColumnLayout {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.pillHPad
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.count > 0 ? `Notifications (${root.count})` : "Notifications"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }

            InlineButton {
                text: "Clear all"
                accentColor: Theme.colorRed
                visible: root.count > 0
                onClicked: root.clearAll()
            }
        }

        Separator {
            visible: root.count > 0
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: Theme.textInactive
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
            visible: root.count === 0
        }

        ScrollableList {
            Layout.fillWidth: true
            maxHeight: 400
            spacing: 6
            visible: root.count > 0

            Repeater {
                model: root.notificationModel

                NotificationCenterItem {
                    required property Notification modelData
                    width: parent.width    // qmllint disable unqualified
                    notif: modelData
                }
            }
        }
    }
}
