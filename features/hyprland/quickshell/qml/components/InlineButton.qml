import QtQuick

// Small inline action button with subtle resting state and animated hover/press.
// Set accentColor to tint the hover state (e.g. theme.colorRed for destructive actions).
Rectangle {
    id: root

    Theme {
        id: theme
    }

    property string text: ""
    property color accentColor: theme.textPrimary

    signal clicked

    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 6
    radius: theme.radiusSm
    color: area.pressed ? theme.pressedBg : area.containsMouse ? theme.hoverBg : theme.withAlpha(theme.white, 0.06)
    border.width: 1
    border.color: area.containsMouse ? theme.withAlpha(root.accentColor, 0.3) : theme.withAlpha(theme.white, 0.06)
    Behavior on color { ColorAnimation { duration: theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: theme.animFast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: area.containsMouse ? root.accentColor : theme.textInactive
        font.pixelSize: theme.fontXs
        font.family: theme.fontFamily
        Behavior on color { ColorAnimation { duration: theme.animFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
