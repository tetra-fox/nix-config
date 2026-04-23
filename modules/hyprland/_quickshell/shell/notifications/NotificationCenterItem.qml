pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Notification notif
    required property real time

    property bool expanded: false
    property bool _dismissing: false

    readonly property color accentColor: {
        if (notif.urgency === NotificationUrgency.Critical)
            return Theme.colorRed;
        if (notif.urgency === NotificationUrgency.Low)
            return Theme.colorYellow;
        return Theme.accent;
    }

    implicitHeight: _dismissing ? 0 : card.height
    opacity: _dismissing ? 0 : 1
    scale: _dismissing ? 0.9 : 1
    transformOrigin: Item.Right
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    transform: Translate {
        id: slideOut
        x: root._dismissing ? 80 : 0
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }
    }

    function dismiss(): void {
        if (_dismissing)
            return;
        _dismissing = true;
        dismissTimer.restart();
    }

    function copyBody(): void {
        if (root.notif.body !== "")
            Quickshell.execDetached(["wl-copy", root.notif.body]);
    }

    function focusWindow(): void {
        const cls = root.notif.desktopEntry || root.notif.appName;
        if (cls)
            Hyprland.dispatch(`focuswindow class:${cls}`);    // qmllint disable unresolved-type
    }

    Timer {
        id: dismissTimer
        interval: 220
        onTriggered: root.notif.dismiss()
    }

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
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: (bodyText.truncated || root.expanded) ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.focusWindow();
                else if (bodyText.truncated || root.expanded)
                    root.expanded = !root.expanded;
            }
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
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                NotificationIcon {
                    notif: root.notif
                    accentColor: root.accentColor
                    size: Theme.fontIcon
                    Layout.preferredWidth: Theme.fontIcon
                    Layout.preferredHeight: Theme.fontIcon
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

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
                            text: Time.friendly(root.time)
                            color: Theme.textInactive
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontFamily
                        }

                        GlyphButton {
                            icon: Icons.contentCopy
                            iconSize: Theme.fontSm
                            visible: root.notif.body !== ""
                            onClicked: root.copyBody()
                        }

                        GlyphButton {
                            icon: Icons.close
                            iconSize: Theme.fontSm
                            onClicked: root.dismiss()
                        }
                    }

                    Text {
                        id: bodyText
                        Layout.fillWidth: true
                        text: root.notif.body
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                        // unlimited when expanded; 99 is effectively unlimited for any realistic body
                        maximumLineCount: root.expanded ? 99 : 2
                        elide: Text.ElideRight
                        textFormat: Text.AutoText
                        visible: root.notif.body !== ""
                    }
                }
            }

            NotificationActions {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.fontIcon + 8
                notif: root.notif
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.fontIcon + 8
                visible: root.notif?.hasInlineReply ?? false    // qmllint disable unresolved-type
                spacing: 6

                InputField {
                    id: replyInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    placeholderText: (root.notif?.inlineReplyPlaceholder ?? "") || "Reply…"    // qmllint disable unresolved-type

                    function submit(): void {
                        if (text === "")
                            return;
                        root.notif.sendInlineReply(text);
                        clear();
                        // most apps expect the notif to close after replying
                        root.notif.dismiss();
                    }

                    onAccepted: replyInput.submit()
                }

                GlyphButton {
                    icon: Icons.send
                    iconSize: Theme.fontIcon
                    baseColor: replyInput.text === "" ? Theme.textInactive : Theme.accent
                    hoverColor: replyInput.text === "" ? Theme.textInactive : Theme.textActive
                    onClicked: replyInput.submit()
                }
            }
        }
    }
}
