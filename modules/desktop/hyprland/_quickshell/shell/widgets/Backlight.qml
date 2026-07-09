pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

// bar widget: a global brightness slider plus one slider per display. hidden
// entirely when no controllable backlight devices exist (see lib/Brightness)
Item {
    id: root

    property var panelWindow

    // gate the whole widget on having controllable backlight; no monitors that
    // answer DDC/CI means nothing to drive, so don't take up bar space
    visible: Brightness.hasDevices
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    IconButton {
        id: btn
        icon: Icons.brightness
        isOpen: popup.visible
        onClicked: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: Theme.popupWidth
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        // keep the model polling while the popup is open so external changes reflect
        onVisibleChanged: {
            if (visible)
                Brightness.addWatcher();
            else
                Brightness.removeWatcher();
        }

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 12

            // global row, drives every display at once
            BrightnessRow {
                id: globalRow
                Layout.fillWidth: true
                value: Brightness.average
                onAdjusted: frac => Brightness.setAll(frac)
                onInteractingChanged: Brightness.setAllInteracting(globalRow.interacting)
            }

            // per-display rows only when there's more than one to distinguish
            Separator {
                visible: Brightness.devices.length > 1
            }

            Repeater {
                model: Brightness.devices.length > 1 ? Brightness.devices : []

                delegate: ColumnLayout {
                    id: deviceEntry
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: deviceEntry.modelData.model
                        color: Theme.textLabel
                        font.pixelSize: Theme.fontSm
                        font.family: Theme.fontFamily
                    }

                    BrightnessRow {
                        id: devRow
                        Layout.fillWidth: true
                        icon: Icons.monitor
                        value: deviceEntry.modelData.value
                        onAdjusted: frac => deviceEntry.modelData.set(frac)
                        // hold off the poll for this device while the user drags it
                        onInteractingChanged: deviceEntry.modelData.interacting = devRow.interacting
                    }
                }
            }
        }
    }
}
