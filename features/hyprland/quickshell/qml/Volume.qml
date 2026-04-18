import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    Theme { id: theme }

    property var panelWindow

    implicitWidth:  btn.implicitWidth
    implicitHeight: btn.implicitHeight

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    PwObjectTracker { objects: [...sinks, ...sources] }

    readonly property PwNode sink:   Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume:    sink?.audio?.volume   ?? 0
    readonly property bool muted:     sink?.audio?.muted    ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted:  source?.audio?.muted  ?? false

    readonly property list<PwNode> sinks:   Pipewire.nodes.values.filter(n =>  n.isSink && !n.isStream && n.audio !== null)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio !== null)

    BarButton {
        id: btn
        icon: root.muted ? "󰝟" : root.volume >= 0.5 ? "󰕾" : root.volume >= 0.01 ? "󰖀" : "󰕿"
        iconColor: root.muted ? theme.danger : theme.textPrimary
        isOpen: popup.visible
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.sink.audio.muted = !root.muted
            else
                popup.visible = !popup.visible
        }
    }

    PopupPanel {
        id: popup
        panelWindow: root.panelWindow

        implicitWidth:  320
        implicitHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors { fill: parent; margins: theme.pillHPad }
            spacing: 20

            AudioSection {
                label: "Output"
                icon:  root.muted ? "󰝟" : "󰕾"
                muted: root.muted
                volume: root.volume
                devices: root.sinks
                activeDevice: Pipewire.defaultAudioSink
                Layout.fillWidth: true
                onToggleMute:  root.sink.audio.muted = !root.muted
                onSetVolume:   v => root.sink.audio.volume = v
                onSelectDevice: d => Pipewire.preferredDefaultAudioSink = d
            }

            Separator { color: theme.inactiveBg }

            AudioSection {
                label: "Input"
                icon:  root.micMuted ? "󰍭" : "󰍬"
                muted: root.micMuted
                volume: root.micVolume
                devices: root.sources
                activeDevice: Pipewire.defaultAudioSource
                Layout.fillWidth: true
                onToggleMute:  root.source.audio.muted = !root.micMuted
                onSetVolume:   v => root.source.audio.volume = v
                onSelectDevice: d => Pipewire.preferredDefaultAudioSource = d
            }
        }
    }
}
