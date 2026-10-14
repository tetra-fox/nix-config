import Quickshell.Io
import QtQuick

Process {
    id: root

    property string _buf: ""
    // increments when a run starts, so onFinished sees the run that just ended
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
