import QtQuick
import QtQuick.Layouts

// Usage bar with icon, label, detail text, and animated progress bar.
ColumnLayout {
    id: root

    Theme {
        id: theme
    }

    property string label: ""
    property string icon: ""
    property real value: 0
    property string detail: ""
    property color barColor: root.value > 0.9 ? theme.danger : root.value > 0.7 ? theme.colorYellow : theme.accent

    spacing: 3
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: theme.textLabel
            font.pixelSize: theme.fontIcon
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
        }

        Text {
            text: root.label
            color: theme.textLabel
            font.pixelSize: theme.fontSm
            font.family: theme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.detail
            color: theme.textSecondary
            font.pixelSize: theme.fontSm
            font.family: theme.fontFamily
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: theme.inactiveBg

        Rectangle {
            width: parent.width * Math.min(Math.max(root.value, 0), 1)
            height: parent.height
            radius: parent.radius
            color: root.barColor

            Behavior on width {
                NumberAnimation {
                    duration: theme.animSlow
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
