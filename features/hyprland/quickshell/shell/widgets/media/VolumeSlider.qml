import qs.components
import qs.theme
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    Layout.fillWidth: true
    spacing: 8

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property PwNode _sink: Pipewire.defaultAudioSink // qmllint disable unresolved-type
    readonly property real _volume: _sink?.audio?.volume ?? 0
    readonly property bool _muted: _sink?.audio?.muted ?? false

    Text {
        text: {
            if (root._muted) return Icons.volumeOff;
            if (root._volume >= 0.5) return Icons.volumeUp;
            if (root._volume >= 0.01) return Icons.volumeDown;
            return Icons.volumeMute;
        }
        color: root._muted ? Theme.danger : Theme.textInactive
        font.pixelSize: Theme.fontIconLg
        font.family: Theme.fontIconFamily
        font.variableAxes: Theme.fontIconAxes

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root._sink?.audio)
                    root._sink.audio.muted = !root._muted;
            }
        }
    }

    AudioSlider {
        Layout.fillWidth: true
        compact: true
        muted: root._muted
        value: root._volume
        onAdjusted: v => {
            if (root._sink?.audio)
                root._sink.audio.volume = v;
        }
    }

    Text {
        text: Math.round(root._volume * 100) + "%"
        color: Theme.textInactive
        font.pixelSize: Theme.fontXs
        font.family: Theme.fontFamily
        Layout.preferredWidth: 32
        horizontalAlignment: Text.AlignRight
    }
}
