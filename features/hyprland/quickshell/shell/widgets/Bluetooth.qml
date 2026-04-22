pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    property var connectedDevices: []
    property var pairedDevices: []
    property var availableDevices: []

    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property var connectingDevice: {
        if (!adapter)
            return null;
        return adapter.devices.values.find(d => d.state === BluetoothDeviceState.Connecting) ?? null; // qmllint disable unresolved-type
    }

    function refreshDevices() {
        if (!root.adapter) {
            root.connectedDevices = [];
            root.pairedDevices = [];
            root.availableDevices = [];
            return;
        }
        const all = root.adapter.devices.values.slice(); // qmllint disable unresolved-type
        const byName = (a, b) => (a.name || a.deviceName || "").localeCompare(b.name || b.deviceName || "");
        root.connectedDevices = all.filter(d => d.connected).sort(byName);
        root.pairedDevices = all.filter(d => d.paired && !d.connected).sort(byName);
        root.availableDevices = all.filter(d => !d.paired && !d.connected && (d.name || d.deviceName)).sort(byName);
    }

    Connections {
        target: root.adapter?.devices ?? null // qmllint disable unresolved-type
        function onCountChanged() {
            root.refreshDevices();
        }
    }

    // dbus doesn't signal individual device property changes during discovery,
    // so poll while scanning to pick up new/changed devices
    Timer {
        interval: 2000
        running: root.scanning
        repeat: true
        onTriggered: root.refreshDevices()
    }

    onPoweredChanged: refreshDevices()

    Component.onCompleted: refreshDevices()

    IconButton {
        id: btn
        icon: {
            if (!root.powered)
                return Icons.bluetoothDisabled;
            if (root.connectedDevice)
                return Icons.bluetoothConnected;
            if (root.scanning)
                return Icons.bluetoothSearching;
            return Icons.bluetooth;
        }
        iconColor: root.powered ? Theme.textPrimary : Theme.textInactive
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 320
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        onVisibleChanged: {
            if (visible) {
                root.refreshDevices();
            } else if (root.adapter) {
                // stop scanning when popup closes to save power
                root.adapter.discovering = false;
            }
        }

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bluetooth"
                    color: Theme.textLabel
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.fontFamily
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

            Header {
                visible: root.powered
                icon: root.connectedDevice ? Icons.bluetoothConnected : root.scanning ? scanFrames[scanIndex] : Icons.bluetooth
                iconColor: root.connectedDevice ? Theme.textPrimary : Theme.textInactive
                title: {
                    if (root.connectedDevice)
                        return root.connectedDevice.name;
                    if (root.connectingDevice)
                        return root.connectingDevice.name;
                    return root.adapter?.name ?? "Bluetooth";
                }
                subtitle: root.connectedDevice ? root.connectedDevice.address : ""
                badgeVisible: true
                badgeActive: root.connectedDevice !== null
                badgePulsing: root.connectingDevice !== null && !root.connectedDevice
                badgeColor: {
                    if (root.connectedDevice)
                        return Theme.colorGreen;
                    if (root.connectingDevice)
                        return Theme.colorYellow;
                    return Theme.colorRed;
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

                property var scanFrames: [Icons.bluetoothSearching, Icons.bluetooth]
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
                    accentColor: Theme.colorRed
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
                                accentColor: Theme.colorRed
                                onClicked: pairedItem.modelData.forget()
                            }
                        }
                    }
                }
            }

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
                    Hyprland.dispatch("exec app2unit -- overskride");
                    popup.visible = false;
                }
            }
        }
    }
}
