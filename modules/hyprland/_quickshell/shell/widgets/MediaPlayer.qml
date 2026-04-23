pragma ComponentBehavior: Bound

import qs.components
import qs.widgets.media
import qs.lib
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    readonly property var players: Mpris.players.values // qmllint disable unresolved-type
    readonly property int playerCount: players ? players.length : 0
    property int selectedIndex: 0
    // stored separately so the animation can slide out first, then swap
    property int _targetIndex: 0
    property int _switchDir: 0

    function switchTo(idx: int) {
        root._switchDir = idx > root.selectedIndex ? 1 : -1;
        root._targetIndex = idx;
        switchAnim.restart();
    }

    onPlayerCountChanged: {
        if (selectedIndex >= playerCount)
            selectedIndex = Math.max(0, playerCount - 1);
        if (_targetIndex >= playerCount)
            _targetIndex = Math.max(0, playerCount - 1);
    }

    readonly property MprisPlayer player: { // qmllint disable unresolved-type
        const ps = root.players;
        if (!ps || ps.length === 0)
            return null;
        return ps[Math.max(0, Math.min(root.selectedIndex, ps.length - 1))];
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: mpris.isPlaying

    DebouncedMpris { // qmllint disable missing-property
        id: mpris
        player: root.player
    }

    visible: hasPlayer
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // mpris doesn't push position updates, so poll once per second while
    // playing and visible to keep the seek bar moving
    Timer {
        running: root.isPlaying && root.player?.positionSupported === true && popup.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    IconButton {
        id: btn
        icon: Icons.musicNote
        iconColor: root.isPlaying ? Theme.accent : Theme.textPrimary
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    FloatingNotes {
        anchors.centerIn: btn
        width: 70
        height: 50
        active: root.isPlaying && !popup.visible
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 300
        contentHeight: col.implicitHeight + Theme.pillHPad * 2
        animateSize: true

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 10

            ColumnLayout {
                id: playerContent
                Layout.fillWidth: true
                spacing: 10
                clip: true

                transform: Translate {
                    id: contentSlide
                }

                CrossfadeArt {
                    id: art
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    // nested radius = outer radius - distance from outer edge
                    radius: Math.max(0, Theme.radiusLg - Theme.pillHPad)
                    source: mpris.artUrl
                    visible: art.ready
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MarqueeText {
                        text: mpris.title || "No title"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBase
                        font.family: Theme.fontFamily
                        font.bold: true
                        hovered: popup.visible
                        Layout.fillWidth: true
                    }

                    Text {
                        text: mpris.artist || "Unknown artist"
                        color: Theme.textInactive
                        font.pixelSize: Theme.fontSm
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: mpris.album !== ""
                        text: mpris.album
                        color: Theme.textInactive
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        opacity: 0.7
                    }
                }

                SeekBar {
                    player: root.player
                }

                PlaybackControls {
                    player: root.player
                    onSkipped: direction => art.slideDir = direction
                }

                VolumeSlider {}
            }

            SequentialAnimation {
                id: switchAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: playerContent
                        property: "opacity"
                        to: 0
                        duration: 120
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: contentSlide
                        property: "x"
                        to: root._switchDir * -30
                        duration: 120
                        easing.type: Easing.InQuad
                    }
                }

                ScriptAction {
                    script: {
                        root.selectedIndex = root._targetIndex;
                        contentSlide.x = root._switchDir * 30;
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: playerContent
                        property: "opacity"
                        to: 1
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: contentSlide
                        property: "x"
                        to: 0
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                SpeedControl {
                    player: root.player
                }

                MediaButton {
                    visible: root.playerCount > 1
                    icon: Icons.chevronLeft
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: root.selectedIndex > 0 && !switchAnim.running
                    onClicked: root.switchTo(root.selectedIndex - 1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.titleCase(root.player?.identity ?? "")
                    color: (root.player?.canRaise ?? false) ? (identityArea.containsMouse ? Theme.textPrimary : Theme.textInactive) : Theme.textInactive
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontFamily
                    font.underline: identityArea.containsMouse && (root.player?.canRaise ?? false)
                    elide: Text.ElideRight

                    MouseArea {
                        id: identityArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.player?.canRaise ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.player?.canRaise)
                                root.player.raise();
                        }
                    }
                }

                MediaButton {
                    visible: root.playerCount > 1
                    icon: Icons.chevronRight
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: root.selectedIndex < root.playerCount - 1 && !switchAnim.running
                    onClicked: root.switchTo(root.selectedIndex + 1)
                }
            }
        }
    }

    function titleCase(s: string): string {
        return s.replace(/\b\w/g, c => c.toUpperCase());
    }
}
