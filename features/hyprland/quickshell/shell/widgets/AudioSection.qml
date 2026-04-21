pragma ComponentBehavior: Bound

import qs.components
import qs.theme

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// volume slider + device selector for one audio direction
ColumnLayout {
    id: root

    property string label
    property string icon
    property bool muted
    property real volume
    property list<PwNode> devices
    property PwNode activeDevice

    signal toggleMute
    signal setVolume(real v)
    signal selectDevice(PwNode d)

    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        IconButton {
            icon: root.icon
            iconColor: root.muted ? Theme.danger : Theme.textPrimary
            iconSize: Theme.fontIconLg
            onClicked: _ => root.toggleMute()
        }

        AudioSlider {
            Layout.fillWidth: true
            value: root.volume
            muted: root.muted
            onAdjusted: v => root.setVolume(v)
        }

        Text {
            text: Math.round(root.volume * 100) + "%"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
            Layout.minimumWidth: 40
            horizontalAlignment: Text.AlignRight
        }
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
