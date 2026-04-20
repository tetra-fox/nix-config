import qs.components
import QtQuick

// Circular icon button for media player controls.
Item {
    id: root

    Theme {
        id: theme
    }

    property string icon
    property color iconColor: root.highlight ? theme.black : theme.textPrimary
    property int iconSize: theme.fontIconLg
    property int size: 32
    property bool enabled: true
    property bool highlight: false

    signal clicked

    implicitWidth: bg.width
    implicitHeight: bg.height
    opacity: enabled ? 1.0 : 0.3

    Rectangle {
        id: bg
        width: root.size
        height: root.size
        radius: root.size / 2
        color: {
            if (root.highlight)
                return area.pressed ? Qt.darker(theme.accent, 1.3) : area.containsMouse ? Qt.lighter(theme.accent, 1.2) : theme.accent;
            return area.pressed ? theme.pressedBg : area.containsMouse ? theme.hoverBg : "transparent";
        }
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.enabled)
                root.clicked()
        }
    }
}
