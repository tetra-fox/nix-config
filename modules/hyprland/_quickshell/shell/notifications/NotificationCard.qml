pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // wrapper carries the popup flag; flipping it false removes us from the overlay
    // while leaving the notif in the center
    required property var wrapper
    readonly property Notification notif: wrapper.notif

    readonly property color accentColor: NotifState.urgencyColor(notif.urgency)
    readonly property string title: NotifState.title(notif)
    // hide the appName subtitle when it's already used as the title to avoid duplication
    readonly property bool showAppNameSubtitle: notif.appName !== "" && notif.summary !== ""

    // _hiding drives the collapse+fade; _closing guards against double-trigger (timer + click)
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

    function dismiss() {
        if (_closing)
            return;
        _closing = true;
        _hiding = true;
        dismissTimer.start();
    }

    function hideAsPopup() {
        if (_closing)
            return;
        _closing = true;
        _hiding = true;
        hideTimer.start();
    }

    // wait for the collapse Behavior to finish before mutating state, otherwise the
    // delegate is destroyed mid-animation and the column snaps shut
    Timer {
        id: dismissTimer
        interval: Theme.animSlow + 30
        onTriggered: root.notif.dismiss()
    }

    Timer {
        id: hideTimer
        interval: Theme.animSlow + 30
        onTriggered: root.wrapper.popup = false
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
        running: interval > 0 && !cardHover.hovered && !root._closing
        repeat: false
        onTriggered: {
            // transient notifs shouldn't persist in the center; others just hide from overlay
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

        // accent strip
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: Theme.radiusLg
            color: root.accentColor
        }

        // HoverHandler tracks hover regardless of child MouseAreas (action buttons, close);
        // a plain MouseArea would lose hover the moment the cursor crosses a button
        HoverHandler {
            id: cardHover
        }

        // body click invokes the spec's "default" action and dismisses; child buttons (close,
        // actions) are above this in the QML tree so their MouseAreas take precedence.
        // hovered link takes priority over default action so <a> tags in markup-bodies work.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (bodyText.hoveredLink !== "") {
                    Quickshell.execDetached(["xdg-open", bodyText.hoveredLink]);
                    root.dismiss();
                    return;
                }
                const def = (root.notif.actions ?? []).find(a => a.identifier === "default");
                if (def)
                    def.invoke();
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
                    size: Theme.fontIconLg
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
                    iconSize: Theme.fontIcon
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
