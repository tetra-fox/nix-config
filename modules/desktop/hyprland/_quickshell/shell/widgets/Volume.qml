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
        // the full device lists only render in the popup; don't keep every
        // node's properties subscribed while it is closed
        objects: popup.visible ? [...root.sinks, ...root.sources] : []
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property bool sinkLocked: Audio.locked(sink)

    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    IconButton {
        id: btn
        icon: Icons.forVolume(root.volume, root.muted)
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

        contentWidth: Theme.popupWidth
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
                activeDevice: root.sink
                Layout.fillWidth: true
                onSelectDevice: d => Pipewire.preferredDefaultAudioSink = d
            }

            Separator {}

            AudioSection {
                label: "Input"
                icon: root.micMuted ? Icons.micOff : Icons.mic
                devices: root.sources
                activeDevice: root.source
                Layout.fillWidth: true
                onSelectDevice: d => Pipewire.preferredDefaultAudioSource = d
            }
        }
    }
}
