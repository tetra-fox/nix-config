pragma ComponentBehavior: Bound

import qs.components

import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// single notification card with urgency accent strip, auto-expire, and dismiss
Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    required property Notification notif

    readonly property color accentColor: {
        if (notif.urgency === NotificationUrgency.Critical)
            return theme.colorRed;
        if (notif.urgency === NotificationUrgency.Low)
            return theme.colorYellow;
        return theme.accent;
    }

    implicitWidth: 320
    implicitHeight: card.height
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: theme.animSlow
            easing.type: Easing.InOutQuad
        }
    }

    // -- enter animation --
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
                target: slideY
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
                target: slideY
                property: "x"
                to: 0
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
    }

    // -- exit --
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

    // -- auto-expire timer --
    Timer {
        id: expireTimer
        interval: {
            if (root.notif.expireTimeout > 0)
                return root.notif.expireTimeout * 1000;
            if (root.notif.urgency === NotificationUrgency.Critical)
                return 0;
            return 5000;
        }
        running: interval > 0 && !hoverArea.containsMouse && !root._closing
        repeat: false
        onTriggered: root.dismiss()
    }

    // -- card visual --
    Rectangle {
        id: card
        width: parent.width
        height: content.implicitHeight + theme.pillHPad * 2
        radius: theme.radiusLg
        color: theme.panelBg
        border.width: 1
        border.color: theme.panelBorder
        clip: true

        transform: Translate {
            id: slideY
            x: 0
        }
        transformOrigin: Item.Right

        // urgency accent strip
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: theme.radiusLg
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
                leftMargin: theme.pillHPad + 3  // after accent strip
                rightMargin: theme.pillHPad
                topMargin: theme.pillHPad
            }
            spacing: 4

            // header row: icon + summary + close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // fallback icon — shown when no image or image fails to load
                Text {
                    text: icons.notifications
                    color: root.accentColor
                    font.family: theme.fontIconFamily
                    font.pixelSize: theme.fontIconLg
                    visible: notifImage.status !== Image.Ready
                }

                // app/notification image
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
                    sourceSize.width: theme.fontIconLg
                    sourceSize.height: theme.fontIconLg
                    Layout.preferredWidth: theme.fontIconLg
                    Layout.preferredHeight: theme.fontIconLg
                }

                // summary
                Text {
                    Layout.fillWidth: true
                    text: root.notif.summary
                    color: theme.textActive
                    font.pixelSize: theme.fontBase
                    font.family: theme.fontFamily
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // close button
                Text {
                    text: icons.close
                    color: closeArea.containsMouse ? theme.textActive : theme.textInactive
                    font.family: theme.fontIconFamily
                    font.pixelSize: theme.fontIcon
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }
            }

            // app name
            Text {
                Layout.fillWidth: true
                text: root.notif.appName
                color: theme.textInactive
                font.pixelSize: theme.fontXs
                font.family: theme.fontFamily
                visible: root.notif.appName !== ""
            }

            // body
            Text {
                Layout.fillWidth: true
                text: root.notif.body
                color: theme.textSecondary
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                visible: root.notif.body !== ""
            }

            // action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.notif.actions.length > 0

                Repeater {
                    model: root.notif.actions

                    Rectangle {
                        id: actionBtn
                        required property NotificationAction modelData

                        Layout.fillWidth: true
                        implicitHeight: theme.popupItemHeight - 4
                        radius: theme.radiusMd
                        color: actionArea.pressed ? theme.pressedBg : actionArea.containsMouse ? theme.hoverBg : theme.withAlpha(theme.hoverBg, 0)
                        border.width: 1
                        border.color: theme.panelBorder
                        Behavior on color {
                            ColorAnimation {
                                duration: theme.animFast
                                easing.type: Easing.OutQuad
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: actionBtn.modelData.text
                            color: theme.textPrimary
                            font.pixelSize: theme.fontSm
                            font.family: theme.fontFamily
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
