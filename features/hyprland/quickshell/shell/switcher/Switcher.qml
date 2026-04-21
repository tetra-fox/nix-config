pragma ComponentBehavior: Bound

import qs.theme
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property int selectedIndex: 0
    property bool open: false
    // snapshot window list on open so it doesn't shift while cycling
    property list<var> windowList: []

    function next() {
        if (!open)
            show();
        else if (windowList.length > 0)
            selectedIndex = (selectedIndex + 1) % windowList.length;
    }

    function prev() {
        if (!open)
            show();
        else if (windowList.length > 0)
            selectedIndex = (selectedIndex - 1 + windowList.length) % windowList.length;
    }

    function show() {
        // snapshot the toplevel list, putting the active window first
        let windows = [];
        const toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            // skip minimized windows
            if (t.minimized)
                continue;
            windows.push(t);
        }
        if (windows.length <= 1)
            return;

        // sort: active window first, then the rest in model order
        const active = ToplevelManager.activeToplevel;
        windows.sort((a, b) => {
            if (a === active)
                return -1;
            if (b === active)
                return 1;
            return 0;
        });

        windowList = windows;
        // start on the second item (the one we're switching to)
        selectedIndex = 1;
        open = true;
        visible = true;
    }

    function commit() {
        if (!open)
            return;
        const target = windowList[selectedIndex];
        open = false;
        visible = false;
        if (target)
            target.activate();
    }

    function dismiss() {
        open = false;
        visible = false;
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    anchors.top: false
    anchors.bottom: false
    anchors.left: false
    anchors.right: false

    implicitWidth: panel.width
    implicitHeight: panel.height

    visible: false
    color: "transparent"

    // guard: key-release from the triggering shortcut can dismiss the grab immediately
    Timer {
        id: grabGuard
        interval: 150
    }

    HyprlandFocusGrab {
        // qmllint disable unresolved-type
        windows: [root]
        active: root.open
        onCleared: {
            if (grabGuard.running)
                return;
            root.commit();
        }
    }

    onVisibleChanged: {
        if (visible) {
            grabGuard.restart();
            openAnim.restart();
            keyScope.forceActiveFocus();
        }
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            PropertyAction {
                target: panel
                property: "scale"
                value: 0.88
            }
            PropertyAction {
                target: panel
                property: "opacity"
                value: 0
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "scale"
                to: 1.0
                duration: 260
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                to: 1.0
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                root.next();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
                root.prev();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.dismiss();
                event.accepted = true;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) {
                root.commit();
                event.accepted = true;
            }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.max(320, list.implicitWidth + Theme.pillHPad * 2)
            height: list.implicitHeight + Theme.pillHPad * 2
            radius: Theme.radiusLg
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder
            transformOrigin: Item.Center

            ColumnLayout {
                id: list
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.pillHPad
                    rightMargin: Theme.pillHPad
                }
                spacing: 2

                Repeater {
                    model: root.windowList

                    SwitcherItem {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        toplevel: modelData
                        selected: index === root.selectedIndex
                        onClicked: {
                            root.selectedIndex = index;
                            root.commit();
                        }
                    }
                }
            }
        }
    }
}
