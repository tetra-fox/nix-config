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

    // emitted after invoke() so the card/center item can dismiss the notif (unless resident)
    // per the dbus spec's implicit-close-after-action behavior
    signal actionInvoked

    // dbus spec: identifier "default" is invoked by clicking the notification body, never as a button.
    // also drop actions that would render blank (no text and no icon to show)
    readonly property var visibleActions: {
        const all = root.notif?.actions ?? [];    // qmllint disable unresolved-type
        const hasIcons = root.notif?.hasActionIcons ?? false;    // qmllint disable unresolved-type
        return all.filter(a => a.identifier !== "default" && (hasIcons || (a.text ?? "") !== ""));
    }

    visible: visibleActions.length > 0
    spacing: 6

    Repeater {
        model: root.visibleActions

        Rectangle {
            id: actionBtn
            required property NotificationAction modelData

            // show icon when available *and* it resolved; fall back to text otherwise
            readonly property bool useIcon: (root.notif?.hasActionIcons ?? false) && iconImg.status === Image.Ready    // qmllint disable unresolved-type

            Layout.fillWidth: true
            implicitHeight: Theme.popupItemHeight - 6
            radius: Theme.radiusMd
            color: Theme.stateBg(actionArea.pressed, false, actionArea.containsMouse)
            border.width: 1
            border.color: Theme.panelBorder
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                    easing.type: Easing.OutQuad
                }
            }

            IconImage {
                id: iconImg
                anchors.centerIn: parent
                visible: actionBtn.useIcon
                source: (root.notif?.hasActionIcons ?? false) ? Quickshell.iconPath(actionBtn.modelData.identifier, true) : ""    // qmllint disable unresolved-type
                asynchronous: true
                implicitSize: Theme.fontIcon
            }

            Text {
                anchors.centerIn: parent
                visible: !actionBtn.useIcon
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
                onClicked: {
                    actionBtn.modelData.invoke();
                    root.actionInvoked();
                }
            }
        }
    }
}
