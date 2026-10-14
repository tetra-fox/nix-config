import qs.lib
import QtQuick

// spins whenever it can be seen, gate it with visible or opacity
Text {
    id: root

    text: Icons.progressActivity
    color: Theme.textInactive
    font.pixelSize: Theme.fontSm
    font.family: Theme.fontIconFamily
    font.variableAxes: Theme.fontIconAxes

    RotationAnimator {
        target: root
        from: 0
        to: 360
        duration: Theme.animSpin
        loops: Animation.Infinite
        running: root.visible && root.opacity > 0
    }
}
