pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import qs.widgets.media

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// volume slider + device selector for one audio direction
ColumnLayout {
    id: root

    property string label
    property string icon
    property list<PwNode> devices
    property PwNode activeDevice

    signal selectDevice(PwNode d)

    spacing: 14

    VolumeSlider {
        node: root.activeDevice
        compact: false
        icon: root.icon
    }

    Accordion {
        id: deviceSelector
        Layout.fillWidth: true
        label: root.label
        value: root.activeDevice ? (root.activeDevice.description || root.activeDevice.nickname || root.activeDevice.name) : "-"

        ScrollableList {
            width: parent.width
            maxItems: 5

            Repeater {
                model: root.devices

                delegate: SelectableItem {
                    required property PwNode modelData
                    required property int index

                    width: parent.width
                    text: modelData.description || modelData.nickname || modelData.name
                    active: modelData === root.activeDevice
                    showSeparator: index > 0
                    onSelected: {
                        root.selectDevice(modelData);
                        deviceSelector.expanded = false;
                    }
                }
            }
        }
    }
}
