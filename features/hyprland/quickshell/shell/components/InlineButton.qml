import qs.theme
import QtQuick

// small inline action button. set accentColor to tint hover (e.g. colorRed for destructive)
Rectangle {
    id: root

    property string text: ""
    property color accentColor: Theme.textPrimary

    signal clicked

    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 6
    radius: Theme.radiusSm
    color: area.pressed ? Theme.pressedBg : area.containsMouse ? Theme.hoverBg : Theme.withAlpha(Theme.white, 0.06)
    border.width: 1
    border.color: area.containsMouse ? Theme.withAlpha(root.accentColor, 0.3) : Theme.withAlpha(Theme.white, 0.06)
    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: area.containsMouse ? root.accentColor : Theme.textInactive
        font.pixelSize: Theme.fontXs
        font.family: Theme.fontFamily
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
