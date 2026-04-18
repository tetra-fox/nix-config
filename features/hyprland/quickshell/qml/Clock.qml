import Quickshell
import QtQuick

// clock — syncs to the nearest second boundary on init, then ticks every 1000ms
Text {
    id: root

    Theme { id: theme }

    color:          theme.textPrimary
    font.pixelSize: theme.fontBase
    font.family:    theme.fontFamily

    function updateTime() {
        text = Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")
    }

    // align to the next second boundary, then hand off to tickTimer
    Timer {
        id: syncTimer
        interval: {
            const sub = Date.now() % 1000
            return sub === 0 ? 1000 : (1000 - sub)
        }
        running: true
        repeat:  false
        onTriggered: {
            root.updateTime()
            tickTimer.running = true
        }
    }

    Timer {
        id: tickTimer
        interval: 1000
        running:  false
        repeat:   true
        onTriggered: root.updateTime()
    }

    Component.onCompleted: updateTime()
}
