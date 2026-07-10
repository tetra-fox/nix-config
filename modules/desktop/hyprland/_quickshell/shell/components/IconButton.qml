import qs.lib
import QtQuick

// bar icon button; isOpen highlights when popup is visible
Item {
    id: root

    property string icon
    property color iconColor: Theme.textPrimary
    property bool isOpen: false
    property int iconSize: Theme.fontIcon
    property bool interactive: true

    signal clicked(var mouse)

    implicitWidth: bg.width
    implicitHeight: bg.height

    Rectangle {
        id: bg
        width: Theme.iconHitWidth
        height: Theme.iconHitHeight
        radius: Theme.radiusMd

        color: Theme.stateBg(area.pressed, root.isOpen, area.containsMouse)
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
            enabled: root.interactive
            hoverEnabled: root.interactive
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => root.clicked(mouse)
        }
    }
}
