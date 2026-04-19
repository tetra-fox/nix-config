import qs.components
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

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
        icon: root.muted ? icons.volumeOff : root.volume >= 0.5 ? icons.volumeUp : root.volume >= 0.01 ? icons.volumeDown : icons.volumeMute
        iconColor: root.muted ? theme.danger : theme.textPrimary
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
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                fill: parent
                margins: theme.pillHPad
            }
            spacing: 10

            AudioSection {
                label: "Output"
                icon: root.muted ? icons.volumeOff : icons.volumeUp
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
                icon: root.micMuted ? icons.micOff : icons.mic
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
