import Quickshell.Io
import QtQuick

// Process wrapper that buffers stdout into a single string.
// Emits finished(string output) when the process completes.
// Avoids the repeated _buf + SplitParser + onRunningChanged boilerplate.
Process {
    id: root

    property string _buf: ""
    signal finished(string output)

    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => root._buf += data + "\n"
    }

    onRunningChanged: {
        if (running) {
            _buf = "";
        } else {
            root.finished(_buf);
        }
    }
}
