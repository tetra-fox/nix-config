import qs.theme
import QtQuick

Item {
    id: root

    property string icon
    property color iconColor: root.highlight ? Theme.black : Theme.textPrimary
    property int iconSize: Theme.fontIconLg
    property int size: 32
    property bool highlight: false

    signal clicked

    implicitWidth: bg.width
    implicitHeight: bg.height
    opacity: root.enabled ? 1.0 : 0.3

    Rectangle {
        id: bg
        width: root.size
        height: root.size
        radius: root.size / 2
        color: {
            if (root.highlight)
                return area.pressed ? Qt.darker(Theme.accent, 1.3) : area.containsMouse ? Qt.lighter(Theme.accent, 1.2) : Theme.accent;
            return area.pressed ? Theme.pressedBg : area.containsMouse ? Theme.hoverBg : "transparent";
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.clicked()
        }
    }
}
