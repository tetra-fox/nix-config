import qs.theme
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var toplevel: null
    property bool selected: false

    signal clicked

    // heuristicLookup("") matches the first entry with no StartupWMClass
    readonly property var desktopEntry: toplevel?.appId ? DesktopEntries.heuristicLookup(toplevel.appId) : null

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

        Image {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            sourceSize.width: 18
            sourceSize.height: 18
            asynchronous: true
            visible: source.toString().length > 0
            source: {
                const icon = root.desktopEntry?.icon ?? "";
                return icon ? Quickshell.iconPath(icon, true) : "";
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.toplevel?.title || root.desktopEntry?.name || root.toplevel?.appId || ""
            color: root.selected ? Theme.textActive : Theme.textPrimary
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }
}
