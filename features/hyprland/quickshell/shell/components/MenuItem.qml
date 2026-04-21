import qs.theme
import QtQuick
import QtQuick.Layouts

// menu row for popups; isSeparator: true for a divider line
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string shortcutHint: ""
    property color textColor: root.enabled ? Theme.textPrimary : Theme.textInactive
    property bool enabled: true
    property bool isSeparator: false

    signal clicked

    implicitHeight: isSeparator ? Theme.popupSeparatorHeight : Theme.popupItemHeight

    Rectangle {
        visible: root.isSeparator
        anchors.centerIn: parent
        width: parent.width - 16
        height: 1
        color: Theme.inactiveBg
    }

    Rectangle {
        visible: !root.isSeparator
        anchors {
            fill: parent
            leftMargin: 4
            rightMargin: 4
        }
        radius: Theme.radiusMd
        color: area.pressed ? Theme.pressedBg : area.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
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
                font.pixelSize: Theme.fontIconLg
                font.family: Theme.fontIconFamily
                font.variableAxes: Theme.fontIconAxes
            }

            Text {
                Layout.fillWidth: true
                text: root.text
                color: root.textColor
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }

            Text {
                visible: root.shortcutHint !== ""
                text: root.shortcutHint
                color: Theme.textInactive
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
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
