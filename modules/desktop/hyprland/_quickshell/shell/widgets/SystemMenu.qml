import qs.components
import qs.dialogs
import qs.widgets.system
import qs.lib
import QtQuick
import QtQuick.Layouts

BarPopupButton {
    id: root

    required property var lockSession

    icon: Icons.systemMenu

    SystemData {
        id: sysData
        active: root.popupVisible
    }

    ConfirmDialog {
        id: dialog
        property string pendingCmd: ""
        onConfirmed: Power.session(pendingCmd)
    }

    function confirm(title, body, actionLabel, cmd, icon) {
        root.popupVisible = false;
        dialog.title = title;
        dialog.body = body;
        dialog.actionLabel = actionLabel;
        dialog.icon = icon;
        dialog.pendingCmd = cmd;
        dialog.open();
    }

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
            root.popupVisible = false;
            root.lockSession(); // qmllint disable use-proper-function
        }
        onConfirmRequested: (title, body, actionLabel, cmd, icon) => root.confirm(title, body, actionLabel, cmd, icon)
    }
}
