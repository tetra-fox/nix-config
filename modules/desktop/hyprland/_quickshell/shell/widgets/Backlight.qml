pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

// bar widget: a global brightness slider plus one slider per display. hidden
// entirely when no controllable backlight devices exist (see lib/Brightness)
BarPopupButton {
    id: root

    // gate the whole widget on having controllable backlight; no monitors that
    // answer DDC/CI means nothing to drive, so don't take up bar space
    visible: Brightness.hasDevices

    icon: Icons.brightness
    spacing: 12

    // keep the model polling while the popup is open so external changes reflect
    onPopupVisibleChanged: {
        if (popupVisible)
            Brightness.addWatcher();
        else
            Brightness.removeWatcher();
    }

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

            SectionLabel {
                text: deviceEntry.modelData.model
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
