import qs.theme
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var toplevel: null
    property bool selected: false

    signal clicked

    implicitHeight: 32
    implicitWidth: row.implicitWidth + Theme.pillHPad * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: root.selected ? Theme.openBg : mouseArea.containsMouse ? Theme.hoverBg : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: Theme.pillHPad
            rightMargin: Theme.pillHPad
        }
        spacing: 8

        // accent bar for selected item
        Rectangle {
            implicitWidth: 2
            implicitHeight: 14
            radius: 1
            color: root.selected ? Theme.accent : "transparent"
        }

        Text {
            Layout.fillWidth: true
            text: {
                const appId = root.toplevel?.appId ?? "";
                const title = root.toplevel?.title ?? "";
                // show "AppName — Title" when they differ
                const name = appId.charAt(0).toUpperCase() + appId.slice(1);
                if (title && title !== name)
                    return name + "  —  " + title;
                return name;
            }
            color: root.selected ? Theme.textActive : Theme.textPrimary
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }
}
