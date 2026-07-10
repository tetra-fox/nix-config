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
    // epsilon match: a player may report 1.0 as 0.999..., which exact compare would style as non-default
    readonly property bool isDefaultRate: Math.abs(root.currentRate - 1.0) <= 0.01

    function cycleRate() {
        if (!root.player)
            return;
        const cur = root.currentRate;
        for (const r of root.rates) {
            // epsilon avoids float equality issues (e.g. 1.0 stored as 0.999...)
            if (r > cur + 0.01) {
                root.player.rate = r;
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
        color: Theme.stateBg(area.pressed, false, area.containsMouse)
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: parseFloat(root.currentRate.toFixed(2)) + "x"
            color: root.isDefaultRate ? Theme.textInactive : Theme.accent
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
            font.bold: !root.isDefaultRate
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
