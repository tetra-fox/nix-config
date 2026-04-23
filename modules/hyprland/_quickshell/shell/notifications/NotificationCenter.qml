pragma ComponentBehavior: Bound
import qs.components
import qs.lib

import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: root

    required property var notifList

    readonly property int count: notifList.length

    // group wrappers by appName, sort newest-first both within and across groups
    readonly property var groups: {
        const map = {};
        for (const w of root.notifList) {
            const key = (w.notif?.appName ?? "") || "Unknown";
            if (!map[key])
                map[key] = [];
            map[key].push(w);
        }
        const out = [];
        for (const k in map) {
            const arr = map[k];
            arr.sort((a, b) => b.time - a.time);
            out.push({
                "appName": k,
                "notifs": arr,
                "time": arr[0].time
            });
        }
        out.sort((a, b) => b.time - a.time);
        return out;
    }

    contentWidth: 380
    contentHeight: column.implicitHeight + Theme.pillHPad * 2
    animateSize: true

    function clearAll(): void {
        const notifs = root.notifList.map(w => w.notif);
        for (const n of notifs)
            n.dismiss();
    }

    function clearApp(appName: string): void {
        const notifs = root.notifList.filter(w => ((w.notif?.appName ?? "") || "Unknown") === appName).map(w => w.notif);
        for (const n of notifs)
            n.dismiss();
    }

    ColumnLayout {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.pillHPad
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.count > 0 ? `Notifications (${root.count})` : "Notifications"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }

            Text {
                text: "DND"
                color: NotifState.dnd ? Theme.textActive : Theme.textInactive
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
            }

            ToggleSwitch {
                checked: NotifState.dnd
                onToggled: NotifState.toggleDnd()
            }

            InlineButton {
                text: "Clear all"
                accentColor: Theme.colorRed
                visible: root.count > 0
                onClicked: root.clearAll()
            }
        }

        Separator {
            visible: root.count > 0
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: Theme.textInactive
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
            visible: root.count === 0
        }

        ScrollableList {
            Layout.fillWidth: true
            maxHeight: 450
            spacing: 12
            visible: root.count > 0

            Repeater {
                model: root.groups

                NotificationGroup {
                    required property var modelData
                    width: parent.width    // qmllint disable unqualified
                    appName: modelData.appName
                    notifs: modelData.notifs
                    onClearGroup: root.clearApp(modelData.appName)
                }
            }
        }
    }
}
