import qs.components
import qs.dialogs
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// clock — syncs to the nearest second boundary on init, then ticks every 1000ms
// click to open power menu
Item {
    id: root

    Theme {
        id: theme
    }

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // align to the next second boundary, then hand off to tickTimer
    Timer {
        id: syncTimer
        interval: {
            const sub = Date.now() % 1000;
            return sub === 0 ? 1000 : (1000 - sub);
        }
        running: true
        repeat: false
        onTriggered: {
            root.tick();
            tickTimer.running = true;
        }
    }

    Timer {
        id: tickTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: root.tick()
    }

    function tick() {
        timeTextProp.text = Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss");
    }

    // use a hit-target rect rather than IconButton since the clock is text not an icon
    Rectangle {
        id: btn
        implicitWidth: timeTextProp.implicitWidth + theme.iconPadH
        implicitHeight: timeTextProp.implicitHeight + theme.iconPadV
        radius: theme.radiusMd

        color: {
            if (area.pressed)
                return theme.pressedBg;
            if (popup.visible)
                return theme.openBg;
            if (area.containsMouse)
                return theme.hoverBg;
            return theme.withAlpha(theme.hoverBg, 0);
        }
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        Text {
            id: timeTextProp
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")
            color: theme.textPrimary
            font.pixelSize: theme.fontBase
            font.family: theme.fontFamily
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.visible = !popup.visible
        }
    }

    Process {
        id: proc
        running: false
        onExited: (code, status) => {
            running = false;
        }
    }

    function run(cmd) {
        proc.command = ["sh", "-c", cmd];
        proc.running = true;
    }

    function confirm(title, body, actionLabel, cmd) {
        popup.visible = false;
        dialog.title = title;
        dialog.body = body;
        dialog.actionLabel = actionLabel;
        dialog.pendingCmd = cmd;
        dialog.open();
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow

        contentWidth: 160
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                fill: parent
                margins: theme.pillHPad / 2
            }
            spacing: 0

            MenuItem {
                text: "  Log out"
                Layout.fillWidth: true
                onClicked: root.confirm("Log out?", "Are you sure you want to log out?", "Log out", "hyprshutdown -p 'uwsm stop'")
            }
            MenuItem {
                text: "  Reboot"
                Layout.fillWidth: true
                onClicked: root.confirm("Reboot?", "Are you sure you want to reboot?", "Reboot", "hyprshutdown -p 'uwsm stop; systemctl reboot'")
            }
            MenuItem {
                text: "  Shut down"
                Layout.fillWidth: true
                onClicked: root.confirm("Shut down?", "Are you sure you want to shut down?", "Shut down", "hyprshutdown -p 'uwsm stop; systemctl poweroff'")
            }
        }
    }

    ConfirmDialog {
        id: dialog
        property string pendingCmd: ""
        onConfirmed: root.run(pendingCmd)
    }
}
