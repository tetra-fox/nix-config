import qs.theme
import QtQuick
import QtQuick.Layouts

// selectable list row with checkmark, marquee label, and hover states
Item {
    id: root

    default property alias actions: actionRow.data

    property string icon: Icons.check
    property color iconColor: root.active ? Theme.accent : "transparent"
    property int iconSize: Theme.fontMd
    property string text: ""
    property color textColor: root.active ? Theme.textActive : Theme.textInactive
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
        color: Theme.separatorBg
        visible: root.showSeparator
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: area.containsMouse ? Theme.hoverBg : "transparent"
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
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
            color: root.iconColor
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animNormal
                }
            }
        }

        MarqueeText {
            Layout.fillWidth: true
            text: root.text
            color: root.textColor
            hovered: area.containsMouse
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animNormal
                }
            }
        }

        Row {
            id: actionRow
            spacing: 6
        }
    }
}
