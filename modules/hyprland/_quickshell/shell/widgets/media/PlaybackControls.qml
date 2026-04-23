import qs.lib
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var player: null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing // qmllint disable unresolved-type

    signal skipped(int direction) // -1 = previous, 1 = next

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter
    spacing: 8

    MediaButton {
        visible: root.player?.shuffleSupported ?? false
        icon: Icons.shuffle
        iconColor: (root.player?.shuffle ?? false) ? Theme.accent : Theme.textPrimary
        enabled: root.player?.canControl ?? false
        onClicked: root.player.shuffle = !root.player.shuffle
    }

    MediaButton {
        icon: Icons.skipPrevious
        enabled: root.player?.canGoPrevious ?? false
        onClicked: {
            root.skipped(-1);
            root.player?.previous();
        }
    }

    MediaButton {
        icon: root.isPlaying ? Icons.pause : Icons.playArrow
        enabled: root.player?.canTogglePlaying ?? false
        onClicked: root.player?.togglePlaying()
        iconSize: Theme.fontIconLg + 4
        size: 36
        highlight: true
    }

    MediaButton {
        icon: Icons.skipNext
        enabled: root.player?.canGoNext ?? false
        onClicked: {
            root.skipped(1);
            root.player?.next();
        }
    }

    MediaButton {
        visible: root.player?.loopSupported ?? false
        icon: (root.player?.loopState === MprisLoopState.Track) ? Icons.repeatOne : Icons.repeat // qmllint disable unresolved-type
        iconColor: (root.player?.loopState !== MprisLoopState.None) ? Theme.accent : Theme.textPrimary // qmllint disable unresolved-type
        enabled: root.player?.canControl ?? false
        onClicked: root.cycleLoop()
    }

    // qmllint disable unresolved-type
    function cycleLoop() {
        if (!root.player)
            return;
        const s = root.player.loopState;
        // None -> Playlist -> Track -> None
        if (s === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Playlist;
        else if (s === MprisLoopState.Playlist)
            root.player.loopState = MprisLoopState.Track;
        else
            root.player.loopState = MprisLoopState.None;
    }
}
