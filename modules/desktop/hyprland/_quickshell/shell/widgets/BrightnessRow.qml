import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property real value: 0
    property string icon: Icons.brightness

    signal adjusted(real frac)
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

        // a Binding survives the slider's own writes during a drag, an inline binding wouldn't.
        // RestoreNone so pressing doesn't snap the handle to its pre-binding value
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
