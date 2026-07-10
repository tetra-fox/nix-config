import qs.lib
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var toplevel: null
    property bool selected: false

    signal clicked

    readonly property var desktopEntry: {
        Apps.rev;
        return Apps.entry(toplevel?.appId);
    }

    implicitHeight: Theme.popupItemHeight
    implicitWidth: row.implicitWidth + Theme.pillHPad * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.stateBg(false, root.selected, mouseArea.containsMouse, "transparent")

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
        spacing: Theme.buttonGap

        // accent bar for selected item
        Rectangle {
            implicitWidth: 2
            implicitHeight: 14
            radius: 1
            color: root.selected ? Theme.accent : "transparent"
        }

        Image {
            Layout.preferredWidth: Theme.fontIconLg
            Layout.preferredHeight: Theme.fontIconLg
            sourceSize.width: Theme.fontIconLg
            sourceSize.height: Theme.fontIconLg
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
