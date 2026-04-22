import qs.components
import qs.dialogs
import qs.widgets.system
import qs.lib
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow
    required property var lockSession

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    SystemData {
        id: sysData
        active: popup.visible
    }

    IconButton {
        id: btn
        icon: Icons.systemMenu
        isOpen: popup.visible
        onClicked: popup.visible = !popup.visible
    }

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

    PopupWindow {
        id: popup
        anchorItem: btn
        panelWindow: root.panelWindow

        contentWidth: 320
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 10

            SystemInfoSection {
                sysData: sysData
            }

            Separator {}

            HardwareSection {
                sysData: sysData
            }

            Separator {}

            SessionActions {
                onLockRequested: {
                    popup.visible = false;
                    root.lockSession(); // qmllint disable use-proper-function
                }
                onConfirmRequested: (title, body, actionLabel, cmd, icon) => root.confirm(title, body, actionLabel, cmd, icon)
            }
        }
    }
}
