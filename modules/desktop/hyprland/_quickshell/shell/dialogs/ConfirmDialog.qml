import qs.components
import qs.lib
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

DialogSurface {
    id: root

    property string title: ""
    property string body: ""
    property string icon: ""
    property string actionLabel: "Confirm"
    property int countdown: 30
    // owned by open() and the countdown timer, not bound to countdown: both
    // write it imperatively, which would destroy a binding on the first open
    property int remaining: 0

    signal confirmed
    signal cancelled

    function open() {
        remaining = root.countdown;
        grabGuard.restart();
        visible = true;
    }

    // guard: key-release from shortcut can dismiss the grab immediately
    Timer {
        id: grabGuard
        interval: 150
    }

    // quickshell deactivates the grab after ANY clear, including the guarded
    // one from the triggering shortcut's key release, so bounce active through
    // false to re-arm it; writing the property directly would kill the binding
    property bool _grabRearm: false

    HyprlandFocusGrab {
        // qmllint disable unresolved-type
        windows: [root]
        active: root.visible && !root._grabRearm
        onCleared: {
            if (grabGuard.running) {
                root._grabRearm = true;
                Qt.callLater(() => root._grabRearm = false);
                return;
            }
            root.visible = false;
            root.cancelled();
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.visible
        // auto-confirm when countdown reaches 0 (e.g. logout proceeds if user walks away)
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0) {
                root.visible = false;
                root.confirmed();
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: Theme.textActive
            font.pixelSize: Theme.fontIconLg
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.textActive
            font.pixelSize: Theme.fontBase
            font.family: Theme.fontFamily
            font.weight: Font.Medium
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: Theme.iconPadV
        text: root.body
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSm
        font.family: Theme.fontFamily
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.pillHPad
        spacing: Theme.iconPadV

        DialogButton {
            Layout.fillWidth: true
            text: "Cancel"
            bordered: true
            onClicked: {
                root.visible = false;
                root.cancelled();
            }
        }

        DialogButton {
            Layout.fillWidth: true
            text: root.actionLabel + "  (" + root.remaining + ")"
            accentColor: Theme.danger
            onClicked: {
                root.visible = false;
                root.confirmed();
            }
        }
    }
}
