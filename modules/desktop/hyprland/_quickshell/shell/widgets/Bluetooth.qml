pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

BarPopupButton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    function deviceLabel(d): string {
        return d.name || d.deviceName || d.address;
    }

    // reading connected/paired/name here subscribes to them, so any device change re-sorts
    readonly property var _sortedDevices: root.adapter?.devices.values.slice().sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b))) ?? [] // qmllint disable unresolved-type
    readonly property var connectedDevices: _sortedDevices.filter(d => d.connected)
    readonly property var pairedDevices: _sortedDevices.filter(d => d.paired && !d.connected)
    readonly property var availableDevices: _sortedDevices.filter(d => !d.paired && !d.connected && (d.name || d.deviceName))

    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property var connectingDevice: {
        if (!adapter)
            return null;
        return adapter.devices.values.find(d => d.state === BluetoothDeviceState.Connecting) ?? null; // qmllint disable unresolved-type
    }

    // recomputed from popup and accordion state, not toggled per edge, so reopening
    // with the accordion already expanded still scans
    function _updateDiscovery(): void {
        if (root.adapter)
            root.adapter.discovering = availableAccordion.expanded && root.popupVisible && root.powered;
    }

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

    onPopupVisibleChanged: {
        // not bound: Accordion's header writes expanded, which would destroy a binding
        if (popupVisible) {
            pairedAccordion.expanded = root.connectedDevice === null;
            availableAccordion.expanded = root.connectedDevice === null && root.pairedDevices.length === 0;
        }
        root._updateDiscovery();
    }

    RowLayout {
        Layout.fillWidth: true

        SectionLabel {
            text: "Bluetooth"
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
        icon: root.connectedDevice ? Icons.bluetoothConnected : root.scanning ? scanCycle.frame : Icons.bluetooth
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

        IconCycle {
            id: scanCycle
            frames: [Icons.bluetoothSearching, Icons.bluetooth]
            running: root.scanning && !root.connectedDevice
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
    }

    Separator {
        visible: root.powered
    }

    Accordion {
        id: pairedAccordion
        visible: root.powered && root.pairedDevices.length > 0
        label: "Paired devices"
        value: root.pairedDevices.length + ""

        ScrollableList {
            width: parent.width
            maxItems: 6

            Repeater {
                // ScriptModel diffs by identity, only added/removed rows rebuild
                model: ScriptModel {
                    values: root.pairedDevices
                }

                SelectableItem {
                    id: pairedItem
                    required property var modelData
                    required property int index
                    width: parent?.width ?? 0
                    text: root.deviceLabel(modelData)
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

        onExpandedChanged: root._updateDiscovery()

        ScrollableList {
            width: parent.width
            maxItems: 6

            Repeater {
                model: ScriptModel {
                    values: root.availableDevices
                }

                SelectableItem {
                    required property var modelData
                    required property int index
                    width: parent?.width ?? 0
                    text: root.deviceLabel(modelData)
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
            Quickshell.execDetached(["app2unit", "--", "overskride"]);
            root.popupVisible = false;
        }
    }
}
