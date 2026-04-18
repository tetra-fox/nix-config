import QtQuick

// bluetooth stub - TODO: wire up bluez/dbus and add a popup
Item {
    id: root

    Theme {
        id: theme
    }

    readonly property bool enabled: true
    readonly property bool connected: false

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    BarButton {
        id: btn
        icon: !root.enabled ? "󰂲" : root.connected ? "󰂱" : "󰂯"
    }
}
