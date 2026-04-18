import QtQuick

// icon button used in the bar. set isOpen: true when its popup is visible
Item {
    id: root

    Theme {
        id: theme
    }

    property string icon
    property color iconColor: theme.textPrimary
    property bool isOpen: false
    property int iconSize: theme.fontIcon

    signal clicked(var mouse)

    implicitWidth: bg.width
    implicitHeight: bg.height

    Rectangle {
        id: bg
        width: iconText.implicitWidth + theme.iconPadH
        height: iconText.implicitHeight + theme.iconPadV
        radius: theme.radiusMd

        color: {
            if (area.pressed)
                return theme.pressedBg;
            if (root.isOpen)
                return theme.openBg;
            if (area.containsMouse)
                return theme.hoverBg;
            return "transparent";
        }
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        Text {
            id: iconText
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
            font.family: theme.fontFamily
            Behavior on color {
                ColorAnimation {
                    duration: theme.animFast
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
