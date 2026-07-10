import Quickshell.Io
import QtQuick

// buffers stdout into a single string, emits finished(output) on completion
Process {
    id: root

    property string _buf: ""
    // increments when a run starts. inside onFinished it still names the run
    // that just ended, so handlers can discard output from runs that started
    // before some state change (see VpnSection._reconcile)
    property int runId: 0
    signal finished(string output)

    stdout: SplitParser {
        onRead: data => root._buf += data + "\n"
    }

    onRunningChanged: {
        if (running) {
            runId++;
            _buf = "";
        } else {
            root.finished(_buf);
        }
    }
}
