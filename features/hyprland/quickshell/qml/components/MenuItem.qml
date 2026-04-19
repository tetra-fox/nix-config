import QtQuick
import QtQuick.Layouts

// menu row for popups. set isSeparator: true for a divider line
Item {
    id: root

    Theme {
        id: theme
    }

    property string text: ""
    property string icon: ""
    property color textColor: root.enabled ? theme.textPrimary : theme.textInactive
    property bool enabled: true
    property bool isSeparator: false

    signal clicked

    implicitHeight: isSeparator ? theme.popupSeparatorHeight : theme.popupItemHeight

    Rectangle {
        visible: root.isSeparator
        anchors.centerIn: parent
        width: parent.width - 16
        height: 1
        color: theme.inactiveBg
    }

    Rectangle {
        visible: !root.isSeparator
        anchors {
            fill: parent
            leftMargin: 4
            rightMargin: 4
        }
        radius: theme.radiusMd
        color: area.pressed ? theme.pressedBg : area.containsMouse ? theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        RowLayout {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: root.textColor
                font.pixelSize: theme.fontIconLg
                font.family: theme.fontIconFamily
                font.variableAxes: theme.fontIconAxes
            }

            Text {
                Layout.fillWidth: true
                text: root.text
                color: root.textColor
                font.pixelSize: theme.fontMd
                font.family: theme.fontFamily
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled && !root.isSeparator
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
