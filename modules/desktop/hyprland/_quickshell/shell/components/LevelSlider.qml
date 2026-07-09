import qs.lib
import QtQuick
import QtQuick.Controls

// styled 0..to slider - shared track/handle look for volume and brightness rows.
// emits adjusted(value) on user drags; subclasses layer extra gestures on top.
Slider {
    id: root

    property bool compact: false
    // paints the fill in danger colour (muted audio); brightness never sets it
    property bool alert: false

    // fires on real value changes from the user
    signal adjusted(real value)
    // subclasses set this to swallow drag emits during a gesture (e.g. the
    // audio double-tap reset, which snaps on release instead)
    property bool suppressAdjust: false

    hoverEnabled: enabled

    onMoved: {
        if (!root.suppressAdjust)
            root.adjusted(value);
    }

    readonly property int _trackH: compact ? 3 : 4
    readonly property int _handleSz: compact ? 10 : 16

    // subclasses parent extra marks (e.g. the 100% tick on the volume slider)
    // here so they position against the track width
    readonly property alias trackItem: track

    background: Item {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.availableWidth
        implicitHeight: root.compact ? 12 : 16

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root._trackH
            radius: height / 2
            color: Theme.inactiveBg

            Rectangle {
                width: root.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.alert ? Theme.danger : Theme.accent
                Behavior on width {
                    enabled: !root.pressed
                    NumberAnimation {
                        duration: Theme.animSettle
                        easing.type: Easing.OutExpo
                    }
                }
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
                duration: Theme.animSettle
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
