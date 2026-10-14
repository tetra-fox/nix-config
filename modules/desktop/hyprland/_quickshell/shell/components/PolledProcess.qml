import QtQuick

// first run fires on the polling edge, not one interval later
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
