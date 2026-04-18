import Quickshell
import QtQuick

// clock, updates every second
Text {
    id: root

    color:          "#dddddd"
    font.pixelSize: 13
    font.family:    "monospace"

    text: Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.text = Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")
    }
}
