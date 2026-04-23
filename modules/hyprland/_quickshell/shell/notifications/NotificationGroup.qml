pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string appName
    required property var notifs    // list of {notif, time} wrappers, newest first

    signal clearGroup

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 4

        // header only shown when a group has >1 notif
        RowLayout {
            Layout.fillWidth: true
            visible: root.notifs.length > 1
            spacing: 6

            Text {
                text: root.appName
                color: Theme.textInactive
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }

            Text {
                text: `(${root.notifs.length})`
                color: Theme.textInactive
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
            }

            Item {
                Layout.fillWidth: true
            }

            InlineButton {
                text: "Clear"
                accentColor: Theme.colorRed
                onClicked: root.clearGroup()
            }
        }

        Repeater {
            model: root.notifs

            NotificationCenterItem {
                required property var modelData
                Layout.fillWidth: true
                notif: modelData.notif
                time: modelData.time
            }
        }
    }
}
