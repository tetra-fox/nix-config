import qs.components
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Playback transport controls: shuffle, prev, play/pause, next, loop.
RowLayout {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property var player: null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing // qmllint disable unresolved-type

    signal skipped(int direction) // -1 = previous, 1 = next

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter
    spacing: 8

    MediaButton {
        visible: root.player?.shuffleSupported ?? false
        icon: icons.shuffle
        iconColor: (root.player?.shuffle ?? false) ? theme.accent : theme.textPrimary
        enabled: root.player?.canControl ?? false
        onClicked: root.player.shuffle = !root.player.shuffle
    }

    MediaButton {
        icon: icons.skipPrevious
        enabled: root.player?.canGoPrevious ?? false
        onClicked: {
            root.skipped(-1);
            root.player?.previous();
        }
    }

    MediaButton {
        icon: root.isPlaying ? icons.pause : icons.playArrow
        enabled: root.player?.canTogglePlaying ?? false
        onClicked: root.player?.togglePlaying()
        iconSize: theme.fontIconLg + 4
        size: 36
        highlight: true
    }

    MediaButton {
        icon: icons.skipNext
        enabled: root.player?.canGoNext ?? false
        onClicked: {
            root.skipped(1);
            root.player?.next();
        }
    }

    MediaButton {
        visible: root.player?.loopSupported ?? false
        icon: (root.player?.loopState === MprisLoopState.Track) ? icons.repeatOne : icons.repeat // qmllint disable unresolved-type
        iconColor: (root.player?.loopState !== MprisLoopState.None) ? theme.accent : theme.textPrimary // qmllint disable unresolved-type
        enabled: root.player?.canControl ?? false
        onClicked: root.cycleLoop()
    }

    function cycleLoop() {
        if (!root.player)
            return;
        const s = root.player.loopState;
        // None → Playlist → Track → None
        if (s === MprisLoopState.None) // qmllint disable unresolved-type
            root.player.loopState = MprisLoopState.Playlist;
            // qmllint disable unresolved-type
        else if (s === MprisLoopState.Playlist) // qmllint disable unresolved-type
            root.player.loopState = MprisLoopState.Track;
            // qmllint disable unresolved-type
        else
            root.player.loopState = MprisLoopState.None; // qmllint disable unresolved-type
    }
}
