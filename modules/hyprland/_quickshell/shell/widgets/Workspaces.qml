import qs.lib
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var screen

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // scroll to switch workspaces on this monitor, wrapping at the ends.
    // high-res scroll wheels and laggy focusedWorkspace updates can fire many
    // events per gesture, so rate-limit to one switch per cooldown window.
    property double _lastScrollAt: 0
    readonly property int _scrollCooldownMs: 180

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: ev => {
            const now = Date.now();
            if (now - root._lastScrollAt < root._scrollCooldownMs)
                return;
            const wss = Hyprland.workspaces.values.filter(ws => ws.monitor?.name === root.screen.name).sort((a, b) => a.id - b.id);
            if (wss.length < 2)
                return;
            const curIdx = wss.findIndex(ws => ws.id === Hyprland.focusedWorkspace?.id);
            const delta = ev.angleDelta.y > 0 ? -1 : 1;
            const next = (Math.max(curIdx, 0) + delta + wss.length) % wss.length;
            if (wss[next].id === Hyprland.focusedWorkspace?.id)
                return;
            root._lastScrollAt = now;
            Hyprland.dispatch("workspace " + wss[next].id);
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.workspacePillSpacing

        Repeater {
            model: Hyprland.workspaces.values.filter(ws => ws.monitor?.name === root.screen.name).sort((a, b) => a.id - b.id)

            delegate: WorkspacePill {
                required property var modelData
                workspace: modelData
            }
        }
    }
}
