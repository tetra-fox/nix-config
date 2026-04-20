import qs.components
import QtQuick

// Playback speed button — cycles through common rates.
Item {
    id: root

    Theme {
        id: theme
    }

    property var player: null

    visible: root.player?.minRate !== root.player?.maxRate
    implicitWidth: bg.width
    implicitHeight: bg.height

    readonly property var rates: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    readonly property real currentRate: root.player?.rate ?? 1.0

    function cycleRate() {
        if (!root.player)
            return;
        // find the next rate above current, wrapping to first
        const cur = root.currentRate;
        for (let i = 0; i < root.rates.length; i++) {
            if (root.rates[i] > cur + 0.01) {
                root.player.rate = root.rates[i];
                return;
            }
        }
        root.player.rate = root.rates[0];
    }

    Rectangle {
        id: bg
        width: label.implicitWidth + 12
        height: label.implicitHeight + 6
        radius: theme.radiusMd
        color: area.pressed ? theme.pressedBg : area.containsMouse ? theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.currentRate.toFixed(root.currentRate % 1 === 0 ? 0 : 2) + "x"
            color: root.currentRate !== 1.0 ? theme.accent : theme.textInactive
            font.pixelSize: theme.fontXs
            font.family: theme.fontFamily
            font.bold: root.currentRate !== 1.0
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cycleRate()
        }
    }
}
