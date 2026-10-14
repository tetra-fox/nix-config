import qs.lib
import QtQuick

LevelSlider {
    id: root

    property bool muted: false
    alert: muted

    to: 1.5

    // double-tap resets to 100% on release, so the intermediate jump isn't heard
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

    // 100% tick, the slider goes to 150%
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
