pragma Singleton

import QtQuick

// shared monotonic clock for "time ago" rendering; 30s resolution is fine since smallest unit is minutes
QtObject {
    id: root

    property real now: Date.now()

    function friendly(t: real): string {
        const diff = (root.now - t) / 1000;
        if (diff < 60)
            return "now";
        if (diff < 3600)
            return `${Math.floor(diff / 60)}m`;
        if (diff < 86400)
            return `${Math.floor(diff / 3600)}h`;
        return `${Math.floor(diff / 86400)}d`;
    }

    property Timer _timer: Timer {
        running: true
        interval: 30000
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
