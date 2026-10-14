pragma Singleton

import qs.components
import QtQuick

// quickshell has no brightness service, so read /sys/class/backlight and write via brightnessctl.
// here every backlight device is a ddcci monitor (modules/hardware/ddcci)
QtObject {
    id: root

    // list<BacklightDevice>, matched by name across polls
    property var devices: []
    readonly property bool hasDevices: devices.length > 0

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

    // ref-counted popups, polling runs while any is open
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

    // hasDevices gates the bar button, so it has to be known before any popup opens
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
                    dev = root._deviceComp.createObject(root, {
                        name: name,
                        model: model,
                        max: max,
                        value: cur / max
                    });
                    // the linter types createObject results as plain QObject
                    dev.valueChanged.connect(root._recomputeAverage); // qmllint disable missing-property
                    root.devices = [...root.devices, dev];
                }
            }
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

    property Timer _poll: Timer {
        interval: 3000
        repeat: true
        running: root._watchers > 0
        onTriggered: root.refresh()
    }

    function setAll(frac: real): void {
        for (const d of root.devices)
            d.set(frac);
    }

    function setAllInteracting(active: bool): void {
        for (const d of root.devices)
            d.interacting = active;
    }
}
