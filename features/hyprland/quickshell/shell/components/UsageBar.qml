import qs.theme
import QtQuick
import QtQuick.Layouts

// usage bar with icon, label, detail text, and animated progress bar
ColumnLayout {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property string detail: ""
    property color barColor: {
        if (root.value > 0.9) return Theme.danger;
        if (root.value > 0.7) return Theme.colorYellow;
        return Theme.accent;
    }

    spacing: 3
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: Theme.textLabel
            font.pixelSize: Theme.fontIcon
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
        }

        Text {
            text: root.label
            color: Theme.textLabel
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.detail
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Theme.inactiveBg

        Rectangle {
            width: parent.width * Math.min(Math.max(root.value, 0), 1)
            height: parent.height
            radius: parent.radius
            color: root.barColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.animSlow
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
