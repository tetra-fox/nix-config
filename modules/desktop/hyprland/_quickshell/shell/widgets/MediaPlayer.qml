pragma ComponentBehavior: Bound

import qs.components
import qs.widgets.media
import qs.lib
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    readonly property bool hasPlayer: sel.player !== null
    readonly property bool isPlaying: mpris.isPlaying

    MprisSelector {
        id: sel
        pollPosition: root.isPlaying && popup.visible
        onSwitchRequested: switchAnim.restart()
    }

    DebouncedMpris { // qmllint disable missing-property
        id: mpris
        player: sel.player
    }

    visible: hasPlayer
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

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
                    player: sel.player
                }

                PlaybackControls {
                    player: sel.player
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
                    color: (sel.player?.canRaise ?? false) ? (identityArea.containsMouse ? Theme.textPrimary : Theme.textInactive) : Theme.textInactive
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontFamily
                    font.underline: identityArea.containsMouse && (sel.player?.canRaise ?? false)
                    elide: Text.ElideRight

                    MouseArea {
                        id: identityArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (sel.player?.canRaise ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (sel.player?.canRaise)
                                sel.player.raise();
                        }
                    }
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
