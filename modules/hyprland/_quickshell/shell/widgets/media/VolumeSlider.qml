import qs.components
import qs.lib
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// icon + slider + readout row for a PwNode. compact=true = inline icon text
// (for media cards). compact=false = full IconButton (for popup sections).
RowLayout {
    id: root

    property PwNode node: Pipewire.defaultAudioSink // qmllint disable unresolved-type
    property bool compact: true
    // override the auto-selected icon (e.g. mic vs speaker). lock icon
    // always wins when _locked so callers don't need to handle it.
    property string icon: ""

    Layout.fillWidth: true
    spacing: root.compact ? 8 : 12

    PwObjectTracker {
        objects: root.node ? [root.node] : []
    }

    readonly property real _volume: node?.audio?.volume ?? 0
    readonly property bool _muted: node?.audio?.muted ?? false
    readonly property bool _locked: node && node.properties && node.properties["channelmix.lock-volumes"] === "true"

    readonly property string _icon: {
        if (root._locked)
            return Icons.lock;
        if (root.icon)
            return root.icon;
        if (root._muted)
            return Icons.volumeOff;
        if (root._volume >= 0.5)
            return Icons.volumeUp;
        if (root._volume >= 0.01)
            return Icons.volumeDown;
        return Icons.volumeMute;
    }

    readonly property color _iconColor: root._muted && !root._locked ? Theme.danger : (root.compact ? Theme.textInactive : Theme.textPrimary)

    function _toggleMute(): void {
        if (root._locked || !root.node?.audio)
            return;
        root.node.audio.muted = !root._muted;
    }

    // full variant — IconButton with animated bg
    IconButton {
        visible: !root.compact
        icon: root._icon
        iconColor: root._iconColor
        iconSize: Theme.fontIconLg
        interactive: !root._locked
        opacity: root._locked ? 0.4 : 1.0
        onClicked: _ => root._toggleMute()
    }

    // compact variant — inline text icon, no bg
    Text {
        visible: root.compact
        text: root._icon
        color: root._iconColor
        font.pixelSize: Theme.fontIconLg
        font.family: Theme.fontIconFamily
        font.variableAxes: Theme.fontIconAxes
        opacity: root._locked ? 0.4 : 1.0

        MouseArea {
            anchors.fill: parent
            enabled: !root._locked
            hoverEnabled: !root._locked
            cursorShape: root._locked ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: root._toggleMute()
        }
    }

    AudioSlider {
        Layout.fillWidth: true
        compact: root.compact
        value: root._volume
        muted: root._muted
        enabled: !root._locked
        opacity: root._locked ? 0.4 : 1.0
        onAdjusted: v => {
            if (root.node?.audio)
                root.node.audio.volume = v;
        }
    }

    Text {
        text: root._locked ? "-" : Math.round(root._volume * 100) + "%"
        color: root.compact ? Theme.textInactive : Theme.textSecondary
        font.pixelSize: root.compact ? Theme.fontXs : Theme.fontMd
        font.family: Theme.fontFamily
        Layout.preferredWidth: root.compact ? 32 : 40
        horizontalAlignment: Text.AlignRight
    }
}
