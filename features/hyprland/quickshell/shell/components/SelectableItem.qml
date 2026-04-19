import QtQuick
import QtQuick.Layouts

// Selectable list row — checkmark + label with marquee, separator, hover/press states.
// Used for device selectors (audio, bluetooth, etc.)
Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    default property alias actions: actionRow.data

    property string icon: icons.check
    property color iconColor: root.active ? theme.accent : "transparent"
    property int iconSize: theme.fontMd
    property string text: ""
    property color textColor: root.active ? theme.textActive : theme.textInactive
    property bool active: false
    property bool showSeparator: false

    signal selected

    implicitHeight: row.implicitHeight + 16

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 8
            rightMargin: 8
        }
        height: 1
        color: theme.separatorBg
        visible: root.showSeparator
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusMd
        color: area.containsMouse ? theme.hoverBg : "transparent"
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selected()
    }

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 8
            topMargin: 6
            bottomMargin: 6
        }
        spacing: 10

        Text {
            text: root.icon
            font.pixelSize: root.iconSize
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
            color: root.iconColor
            Behavior on color {
                ColorAnimation {
                    duration: theme.animNormal
                }
            }
        }

        MarqueeText {
            Layout.fillWidth: true
            text: root.text
            color: root.textColor
            hovered: area.containsMouse
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            Behavior on color {
                ColorAnimation {
                    duration: theme.animNormal
                }
            }
        }

        Row {
            id: actionRow
            spacing: 6
        }
    }
}
