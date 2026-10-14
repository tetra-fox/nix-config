pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

BarPopupButton {
    id: root

    visible: Brightness.hasDevices

    icon: Icons.brightness
    spacing: 12

    onPopupVisibleChanged: {
        if (popupVisible)
            Brightness.addWatcher();
        else
            Brightness.removeWatcher();
    }

    BrightnessRow {
        id: globalRow
        Layout.fillWidth: true
        value: Brightness.average
        onAdjusted: frac => Brightness.setAll(frac)
        onInteractingChanged: Brightness.setAllInteracting(globalRow.interacting)
    }

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
                onInteractingChanged: deviceEntry.modelData.interacting = devRow.interacting
            }
        }
    }
}
