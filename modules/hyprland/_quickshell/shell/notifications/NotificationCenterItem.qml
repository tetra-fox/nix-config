pragma ComponentBehavior: Bound
import qs.lib

import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Notification notif

    readonly property color accentColor: {
        if (notif.urgency === NotificationUrgency.Critical)
            return Theme.colorRed;
        if (notif.urgency === NotificationUrgency.Low)
            return Theme.colorYellow;
        return Theme.accent;
    }

    implicitHeight: card.height

    Rectangle {
        id: card
        width: parent.width
        height: content.implicitHeight + Theme.pillHPad
        radius: Theme.radiusMd
        color: hoverArea.containsMouse ? Theme.hoverBg : Theme.withAlpha(Theme.white, 0.04)
        border.width: 1
        border.color: Theme.panelBorder
        clip: true
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: root.accentColor
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Theme.pillHPad + 3
                rightMargin: Theme.pillHPad
                topMargin: Theme.pillHPad / 2
            }
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.notif.summary
                    color: Theme.textActive
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: root.notif.appName
                    color: Theme.textInactive
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontFamily
                    visible: root.notif.appName !== ""
                    elide: Text.ElideRight
                }

                Text {
                    text: Icons.close
                    color: closeArea.containsMouse ? Theme.textActive : Theme.textInactive
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontSm
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notif.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notif.body
                color: Theme.textSecondary
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: root.notif.body !== ""
            }
        }
    }
}
