import qs.components
import qs.widgets.media
import qs.lib
import QtQuick
import QtQuick.Layouts

// compact media card for the lock screen
Item {
    id: root

    MprisSelector {
        id: sel
        pollPosition: mpris.isPlaying
        onSwitchRequested: switchAnim.restart()
    }

    DebouncedMpris { // qmllint disable missing-property
        id: mpris
        player: sel.player
    }

    // -- layout --

    implicitWidth: Theme.popupWidth
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
                    player: sel.player
                    onSkipped: direction => art.slideDir = direction
                }

                SeekBar {
                    player: sel.player
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
                        duration: Theme.animNormal
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: contentSlide
                        property: "x"
                        to: sel.switchDir * -30
                        duration: Theme.animNormal
                        easing.type: Easing.InQuad
                    }
                }

                ScriptAction {
                    script: {
                        sel.commit();
                        contentSlide.x = sel.switchDir * 30;
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: playerContent
                        property: "opacity"
                        to: 1
                        duration: Theme.animNormal
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: contentSlide
                        property: "x"
                        to: 0
                        duration: Theme.animNormal
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
                    player: sel.player
                }

                MediaButton {
                    visible: sel.playerCount > 1
                    icon: Icons.chevronLeft
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: sel.selectedIndex > 0 && !switchAnim.running
                    onClicked: sel.switchTo(sel.selectedIndex - 1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: sel.titleCase(sel.player?.identity ?? "")
                    color: Theme.textInactive
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                MediaButton {
                    visible: sel.playerCount > 1
                    icon: Icons.chevronRight
                    iconSize: Theme.fontMd
                    size: 24
                    enabled: sel.selectedIndex < sel.playerCount - 1 && !switchAnim.running
                    onClicked: sel.switchTo(sel.selectedIndex + 1)
                }
            }
        }
    }
}
