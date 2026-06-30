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

    readonly property color accentColor: NotifState.urgencyColor(notif.urgency)
    readonly property string title: NotifState.title(notif)

    // whether a left-click can jump to the source (default action, or a window to raise)
    readonly property bool canActivate: {
        const hasDefault = (notif.actions ?? []).some(a => a.identifier === "default");
        return hasDefault || (notif.desktopEntry || notif.appName) !== "";
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
            duration: Theme.animSlow
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animSlow
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

    function focusWindow(): bool {
        const raw = root.notif.desktopEntry || root.notif.appName;
        // desktopEntry/appName are untrusted dbus Notify fields interpolated into a lua
        // long-bracket string that hyprland evaluates. strip the [[ ]] delimiters and
        // newlines so a hostile appName can't close the bracket early and inject lua.
        const cls = raw.replace(/\]\]|\[\[|[\r\n]/g, "");
        if (!cls)
            return false;
        Hyprland.dispatch(`hl.dsp.event([[focuswindow class:${cls}]])`);    // qmllint disable unresolved-type
        return true;
    }

    // left-click activation: invoke the spec default action (jump to the source,
    // e.g. discord opens the message), else raise the app window by class. dismiss
    // on success since the user has been taken to the source
    function activate(): void {
        if (NotifState.activate(root.notif) || root.focusWindow())
            root.dismiss();
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
            cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                // middle-click always raises the window, never jumps to the message
                if (mouse.button === Qt.MiddleButton)
                    root.focusWindow();
                else if (root.canActivate)
                    root.activate();
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
                            text: root.title
                            color: Theme.textActive
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: root.title !== ""
                        }

                        Text {
                            text: Time.friendly(root.time)
                            color: Theme.textInactive
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontFamily
                        }

                        GlyphButton {
                            icon: Icons.expandMore
                            iconSize: Theme.fontSm
                            // only offer expand when there's hidden text to reveal
                            visible: bodyText.truncated || root.expanded
                            rotation: root.expanded ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutQuad
                                }
                            }
                            onClicked: root.expanded = !root.expanded
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
                        text: NotifState.cleanBody(root.notif.body, root.notif.appName)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                        // unlimited when expanded; 99 is effectively unlimited for any realistic body
                        maximumLineCount: root.expanded ? 99 : 2
                        elide: Text.ElideRight
                        textFormat: Text.AutoText
                        visible: text !== ""
                        onLinkActivated: link => {
                            Quickshell.execDetached(["xdg-open", link]);
                            root.dismiss();
                        }
                    }
                }
            }

            NotificationActions {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.fontIcon + 8
                notif: root.notif
                onActionInvoked: if (!root.notif.resident)
                    root.dismiss()
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
                    placeholderText: (root.notif?.inlineReplyPlaceholder ?? "") || "Reply..."    // qmllint disable unresolved-type

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
