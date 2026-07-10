import qs.lib
import QtQuick

// indeterminate spinner glyph; spins whenever it can be seen, so gate it with
// either visible or opacity depending on whether it should keep its layout slot
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
