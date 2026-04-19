import qs.components
import qs.dialogs
import qs.widgets.system
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// System menu — power button with system info dropdown.
Item {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    SystemData {
        id: sysData
        active: popup.visible
    }

    // ── bar button ──────────────────────────────────────────────────────────

    IconButton {
        id: btn
        icon: icons.systemMenu
        isOpen: popup.visible
        onClicked: popup.visible = !popup.visible
    }

    // ── confirm dialog ──────────────────────────────────────────────────────

    ConfirmDialog {
        id: dialog
        property string pendingCmd: ""
        onConfirmed: Hyprland.dispatch(pendingCmd)
    }

    function confirm(title, body, actionLabel, cmd, icon) {
        popup.visible = false;
        dialog.title = title;
        dialog.body = body;
        dialog.actionLabel = actionLabel;
        dialog.icon = icon;
        dialog.pendingCmd = cmd;
        dialog.open();
    }

    // ── popup ───────────────────────────────────────────────────────────────

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow

        contentWidth: 320
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: theme.pillHPad
            }
            spacing: 10

            SystemInfoSection {
                data: sysData
            }

            Separator {}

            HardwareSection {
                data: sysData
            }

            Separator {}

            SessionActions {
                onLockRequested: {
                    popup.visible = false;
                    Hyprland.dispatch("exec hyprlock");
                }
                onConfirmRequested: (title, body, actionLabel, cmd, icon) => root.confirm(title, body, actionLabel, cmd, icon)
            }
        }
    }
}
