import qs.components
import QtQuick

// bluetooth stub - TODO: wire up bluez/dbus and add a popup
Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    readonly property bool enabled: true
    readonly property bool connected: false

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    IconButton {
        id: btn
        icon: !root.enabled ? icons.bluetoothDisabled : icons.bluetooth
    }
}
