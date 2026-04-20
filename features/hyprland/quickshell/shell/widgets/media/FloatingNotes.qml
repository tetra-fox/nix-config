import qs.components
import QtQuick
import QtQuick.Effects

// Floating music note particle effect for the bar button.
Item {
    id: root

    property bool active: false

    property int _nextNote: 0

    Timer {
        running: root.active
        interval: 800
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            noteRepeater.itemAt(root._nextNote).launch(); // qmllint disable missing-property
            root._nextNote = (root._nextNote + 1) % noteRepeater.count;
        }
    }

    Repeater {
        id: noteRepeater
        model: 5

        FloatingNote {}
    }

    component FloatingNote: Item {
        id: fn

        Theme {
            id: fnTheme
        }

        property real angle: 0
        property real drift: 0

        x: root.width / 2 - width / 2 + Math.cos(fn.angle) * fn.drift
        y: root.height / 2 - height / 2 + Math.sin(fn.angle) * fn.drift
        width: fnLabel.implicitWidth
        height: fnLabel.implicitHeight

        // radial fade: quick fade-in near center, smooth fade-out toward edge
        opacity: {
            const t = fn.drift / 24.0;
            if (t < 0.15)
                return t / 0.15 * 0.7;
            return 0.7 * (1.0 - (t - 0.15) / 0.85);
        }

        function launch() {
            fn.angle = Math.random() * 2 * Math.PI;
            fnLabel.font.pixelSize = 10 + Math.round(Math.random() * 3);
            fnDrift.restart();
        }

        Text {
            id: fnLabel
            text: "\uE405"
            font.family: fnTheme.fontIconFamily
            font.pixelSize: 10
            font.variableAxes: fnTheme.fontIconAxes
            color: fnTheme.accent
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            source: fnLabel
            anchors.centerIn: fnLabel
            width: fnLabel.width
            height: fnLabel.height
            blurEnabled: true
            blurMax: 16
            blur: (Math.exp(fn.drift / 24.0) - 1) / (Math.E - 1)
        }

        NumberAnimation {
            id: fnDrift
            target: fn
            property: "drift"
            from: 0
            to: 24
            duration: 1400
            easing.type: Easing.OutCubic
        }
    }
}
