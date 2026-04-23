import qs.lib
import QtQuick

// bar icon button; isOpen highlights when popup is visible
Item {
    id: root

    property string icon
    property color iconColor: Theme.textPrimary
    property bool isOpen: false
    property int iconSize: Theme.fontIcon

    signal clicked(var mouse)

    implicitWidth: bg.width
    implicitHeight: bg.height

    Rectangle {
        id: bg
        width: Theme.iconHitWidth
        height: Theme.iconHitHeight
        radius: Theme.radiusMd

        color: {
            if (area.pressed)
                return Theme.pressedBg;
            if (root.isOpen)
                return Theme.openBg;
            if (area.containsMouse)
                return Theme.hoverBg;
            return Theme.withAlpha(Theme.hoverBg, 0);
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        Text {
            id: iconText
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => root.clicked(mouse)
        }
    }
}
