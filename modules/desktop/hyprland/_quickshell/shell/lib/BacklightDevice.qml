import Quickshell.Io
import QtQuick

// one /sys/class/backlight device. persists across polls (matched by name) so
// the Repeater delegate and its slider keep stable identity instead of churning.
QtObject {
    id: root

    required property string name
    property string model: name
    property int max: 100

    // 0..1. `value` is what the slider drives and reads; the poll only writes it
    // through when the user is not actively dragging, so an in-flight brightnessctl
    // write (slow on DDC/CI) can't yank the handle back to a stale reading
    property real value: 0
    property bool interacting: false

    // whole-percent step, matching brightnessctl's granularity
    function pct(frac: real): int {
        return Math.max(0, Math.min(100, Math.round(frac * 100)));
    }

    // the percent the monitor is believed to hold, used to skip duplicate writes;
    // -1 until the first write or poll reading
    property int _wrotePct: -1

    // called on user drag: move the handle immediately and stream the value to the
    // monitor as fast as the DDC/CI bus allows. a write takes ~85ms on these Dells,
    // so rather than guess a throttle interval, self-pace: issue one write now if
    // none is in flight, and when it finishes issue the next only if the value moved.
    // this tracks the finger as live as the hardware permits without queueing writes
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

    // called by the poll with the device's real current value
    function syncFromDevice(frac: real): void {
        // a write we just issued may not have landed on the monitor yet, so ignore
        // the poll while dragging or while a write is still in flight
        if (root.interacting || writeProc.running)
            return;
        root.value = frac;
        // adopt the reading, so a drag back to a percent we wrote earlier is not
        // skipped as a duplicate after something else moved the monitor
        root._wrotePct = root.pct(frac);
    }

    property Process _writeProc: Process {
        id: writeProc
        // as soon as one write lands, send the next if the drag moved on. on the
        // final release this fires once more with no pending change and stops.
        // exec() during a run would sigterm it and queue the new command (see
        // Process::exec in quickshell src/io/process.cpp), but set() only flushes
        // from idle, so every exec here starts with no process alive
        onRunningChanged: if (!running) {
            stallKill.stop();
            root._flush();
        }
    }

    // ddc/ci on this machine has wedged an i2c bus before (see modules/hardware/
    // ddcci). a write stuck far past the ~85ms norm freezes both the flush chain
    // and the poll sync, so kill it and let the false edge of running resume the
    // chain. brightnessctl only writes sysfs, the kernel finishes the i2c
    // transaction on its own, so the kill cannot tear a transfer
    property Timer _stallKill: Timer {
        id: stallKill
        interval: 5000
        onTriggered: {
            // the killed write may not have landed; forget it so the retry is not
            // skipped as a duplicate
            root._wrotePct = -1;
            writeProc.signal(9);
        }
    }
}
