pragma ComponentBehavior: Bound

import qs.lib
import QtQuick
import QtQuick.Effects

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

        FloatingNote {
            containerWidth: root.width
            containerHeight: root.height
        }
    }

    component FloatingNote: Item {
        id: fn

        readonly property var noteColors: [Theme.colorPink, Theme.colorPurple, Theme.colorBlue, Theme.colorGreen, Theme.colorYellow, Theme.colorRed]

        required property real containerWidth
        required property real containerHeight
        property real angle: 0
        property real drift: 0

        x: fn.containerWidth / 2 - width / 2 + Math.cos(fn.angle) * fn.drift
        y: fn.containerHeight / 2 - height / 2 + Math.sin(fn.angle) * fn.drift
        width: fnLabel.implicitWidth
        height: fnLabel.implicitHeight

        // radial fade: fast in near center, smooth out toward edge
        opacity: {
            const t = fn.drift / 24.0;
            if (t < 0.15)
                return t / 0.15 * 0.7;
            return 0.7 * (1.0 - (t - 0.15) / 0.85);
        }

        function launch() {
            fn.angle = Math.random() * 2 * Math.PI;
            fnLabel.font.pixelSize = 10 + Math.round(Math.random() * 3);
            fnLabel.color = fn.noteColors[Math.floor(Math.random() * fn.noteColors.length)];
            fnDrift.restart();
        }

        Text {
            id: fnLabel
            // material symbols music_note glyph
            text: "\uE405"
            font.family: Theme.fontIconFamily
            font.pixelSize: 10
            font.variableAxes: Theme.fontIconAxes
            color: Theme.colorPink
            // hidden but layer-rendered so MultiEffect can use it as a source
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
            // exponential ramp so blur accelerates as notes drift outward
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
