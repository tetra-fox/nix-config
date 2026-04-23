import qs.lib
import QtQuick

Item {
    id: root

    property var player: null

    visible: root.player?.minRate !== root.player?.maxRate
    implicitWidth: bg.width
    implicitHeight: bg.height

    readonly property var rates: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    readonly property real currentRate: root.player?.rate ?? 1.0

    function cycleRate() {
        if (!root.player)
            return;
        const cur = root.currentRate;
        for (let i = 0; i < root.rates.length; i++) {
            // epsilon avoids float equality issues (e.g. 1.0 stored as 0.999...)
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
        radius: Theme.radiusMd
        color: area.pressed ? Theme.pressedBg : area.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: parseFloat(root.currentRate.toFixed(2)) + "x"
            color: root.currentRate !== 1.0 ? Theme.accent : Theme.textInactive
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
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
