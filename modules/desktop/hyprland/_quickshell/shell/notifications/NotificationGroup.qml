pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string appName
    required property var notifs    // wrappers, newest first

    signal clearGroup

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 4

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
            // ScriptModel diffs by identity, only added/removed rows rebuild
            model: ScriptModel {
                values: root.notifs
            }

            NotificationCenterItem {
                required property var modelData
                Layout.fillWidth: true
                wrapper: modelData
            }
        }
    }
}
