pragma Singleton

import qs.components
import QtQuick

// backlight model. quickshell has no native brightness service, so enumerate
// /sys/class/backlight via a script and drive brightnessctl to set levels.
// on this desktop the only backlight devices are the ddcci monitors (see
// modules/hardware/ddcci), so each device is one external display.
//
// devices are persistent BacklightDevice objects, matched by name across polls,
// so the per-display Repeater and its sliders keep stable identity. the poll
// only updates a device's value when the user is not dragging it.
QtObject {
    id: root

    // list<BacklightDevice>, created once and reused
    property var devices: []
    readonly property bool hasDevices: devices.length > 0

    // mean level across all displays, drives the global slider. recomputed
    // whenever any device's value changes (wired up per device on creation)
    property real average: 0
    function _recomputeAverage(): void {
        if (devices.length === 0) {
            average = 0;
            return;
        }
        let sum = 0;
        for (const d of devices)
            sum += d.value;
        average = sum / devices.length;
    }

    // poll while any brightness UI is open; ref-counted so multiple popups share
    // one timer. also refreshed once at startup so hasDevices (which gates the
    // bar button) is known before any popup can open
    property int _watchers: 0
    function addWatcher(): void {
        if (_watchers === 0)
            root.refresh();
        _watchers += 1;
    }
    function removeWatcher(): void {
        _watchers = Math.max(0, _watchers - 1);
    }

    readonly property string _scriptsDir: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    Component.onCompleted: root.refresh()

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    property Component _deviceComp: Component {
        BacklightDevice {}
    }

    function _deviceByName(name: string): var {
        for (const d of root.devices)
            if (d.name === name)
                return d;
        return null;
    }

    property BufferedProcess _listProc: BufferedProcess {
        id: listProc
        command: ["sh", root._scriptsDir + "/list-backlight.sh"]
        onFinished: output => {
            const seen = {};
            for (const line of output.trim().split("\n")) {
                if (line === "")
                    continue;
                const f = line.split("\t");
                const name = f[0];
                const model = f[1];
                const max = parseInt(f[2]) || 0;
                const cur = parseInt(f[3]) || 0;
                if (max <= 0)
                    continue;
                seen[name] = true;
                let dev = root._deviceByName(name);
                if (dev) {
                    dev.model = model;
                    dev.max = max;
                    dev.syncFromDevice(cur / max);
                } else {
                    // new device: create a persistent object for it
                    dev = root._deviceComp.createObject(root, {
                        name: name,
                        model: model,
                        max: max,
                        value: cur / max
                    });
                    // keep the running average current as any device moves.
                    // the linter types createObject results as plain QObject
                    dev.valueChanged.connect(root._recomputeAverage); // qmllint disable missing-property
                    root.devices = [...root.devices, dev];
                }
            }
            // drop devices that disappeared (monitor unplugged)
            const survivors = root.devices.filter(d => seen[d.name]);
            if (survivors.length !== root.devices.length) {
                for (const d of root.devices)
                    if (!seen[d.name])
                        d.destroy();
                root.devices = survivors;
            }
            root._recomputeAverage();
        }
    }

    // re-read every 3s while a brightness popup is open, so external changes
    // (keyboard keys, other tools) reflect in the sliders
    property Timer _poll: Timer {
        interval: 3000
        repeat: true
        running: root._watchers > 0
        onTriggered: root.refresh()
    }

    // global slider: drive every display to the same level at once
    function setAll(frac: real): void {
        for (const d of root.devices)
            d.set(frac);
    }

    // global slider drag: hold off poll syncs on every device, same as a
    // per-display drag does for its one device
    function setAllInteracting(active: bool): void {
        for (const d of root.devices)
            d.interacting = active;
    }
}
