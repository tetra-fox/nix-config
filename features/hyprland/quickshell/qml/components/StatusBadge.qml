import qs.components
import QtQuick
import QtQuick.Effects

// A small pill-shaped status badge with an optional animated ping ring.
// active=true  → accent tint, pulsing text, expanding ring
// active=false → accent tint, no animation
// Override accentColor to change the color (default: green when active, red when not)
Rectangle {
    id: root

    Theme {
        id: theme
    }

    property string text: ""
    property bool active: false
    property bool pulsing: false
    // Override to use a custom accent (e.g. theme.colorYellow for a connecting state)
    property color accentColor: root.active ? theme.colorGreen : theme.colorRed

    radius: theme.radiusSm
    color: theme.withAlpha(root.accentColor, 0.18)
    implicitWidth:  label.implicitWidth + 8
    implicitHeight: label.implicitHeight + 4

    // ── ping ring ─────────────────────────────────────────────────────────────
    Rectangle {
        id: ringSource
        anchors.centerIn: parent
        width:  parent.width  + 6
        height: parent.height + 6
        radius: parent.radius
        color: "transparent"
        border.color: root.accentColor
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        id: ring
        source: ringSource
        anchors.centerIn: parent
        width:  ringSource.width
        height: ringSource.height
        blurEnabled: true
        blurMax: 12
        blur: 0
        opacity: 0
        scale: 1.0

        SequentialAnimation {
            loops: Animation.Infinite
            running: root.active
            onRunningChanged: if (!running) {
                ring.opacity = 0;
                ring.scale = 1.0;
                ring.blur = 0;
                ringSource.border.width = 0;
            }
            PropertyAction { target: ring;       property: "scale";   value: 0.92 }
            PropertyAction { target: ring;       property: "opacity"; value: 0.8 }
            PropertyAction { target: ring;       property: "blur";    value: 1.0 }
            PropertyAction { target: ringSource; property: "border.width"; value: 1.5 }
            ParallelAnimation {
                NumberAnimation { target: ring;       property: "scale";        to: 1.32; duration: 1200; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring;       property: "opacity";      to: 0;    duration: 1200; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring;       property: "blur";         to: 5.0;  duration: 1200; easing.type: Easing.OutCubic }
                NumberAnimation { target: ringSource; property: "border.width"; to: 3.0;  duration: 1200; easing.type: Easing.OutCubic }
            }
            PauseAnimation { duration: 1400 }
        }
    }

    // ── label ─────────────────────────────────────────────────────────────────
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.accentColor
        font.pixelSize: theme.fontXs
        font.family: theme.fontFamily

        SequentialAnimation on color {
            loops: Animation.Infinite
            running: root.active
            ColorAnimation { to: Qt.lighter(root.accentColor, 1.2); duration: 2000; easing.type: Easing.InOutSine }
            ColorAnimation { to: root.accentColor;                   duration: 2000; easing.type: Easing.InOutSine }
        }
    }

    // ── connecting pulse ──────────────────────────────────────────────────────
    SequentialAnimation {
        id: pulseAnim
        loops: Animation.Infinite
        running: root.pulsing
        NumberAnimation { target: root; property: "opacity"; to: 0.4; duration: 300; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.InOutSine }
    }

    onPulsingChanged: if (!pulsing) opacity = 1.0
}
