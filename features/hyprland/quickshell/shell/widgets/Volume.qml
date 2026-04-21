import qs.components
import qs.theme
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // pipewire nodes are lazy-loaded; trackers force property
    // subscriptions so bindings below stay up to date
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    IconButton {
        id: btn
        icon: {
            if (root.muted) return Icons.volumeOff;
            if (root.volume >= 0.5) return Icons.volumeUp;
            if (root.volume >= 0.01) return Icons.volumeDown;
            return Icons.volumeMute;
        }
        iconColor: root.muted ? Theme.danger : Theme.textPrimary
        isOpen: popup.visible
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.sink?.audio)
                root.sink.audio.muted = !root.muted;
            else
                popup.visible = !popup.visible;
        }
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 320
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                fill: parent
                margins: Theme.pillHPad
            }
            spacing: 10

            AudioSection {
                label: "Output"
                icon: root.muted ? Icons.volumeOff : Icons.volumeUp
                muted: root.muted
                volume: root.volume
                devices: root.sinks
                activeDevice: Pipewire.defaultAudioSink
                Layout.fillWidth: true
                onToggleMute: if (root.sink?.audio)
                    root.sink.audio.muted = !root.muted
                onSetVolume: v => {
                    if (root.sink?.audio)
                        root.sink.audio.volume = v;
                }
                onSelectDevice: d => Pipewire.preferredDefaultAudioSink = d
            }

            Separator {}

            AudioSection {
                label: "Input"
                icon: root.micMuted ? Icons.micOff : Icons.mic
                muted: root.micMuted
                volume: root.micVolume
                devices: root.sources
                activeDevice: Pipewire.defaultAudioSource
                Layout.fillWidth: true
                onToggleMute: if (root.source?.audio)
                    root.source.audio.muted = !root.micMuted
                onSetVolume: v => {
                    if (root.source?.audio)
                        root.source.audio.volume = v;
                }
                onSelectDevice: d => Pipewire.preferredDefaultAudioSource = d
            }
        }
    }
}
