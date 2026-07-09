pragma ComponentBehavior: Bound
// own-module import: NotifState's singleton flag lives in the generated qmldir,
// which tooling only reads through a module import, not same-directory lookup
import qs.notifications
import qs.components
import qs.lib

import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: root

    required property var notifList

    readonly property int count: notifList.length

    // group wrappers by appName, sorted newest-first within and across groups.
    // groups are persistent objects cached by appName and updated in place, so
    // the Repeater keeps its delegates (and their expanded/reply state) when
    // the list changes; a binding building fresh js objects would rebuild all
    property var groups: []
    property var _groupCache: ({})
    property Component _groupComp: Component {
        QtObject {
            property string appName
            property var notifs: []
            property real time: 0
        }
    }

    onNotifListChanged: _regroup()
    Component.onCompleted: _regroup()

    function _regroup(): void {
        const map = {};
        for (const w of root.notifList) {
            const key = NotifState.groupKey(w);
            if (!map[key])
                map[key] = [];
            map[key].push(w);
        }
        const out = [];
        for (const k in map) {
            const arr = map[k];
            arr.sort((a, b) => b.time - a.time);
            let g = root._groupCache[k];
            if (!g) {
                g = root._groupComp.createObject(root, {
                    appName: k
                });
                root._groupCache[k] = g;
            }
            g.notifs = arr;
            g.time = arr[0].time;
            out.push(g);
        }
        for (const k in root._groupCache) {
            if (!map[k]) {
                root._groupCache[k].destroy();
                delete root._groupCache[k];
            }
        }
        out.sort((a, b) => b.time - a.time);
        // publish only real order or membership changes
        if (out.length !== root.groups.length || out.some((g, i) => g !== root.groups[i]))
            root.groups = out;
    }

    contentWidth: 380
    contentHeight: column.implicitHeight + Theme.pillHPad * 2
    animateSize: true

    function clearAll(): void {
        NotifState.dismissAll(root.notifList);
    }

    function clearApp(appName: string): void {
        NotifState.dismissAll(root.notifList.filter(w => NotifState.groupKey(w) === appName));
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
                model: ScriptModel {
                    values: root.groups
                }

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
