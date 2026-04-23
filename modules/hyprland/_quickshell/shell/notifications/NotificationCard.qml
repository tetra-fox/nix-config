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

    // popup visibility (overlay only); flips false on timer expire so notif stays tracked for the center
    property bool _popupShown: true

    implicitWidth: 320
    implicitHeight: _popupShown ? card.height : 0
    opacity: _popupShown ? 1 : 0
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.InQuad
        }
    }

    Component.onCompleted: enterAnim.restart()

    SequentialAnimation {
        id: enterAnim
        ParallelAnimation {
            PropertyAction {
                target: card
                property: "scale"
                value: 0.82
            }
            PropertyAction {
                target: slideX
                property: "x"
                value: 16
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "scale"
                to: 1.0
                duration: 280
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: slideX
                property: "x"
                to: 0
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
    }

    // guard against double-dismiss (timer + click can race)
    property bool _closing: false
    function dismiss() {
        if (_closing)
            return;
        _closing = true;
        exitAnim.restart();
    }

    SequentialAnimation {
        id: exitAnim
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: root.notif.dismiss()
        }
    }

    Timer {
        id: expireTimer
        interval: {
            // expireTimeout is MILLISECONDS not SECONDS per dbus spec: >0 explicit, 0 never, -1 server default
            if (root.notif.expireTimeout > 0)
                return root.notif.expireTimeout;
            // critical notifs stay until manually dismissed (interval 0 = never fires)
            if (root.notif.urgency === NotificationUrgency.Critical)
                return 0;
            return 5000;
        }
        running: interval > 0 && !hoverArea.containsMouse && !root._closing && root._popupShown
        repeat: false
        // hide from overlay but keep tracked so it stays in the notification center
        onTriggered: root._popupShown = false
    }

    Rectangle {
        id: card
        width: parent.width
        height: content.implicitHeight + Theme.pillHPad * 2
        radius: Theme.radiusLg
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder
        clip: true

        transform: Translate {
            id: slideX
        }
        transformOrigin: Item.Right

        // accent strip
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: Theme.radiusLg
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
                leftMargin: Theme.pillHPad + 3  // clear accent strip
                rightMargin: Theme.pillHPad
                topMargin: Theme.pillHPad
            }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // fallback icon
                Text {
                    text: Icons.notifications
                    color: root.accentColor
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIconLg
                    visible: notifImage.status !== Image.Ready
                }

                Image {
                    id: notifImage
                    source: {
                        if (root.notif.image !== "")
                            return root.notif.image;
                        if (root.notif.appIcon !== "")
                            return root.notif.appIcon;
                        return "";
                    }
                    visible: status === Image.Ready
                    sourceSize.width: Theme.fontIconLg
                    sourceSize.height: Theme.fontIconLg
                    Layout.preferredWidth: Theme.fontIconLg
                    Layout.preferredHeight: Theme.fontIconLg
                }

                Text {
                    Layout.fillWidth: true
                    text: root.notif.summary
                    color: Theme.textActive
                    font.pixelSize: Theme.fontBase
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: Icons.close
                    color: closeArea.containsMouse ? Theme.textActive : Theme.textInactive
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        // extend hit area beyond the tiny icon glyph
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notif.appName
                color: Theme.textInactive
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
                visible: root.notif.appName !== ""
            }

            Text {
                Layout.fillWidth: true
                text: root.notif.body
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                visible: root.notif.body !== ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.notif.actions.length > 0 // qmllint disable unresolved-type

                Repeater {
                    model: root.notif.actions // qmllint disable unresolved-type

                    Rectangle {
                        id: actionBtn
                        required property NotificationAction modelData

                        Layout.fillWidth: true
                        implicitHeight: Theme.popupItemHeight - 4
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

                        Text {
                            anchors.centerIn: parent
                            text: actionBtn.modelData.text
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSm
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
        }
    }
}
