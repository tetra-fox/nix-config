import QtQuick

// BufferedProcess that reruns on an interval while polling is true. the first
// run fires on the polling edge itself, not one interval later, which also
// covers the "kick it immediately when the gate opens" call sites
BufferedProcess {
    id: root

    property bool polling: false
    property int interval: 2000

    function trigger(): void {
        if (!root.running)
            root.running = true;
    }

    // declared as a property because Process has no default children slot
    readonly property Timer _timer: Timer {
        running: root.polling
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.trigger()
    }
}
