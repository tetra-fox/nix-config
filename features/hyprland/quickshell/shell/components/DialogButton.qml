import qs.theme
import QtQuick

Rectangle {
    id: root

    property string text
    property color accentColor: "transparent"
    property bool bordered: false

    signal clicked

    readonly property bool _hasAccent: root.accentColor.a > 0

    implicitHeight: Theme.popupItemHeight
    radius: Theme.radiusMd
    color: {
        if (root._hasAccent)
            return area.pressed ? Qt.darker(root.accentColor, 1.3) : area.containsMouse ? root.accentColor : Theme.withAlpha(root.accentColor, 0.75);
        return area.pressed ? Theme.pressedBg : area.containsMouse ? Theme.hoverBg : Theme.withAlpha(Theme.hoverBg, 0);
    }
    border.width: root.bordered ? 1 : 0
    border.color: Theme.panelBorder
    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutQuad
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root._hasAccent ? Theme.textActive : Theme.textPrimary
        font.pixelSize: Theme.fontMd
        font.family: Theme.fontFamily
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
