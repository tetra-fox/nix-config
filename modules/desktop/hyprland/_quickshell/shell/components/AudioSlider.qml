import qs.lib
import QtQuick

// volume slider - LevelSlider plus the audio-only bits: 150% range, a 100%
// tick, and double-tap to reset to 100%
LevelSlider {
    id: root

    property bool muted: false
    alert: muted

    to: 1.5

    // double-tap snaps to 100%: flag is set on double-tap, volume
    // resets on release so the user doesn't hear the intermediate jump
    property bool _resetOnRelease: false
    suppressAdjust: _resetOnRelease

    onPressedChanged: {
        if (!pressed && _resetOnRelease) {
            _resetOnRelease = false;
            _resetTimer.start();
        }
    }

    // defer one tick so Behavior on x re-enables before value changes
    Timer {
        id: _resetTimer
        interval: 1
        onTriggered: root.adjusted(1.0)
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: root._resetOnRelease = true
    }

    // 100% tick mark (slider goes to 150%), parented into the base track so it
    // positions against the track width
    Rectangle {
        parent: root.trackItem
        x: parent.width * (1.0 / 1.5) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? 1 : 2
        height: root.compact ? 8 : 10
        radius: width / 2
        color: Theme.withAlpha(Theme.white, 0.18)
    }
}
