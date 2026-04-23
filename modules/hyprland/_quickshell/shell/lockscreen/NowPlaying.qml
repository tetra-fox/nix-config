import qs.components
import qs.widgets.media
import qs.lib
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// compact media card for the lock screen
Item {
    id: root

    // -- player management --

    readonly property var _players: Mpris.players.values // qmllint disable unresolved-type
    readonly property int _playerCount: _players ? _players.length : 0
    property int _selectedIndex: 0
    property int _targetIndex: 0
    property int _switchDir: 0

    function _switchTo(idx: int) {
        root._switchDir = idx > root._selectedIndex ? 1 : -1;
        root._targetIndex = idx;
        switchAnim.restart();
    }

    on_PlayerCountChanged: {
        if (_selectedIndex >= _playerCount)
            _selectedIndex = Math.max(0, _playerCount - 1);
        if (_targetIndex >= _playerCount)
            _targetIndex = Math.max(0, _playerCount - 1);
    }

    readonly property MprisPlayer _player: { // qmllint disable unresolved-type
        const ps = root._players;
        if (!ps || ps.length === 0)
            return null;
        return ps[Math.max(0, Math.min(root._selectedIndex, ps.length - 1))];
    }

    DebouncedMpris { // qmllint disable missing-property
        id: mpris
        player: root._player
    }

    // mpris doesn't push position updates, so poll while playing
    Timer {
        running: mpris.isPlaying && root._player?.positionSupported === true
        interval: 1000
        repeat: true
        onTriggered: root._player?.positionChanged()
    }

    // -- layout --

    implicitWidth: 320
    implicitHeight: mpris.hasMedia ? card.height : 0
    opacity: mpris.hasMedia ? 1 : 0
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        id: card
        width: root.implicitWidth
        height: cardCol.implicitHeight + 24
        radius: 12
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder

        ColumnLayout {
            id: cardCol
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 12
            }
            spacing: 8

            ColumnLayout {
                id: playerContent
                Layout.fillWidth: true
                spacing: 8
                clip: true

                transform: Translate {
                    id: contentSlide
                }

                // compact header: small art + title/artist
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    CrossfadeArt {
                        id: art
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: Theme.radiusMd
                        source: mpris.artUrl

                        // fallback icon when no art available
                        Text {
                            anchors.centerIn: parent
                            text: Icons.musicNote
                            color: Theme.textInactive
                            font.pixelSize: 24
                            font.family: Theme.fontIconFamily
                            font.variableAxes: Theme.fontIconAxes
                            visible: !art.ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: mpris.title || "No title"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBase
                            font.family: Theme.fontFamily
                            font.bold: true
                            elide: Text.ElideRight
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
                    }
                }

                PlaybackControls {
                    player: root._player
                    onSkipped: direction => art.slideDir = direction
                }

                SeekBar {
                    player: root._player
                }

                VolumeSlider {}
            }

            // -- switch animation --

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
                        root._selectedIndex = root._targetIndex;
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

            // -- bottom row: speed + player switching --

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                SpeedControl {
                    player: root._player
                }

                MediaButton {
                    visible: root._playerCount > 1
                    icon: Icons.chevronLeft
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: root._selectedIndex > 0 && !switchAnim.running
                    onClicked: root._switchTo(root._selectedIndex - 1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root._titleCase(root._player?.identity ?? "")
                    color: Theme.textInactive
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                MediaButton {
                    visible: root._playerCount > 1
                    icon: Icons.chevronRight
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: root._selectedIndex < root._playerCount - 1 && !switchAnim.running
                    onClicked: root._switchTo(root._selectedIndex + 1)
                }
            }
        }
    }

    function _titleCase(s: string): string {
        return s.replace(/\b\w/g, c => c.toUpperCase());
    }
}
