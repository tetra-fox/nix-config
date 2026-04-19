pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

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

    // ── adapter ──────────────────────────────────────────────────────────────
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    // ── device lists (imperatively refreshed) ────────────────────────────────
    property var connectedDevices: []
    property var pairedDevices: []
    property var availableDevices: []

    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property var connectingDevice: {
        if (!adapter)
            return null;
        return adapter.devices.values.find(d => d.state === BluetoothDeviceState.Connecting) ?? null;
    }

    function refreshDevices() {
        if (!root.adapter) {
            root.connectedDevices = [];
            root.pairedDevices = [];
            root.availableDevices = [];
            return;
        }
        const all = root.adapter.devices.values.slice();
        root.connectedDevices = all.filter(d => d.connected).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        root.pairedDevices = all.filter(d => d.paired && !d.connected).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        root.availableDevices = all.filter(d => !d.paired && !d.connected && (d.name || d.deviceName)).sort((a, b) => (a.name || a.deviceName || "").localeCompare(b.name || b.deviceName || ""));
    }

    Connections {
        target: root.adapter?.devices ?? null
        function onCountChanged() {
            root.refreshDevices();
        }
    }

    Timer {
        interval: 2000
        running: root.scanning
        repeat: true
        onTriggered: root.refreshDevices()
    }

    onPoweredChanged: refreshDevices()

    Component.onCompleted: refreshDevices()

    // ── bar button ───────────────────────────────────────────────────────────
    IconButton {
        id: btn
        icon: {
            if (!root.powered)
                return icons.bluetoothDisabled;
            if (root.connectedDevice)
                return icons.bluetoothConnected;
            if (root.scanning)
                return icons.bluetoothSearching;
            return icons.bluetooth;
        }
        iconColor: root.powered ? theme.textPrimary : theme.textInactive
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    // ── popup ────────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup
        panelWindow: root.panelWindow

        contentWidth: 320
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        onVisibleChanged: {
            if (visible) {
                root.refreshDevices();
            } else if (root.adapter) {
                root.adapter.discovering = false;
            }
        }

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: theme.pillHPad
            }
            spacing: 10

            // ── power toggle ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bluetooth"
                    color: theme.textLabel
                    font.pixelSize: theme.fontSm
                    font.family: theme.fontFamily
                    Layout.fillWidth: true
                }

                ToggleSwitch {
                    checked: root.powered
                    onToggled: {
                        if (root.adapter)
                            root.adapter.enabled = !root.powered;
                    }
                }
            }

            // ── header ───────────────────────────────────────────────────
            Header {
                visible: root.powered
                icon: root.connectedDevice ? icons.bluetoothConnected : root.scanning ? scanFrames[scanIndex] : icons.bluetooth
                iconColor: root.connectedDevice ? theme.textPrimary : theme.textInactive
                title: root.connectedDevice ? root.connectedDevice.name : root.connectingDevice ? root.connectingDevice.name : (root.adapter?.name ?? "Bluetooth")
                subtitle: root.connectedDevice ? root.connectedDevice.address : ""
                badgeVisible: true
                badgeActive: root.connectedDevice !== null
                badgePulsing: root.connectingDevice !== null && !root.connectedDevice
                badgeColor: {
                    if (root.connectedDevice)
                        return theme.colorGreen;
                    if (root.connectingDevice)
                        return theme.colorYellow;
                    return theme.colorRed;
                }
                badgeText: {
                    if (root.connectedDevice) {
                        let t = "Connected";
                        if (root.connectedDevice.batteryAvailable)
                            t += " \u00b7 " + Math.round(root.connectedDevice.battery * 100) + "%";
                        return t;
                    }
                    if (root.connectingDevice)
                        return "Connecting";
                    return "Disconnected";
                }

                property var scanFrames: [icons.bluetoothSearching, icons.bluetooth]
                property int scanIndex: 0

                Timer {
                    running: root.scanning && !root.connectedDevice
                    interval: 600
                    repeat: true
                    onRunningChanged: if (!running)
                        parent.scanIndex = 0
                    onTriggered: parent.scanIndex = (parent.scanIndex + 1) % parent.scanFrames.length
                }
            }

            // ── action buttons (connected) ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: root.connectedDevice !== null
                spacing: 8

                InlineButton {
                    text: "Disconnect"
                    onClicked: root.connectedDevice?.disconnect()
                }

                InlineButton {
                    text: "Forget"
                    accentColor: theme.colorRed
                    onClicked: {
                        const dev = root.connectedDevice;
                        if (!dev)
                            return;
                        dev.disconnect();
                        dev.forget();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Separator {
                visible: root.powered
            }

            // ── paired devices ───────────────────────────────────────────
            Accordion {
                visible: root.powered && root.pairedDevices.length > 0
                label: "Paired devices"
                expanded: root.connectedDevice === null
                value: root.pairedDevices.length + ""

                ScrollableList {
                    width: parent.width
                    maxItems: 6

                    Repeater {
                        model: root.pairedDevices

                        SelectableItem {
                            id: pairedItem
                            required property var modelData
                            required property int index
                            width: parent?.width ?? 0
                            text: modelData.name || modelData.deviceName || modelData.address
                            active: modelData.state === BluetoothDeviceState.Connecting
                            showSeparator: index > 0
                            onSelected: modelData.connected = true

                            InlineButton {
                                text: "Forget"
                                accentColor: theme.colorRed
                                onClicked: pairedItem.modelData.forget()
                            }
                        }
                    }
                }
            }

            // ── available devices ────────────────────────────────────────
            Accordion {
                id: availableAccordion
                visible: root.powered
                label: "Available devices"
                loading: root.scanning
                expanded: root.connectedDevice === null && root.pairedDevices.length === 0

                onExpandedChanged: {
                    if (!root.adapter)
                        return;
                    root.adapter.discovering = expanded && popup.visible && root.powered;
                }

                ScrollableList {
                    width: parent.width
                    maxItems: 6

                    Repeater {
                        model: root.availableDevices

                        SelectableItem {
                            required property var modelData
                            required property int index
                            width: parent?.width ?? 0
                            text: modelData.name || modelData.deviceName || modelData.address
                            active: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                            showSeparator: index > 0
                            onSelected: {
                                if (!modelData.paired)
                                    modelData.pair();
                                else
                                    modelData.connected = true;
                            }
                        }
                    }
                }
            }

            Separator {
                visible: root.powered
            }

            MenuItem {
                Layout.fillWidth: true
                visible: root.powered
                text: "More settings..."
                onClicked: {
                    launcher.running = true;
                    popup.visible = false;
                }
            }
        }
    }

    BufferedProcess {
        id: launcher
        command: ["blueman-manager"]
    }
}
