import Quickshell.Io
import QtQuick

// one /sys/class/backlight device, kept across polls so its slider keeps identity
QtObject {
    id: root

    required property string name
    property string model: name
    property int max: 100

    // 0..1. polls don't write it mid-drag, a slow DDC/CI write would yank the handle back
    property real value: 0
    property bool interacting: false

    function pct(frac: real): int {
        return Math.max(0, Math.min(100, Math.round(frac * 100)));
    }

    // percent the monitor is believed to hold, skips duplicate writes. -1 means unknown
    property int _wrotePct: -1

    // self-paced instead of throttled: one write in flight at a time (~85ms on these
    // dells), the next goes out when it finishes if the value moved
    function set(frac: real): void {
        root.value = frac;
        if (!writeProc.running)
            _flush();
    }

    function _flush(): void {
        const p = root.pct(root.value);
        if (p === root._wrotePct)
            return;
        root._wrotePct = p;
        writeProc.exec(["brightnessctl", "-d", root.name, "set", p + "%"]);
        stallKill.restart();
    }

    function syncFromDevice(frac: real): void {
        // an in-flight write may not have landed yet
        if (root.interacting || writeProc.running)
            return;
        root.value = frac;
        // so a drag back to an earlier percent isn't skipped after something else moved it
        root._wrotePct = root.pct(frac);
    }

    property Process _writeProc: Process {
        id: writeProc
        // exec() while running would sigterm the write, set() only flushes from idle
        onRunningChanged: if (!running) {
            stallKill.stop();
            root._flush();
        }
    }

    // ddc/ci can wedge the i2c bus (modules/hardware/ddcci), a stuck write stalls flush and
    // poll sync. brightnessctl only writes sysfs, so killing it can't tear a transfer
    property Timer _stallKill: Timer {
        id: stallKill
        interval: 5000
        onTriggered: {
            // the killed write may not have landed
            root._wrotePct = -1;
            writeProc.signal(9);
        }
    }
}
