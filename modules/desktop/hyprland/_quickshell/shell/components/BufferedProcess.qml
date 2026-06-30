import Quickshell.Io
import QtQuick

// buffers stdout into a single string, emits finished(output) on completion
Process {
    id: root

    property string _buf: ""
    signal finished(string output)

    stdout: SplitParser {
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
