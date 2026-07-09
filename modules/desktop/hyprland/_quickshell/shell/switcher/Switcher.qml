pragma ComponentBehavior: Bound

import qs.lib
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
        // snapshot the toplevel list: active window first, then the rest in
        // model order, skipping minimized windows
        const active = ToplevelManager.activeToplevel;
        const windows = active && !active.minimized ? [active] : [];
        for (const t of ToplevelManager.toplevels.values) {
            if (t.minimized || t === active)
                continue;
            windows.push(t);
        }
        if (windows.length <= 1)
            return;

        windowList = windows;
        // start on the second item (the one we're switching to)
        selectedIndex = 1;
        open = true;
    }

    function commit() {
        if (!open)
            return;
        const target = windowList[selectedIndex];
        open = false;
        // the toplevel may have been closed while the switcher was open; the deleted
        // C++ object leaves a stale-but-truthy js reference, so re-check it is still live
        if (target && ToplevelManager.toplevels.values.includes(target))
            target.activate();
    }

    function dismiss() {
        open = false;
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    implicitWidth: panel.width
    implicitHeight: panel.height

    visible: open
    color: "transparent"

    // guard: key-release from the triggering shortcut can dismiss the grab immediately
    Timer {
        id: grabGuard
        interval: 150
    }

    // quickshell deactivates the grab after ANY clear, including the guarded
    // one from the triggering shortcut's key release, so bounce active through
    // false to re-arm it; writing the property directly would kill the binding
    property bool _grabRearm: false

    HyprlandFocusGrab {
        // qmllint disable unresolved-type
        windows: [root]
        active: root.open && !root._grabRearm
        onCleared: {
            if (grabGuard.running) {
                root._grabRearm = true;
                Qt.callLater(() => root._grabRearm = false);
                return;
            }
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
                value: Theme.dialogOpenScale
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
                duration: Theme.animDialogIn
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                to: 1.0
                duration: Theme.animSettle
                easing.type: Easing.OutQuad
            }
        }
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // xkb delivers shift+tab as Key_Backtab, not Key_Tab with a modifier
            if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.prev();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                root.next();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.commit();
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
            width: Math.max(Theme.popupWidth, list.implicitWidth + Theme.pillHPad * 2)
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
