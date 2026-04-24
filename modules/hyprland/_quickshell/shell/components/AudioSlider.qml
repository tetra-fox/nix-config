import qs.lib
import QtQuick
import QtQuick.Controls

// styled volume slider with double-tap to reset to 100%
Slider {
    id: root

    property bool compact: false
    property bool muted: false

    // fires on real value changes (suppressed during double-tap gesture)
    signal adjusted(real value)

    from: 0
    to: 1.5

    hoverEnabled: enabled

    // double-tap snaps to 100%: flag is set on double-tap, volume
    // resets on release so the user doesn't hear the intermediate jump
    property bool _resetOnRelease: false

    onMoved: {
        if (!_resetOnRelease)
            root.adjusted(value);
    }

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

    readonly property int _trackH: compact ? 3 : 4
    readonly property int _handleSz: compact ? 10 : 16

    background: Item {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.availableWidth
        implicitHeight: root.compact ? 12 : 16

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root._trackH
            radius: height / 2
            color: Theme.inactiveBg

            Rectangle {
                width: root.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.muted ? Theme.danger : Theme.accent
                Behavior on width {
                    enabled: !root.pressed
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutExpo
                    }
                }
            }

            // 100% tick mark (slider goes to 150%)
            Rectangle {
                x: parent.width * (1.0 / 1.5) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.compact ? 1 : 2
                height: root.compact ? 8 : 10
                radius: width / 2
                color: Theme.withAlpha(Theme.white, 0.18)
            }
        }
    }

    handle: Item {
        x: root.leftPadding + root.visualPosition * root.availableWidth - width / 2
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root._handleSz
        height: root._handleSz
        Behavior on x {
            enabled: !root.pressed
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutExpo
            }
        }

        // glow ring (full mode only)
        Rectangle {
            visible: !root.compact
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 14
            color: Theme.withAlpha(Theme.accent, root.pressed ? 0.22 : root.hovered ? 0.15 : 0)
            scale: root.pressed ? 1.7 : root.hovered ? 1.2 : 0.7
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.pressed ? (root.compact ? 6 : 8) : root.hovered ? root._handleSz : root._handleSz - 2
            height: root.pressed ? (root.compact ? 14 : 20) : root.hovered ? root._handleSz : root._handleSz - 2
            radius: height / 2
            color: root.pressed ? Theme.accent : Theme.textPrimary
            Behavior on width {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutExpo
                }
            }
        }
    }
}
