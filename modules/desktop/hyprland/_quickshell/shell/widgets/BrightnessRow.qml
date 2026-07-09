import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

// icon + slider + percent readout for one brightness level (a single display,
// or the global average across displays)
RowLayout {
    id: root

    // model value 0..1, applied to the slider only while it is not pressed
    property real value: 0
    property string icon: Icons.brightness

    signal adjusted(real frac)
    // true while the user is dragging; owners hold off poll syncs on it
    readonly property alias interacting: slider.pressed

    Layout.fillWidth: true
    spacing: 12

    Text {
        text: root.icon
        color: Theme.textPrimary
        font.pixelSize: Theme.fontIconLg
        font.family: Theme.fontIconFamily
        font.variableAxes: Theme.fontIconAxes
        Layout.preferredWidth: Theme.fontIconLg
        horizontalAlignment: Text.AlignHCenter
    }

    LevelSlider {
        id: slider
        Layout.fillWidth: true
        onAdjusted: v => root.adjusted(v)

        // while pressed the slider owns its position; on release this re-applies
        // the model value, which the drag already moved, so the handle stays put.
        // a Binding element survives the slider's own value writes during a drag,
        // where an inline `value: root.value` would be destroyed by the first one.
        // RestoreNone because the default restore mode would snap the handle to
        // its pre-binding value at press time
        Binding on value {
            when: !slider.pressed
            value: root.value
            restoreMode: Binding.RestoreNone
        }
    }

    Text {
        text: Math.round(slider.value * 100) + "%"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontMd
        font.family: Theme.fontFamily
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
    }
}
