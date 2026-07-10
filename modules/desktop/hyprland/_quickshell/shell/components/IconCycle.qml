import QtQuick

// cycles frame through a list of icon glyphs while running; resets to the
// first frame on stop so a restart is deterministic
QtObject {
    id: root

    property var frames: []
    property int interval: 600
    property bool running: false

    readonly property string frame: frames[_index] ?? ""

    property int _index: 0

    // declared as a property because QtObject has no default children slot
    readonly property Timer _timer: Timer {
        running: root.running
        interval: root.interval
        repeat: true
        onRunningChanged: if (!running)
            root._index = 0
        onTriggered: root._index = (root._index + 1) % root.frames.length
    }
}
