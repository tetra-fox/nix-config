pragma ComponentBehavior: Bound
// self-import: tooling only sees the singleton flag in qmldir through a module import
import qs.notifications
import qs.components
import qs.lib

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var wrapper
    readonly property Notification notif: wrapper.notif

    readonly property color accentColor: NotifState.urgencyColor(notif.urgency)
    readonly property string title: NotifState.title(notif)
    readonly property bool showAppNameSubtitle: notif.appName !== "" && notif.summary !== ""

    // _closing stops the timer and a click both closing
    property bool _hiding: false
    property bool _closing: false

    implicitWidth: Theme.popupWidth
    implicitHeight: _hiding ? 0 : card.height
    opacity: _hiding ? 0 : 1
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animSlow
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
                value: Theme.popupOpenScale
            }
            PropertyAction {
                target: slideX
                property: "x"
                value: Theme.popupSlideOffset
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "scale"
                to: 1.0
                duration: Theme.animPopupIn
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: slideX
                property: "x"
                to: 0
                duration: Theme.animPopupSlide
                easing.type: Easing.OutExpo
            }
        }
    }

    property bool _dismissOnClose: false

    function dismiss() {
        if (_closing)
            return;
        _closing = true;
        _hiding = true;
        _dismissOnClose = true;
        closeTimer.start();
    }

    function hideAsPopup() {
        if (_closing)
            return;
        _closing = true;
        _hiding = true;
        _dismissOnClose = false;
        closeTimer.start();
    }

    // mutating state destroys the delegate, so wait out the collapse animation
    Timer {
        id: closeTimer
        interval: Theme.animSlow + 30
        onTriggered: {
            if (root._dismissOnClose)
                root.notif.dismiss();
            else
                root.wrapper.popup = false;
        }
    }

    Timer {
        id: expireTimer
        interval: {
            // milliseconds, not seconds: >0 explicit, 0 never, -1 server default
            if (root.notif.expireTimeout > 0)
                return root.notif.expireTimeout;
            if (root.notif.urgency === NotificationUrgency.Critical)
                return 0;
            return 5000;
        }
        running: interval > 0 && !cardHover.hovered && !root._closing
        onTriggered: {
            // transient notifs skip the center
            if (root.notif.transient)
                root.dismiss();
            else
                root.hideAsPopup();
        }
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

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: Theme.radiusLg
            color: root.accentColor
        }

        // a MouseArea would lose hover over the child buttons
        HoverHandler {
            id: cardHover
        }

        // a hovered link wins over the default action so <a> in bodies works
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (bodyText.hoveredLink !== "") {
                    Quickshell.execDetached(["xdg-open", bodyText.hoveredLink]);
                    root.dismiss();
                    return;
                }
                NotifState.activate(root.notif);
                root.dismiss();
            }
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

                NotificationIcon {
                    notif: root.notif
                    accentColor: root.accentColor

                    Layout.preferredWidth: Theme.fontIconLg
                    Layout.preferredHeight: Theme.fontIconLg
                }

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.textActive
                    font.pixelSize: Theme.fontBase
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.title !== ""
                }

                GlyphButton {
                    icon: Icons.close

                    onClicked: root.dismiss()
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notif.appName
                color: Theme.textInactive
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
                visible: root.showAppNameSubtitle
            }

            Text {
                id: bodyText
                Layout.fillWidth: true
                text: NotifState.cleanBody(root.notif.body, root.notif.appName)
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                visible: text !== ""
            }

            NotificationActions {
                Layout.fillWidth: true
                onActionInvoked: if (!root.notif.resident)
                    root.dismiss()
                notif: root.notif
            }
        }
    }
}
