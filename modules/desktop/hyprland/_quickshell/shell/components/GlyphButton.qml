import qs.lib
import QtQuick

// Material icon glyph as a clickable button; hover highlight + extended hit area
Text {
    id: root

    property string icon
    property int iconSize: Theme.fontIcon
    property color baseColor: Theme.textInactive
    property color hoverColor: Theme.textActive

    signal clicked

    text: icon
    color: area.containsMouse ? hoverColor : baseColor
    font.family: Theme.fontIconFamily
    font.pixelSize: iconSize

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // extend hit area beyond the tiny glyph
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
