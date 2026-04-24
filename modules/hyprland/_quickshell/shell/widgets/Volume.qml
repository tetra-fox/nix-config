import qs.components
import qs.lib
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

    // channelmix.lock-volumes disables software volume/mute entirely on the
    // node; reflect that so the slider doesn't look interactive when it isn't
    readonly property bool sinkLocked: sink && sink.properties && sink.properties["channelmix.lock-volumes"] === "true"
    readonly property bool sourceLocked: source && source.properties && source.properties["channelmix.lock-volumes"] === "true"

    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    IconButton {
        id: btn
        icon: {
            if (root.muted)
                return Icons.volumeOff;
            if (root.volume >= 0.5)
                return Icons.volumeUp;
            if (root.volume >= 0.01)
                return Icons.volumeDown;
            return Icons.volumeMute;
        }
        iconColor: root.muted ? Theme.danger : Theme.textPrimary
        isOpen: popup.visible
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.sink?.audio && !root.sinkLocked)
                root.sink.audio.muted = !root.muted;
            else if (mouse.button !== Qt.RightButton)
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
                devices: root.sinks
                activeDevice: Pipewire.defaultAudioSink
                Layout.fillWidth: true
                onSelectDevice: d => Pipewire.preferredDefaultAudioSink = d
            }

            Separator {}

            AudioSection {
                label: "Input"
                icon: root.micMuted ? Icons.micOff : Icons.mic
                devices: root.sources
                activeDevice: Pipewire.defaultAudioSource
                Layout.fillWidth: true
                onSelectDevice: d => Pipewire.preferredDefaultAudioSource = d
            }
        }
    }
}
