import Quickshell.Services.Mpris
import QtQuick

// selection state over the mpris player list, shared by the bar media popup
// and the lock screen card. non-visual: the owner provides the slide animation,
// restarts it from switchRequested, and calls commit() once slid out
QtObject {
    id: root

    readonly property var players: Mpris.players.values // qmllint disable unresolved-type
    readonly property int playerCount: players.length
    property int selectedIndex: 0
    // the switch animation slides out first, then commits the swap
    property int targetIndex: 0
    property int switchDir: 0

    signal switchRequested

    readonly property MprisPlayer player: { // qmllint disable unresolved-type
        const ps = root.players;
        if (ps.length === 0)
            return null;
        return ps[Math.max(0, Math.min(root.selectedIndex, ps.length - 1))];
    }

    function switchTo(idx: int): void {
        root.switchDir = idx > root.selectedIndex ? 1 : -1;
        root.targetIndex = idx;
        root.switchRequested();
    }

    function commit(): void {
        root.selectedIndex = root.targetIndex;
    }

    // follow the selected player object across list changes; a plain index
    // would silently show a different player when an earlier one vanishes
    property var _lastPlayer: null
    onPlayerChanged: _lastPlayer = player
    onPlayersChanged: {
        if (root._lastPlayer) {
            const idx = root.players.indexOf(root._lastPlayer);
            if (idx >= 0 && idx !== root.selectedIndex)
                root.selectedIndex = idx;
        }
        if (root.selectedIndex >= root.playerCount)
            root.selectedIndex = Math.max(0, root.playerCount - 1);
        if (root.targetIndex >= root.playerCount)
            root.targetIndex = Math.max(0, root.playerCount - 1);
    }

    // mpris doesn't push position updates, so poll while the owner says the
    // seek bar is visible and moving
    property bool pollPosition: false
    property Timer _positionPoll: Timer {
        running: root.pollPosition && (root.player?.positionSupported ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function titleCase(s: string): string {
        return s.replace(/\b\w/g, c => c.toUpperCase());
    }
}
