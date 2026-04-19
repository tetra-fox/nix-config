pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property var panelWindow

    // pick the first player, preferring one that's actively playing
    readonly property var players: Mpris.players.values // qmllint disable unresolved-type
    readonly property MprisPlayer player: { // qmllint disable unresolved-type
        const ps = root.players;
        if (!ps || ps.length === 0)
            return null;
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]; // qmllint disable unresolved-type
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing // qmllint disable unresolved-type
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""

    visible: hasPlayer
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // ── position tracking ───────────────────────────────────────────────────
    Timer {
        running: root.isPlaying && root.player?.positionSupported === true && popup.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // ── bar button ──────────────────────────────────────────────────────────
    IconButton {
        id: btn
        icon: icons.musicNote
        iconColor: root.isPlaying ? theme.accent : theme.textPrimary
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    // ── popup ───────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 300
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: theme.pillHPad
            }
            spacing: 10

            // ── album art ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width
                radius: theme.radiusMd
                color: theme.withAlpha(theme.white, 0.06)
                clip: true
                visible: artImg.status === Image.Ready

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            // ── track info ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                MarqueeText {
                    text: root.title || "No title"
                    color: theme.textPrimary
                    font.pixelSize: theme.fontBase
                    font.family: theme.fontFamily
                    font.bold: true
                    hovered: popup.visible
                    Layout.fillWidth: true
                }

                Text {
                    text: root.artist || "Unknown artist"
                    color: theme.textInactive
                    font.pixelSize: theme.fontSm
                    font.family: theme.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // ── seek bar ────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.player?.lengthSupported === true

                Item {
                    Layout.fillWidth: true
                    height: seekArea.containsMouse || seekArea.pressed ? 6 : 3
                    Behavior on height {
                        NumberAnimation {
                            duration: theme.animFast
                        }
                    }

                    Rectangle {
                        id: seekTrack
                        anchors.fill: parent
                        radius: height / 2
                        color: theme.withAlpha(theme.white, 0.1)

                        Rectangle {
                            id: seekFill
                            width: {
                                if (seekArea.pressed)
                                    return seekArea.mouseX / seekTrack.width * seekTrack.width;
                                const len = root.player?.length ?? 0;
                                const pos = root.player?.position ?? 0;
                                if (len <= 0)
                                    return 0;
                                return Math.min(1, pos / len) * seekTrack.width;
                            }
                            height: parent.height
                            radius: parent.radius
                            color: theme.accent
                        }

                        // seek handle
                        Rectangle {
                            x: Math.max(0, Math.min(seekFill.width - width / 2, seekTrack.width - width))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: theme.accent
                            visible: seekArea.containsMouse || seekArea.pressed
                            scale: seekArea.pressed ? 1.2 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: theme.animFast
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: seekArea
                        anchors {
                            fill: parent
                            topMargin: -6
                            bottomMargin: -6
                        }
                        hoverEnabled: true
                        cursorShape: (root.player?.canSeek ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.player?.canSeek ?? false
                        onClicked: mouse => {
                            const fraction = Math.max(0, Math.min(1, mouse.x / seekTrack.width));
                            const len = root.player?.length ?? 0;
                            if (root.player && len > 0)
                                root.player.position = fraction * len;
                        }
                        onPositionChanged: mouse => {
                            if (pressed) {
                                const fraction = Math.max(0, Math.min(1, mouse.x / seekTrack.width));
                                const len = root.player?.length ?? 0;
                                if (root.player && len > 0)
                                    root.player.position = fraction * len;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(seekArea.pressed ? (Math.max(0, Math.min(1, seekArea.mouseX / seekTrack.width)) * (root.player?.length ?? 0)) : (root.player?.position ?? 0))
                        color: theme.textInactive
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.formatTime(root.player?.length ?? 0)
                        color: theme.textInactive
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                    }
                }
            }

            // ── playback controls ───────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                MediaButton {
                    icon: icons.skipPrevious
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()
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
                    onClicked: root.player?.next()
                }
            }

            // ── player identity ─────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.player?.identity ?? ""
                color: theme.textInactive
                font.pixelSize: theme.fontXs
                font.family: theme.fontFamily
            }
        }
    }

    function formatTime(seconds: real): string {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // ── popup control button ────────────────────────────────────────────────
    component MediaButton: Item {
        id: mbRoot

        Theme {
            id: mbTheme
        }

        property string icon
        property int iconSize: mbTheme.fontIconLg
        property int size: 32
        property bool enabled: true
        property bool highlight: false

        signal clicked

        implicitWidth: mbBg.width
        implicitHeight: mbBg.height
        opacity: enabled ? 1.0 : 0.3

        Rectangle {
            id: mbBg
            width: mbRoot.size
            height: mbRoot.size
            radius: mbRoot.size / 2
            color: {
                if (mbRoot.highlight)
                    return mbArea.pressed ? Qt.darker(mbTheme.accent, 1.3) : mbArea.containsMouse ? Qt.lighter(mbTheme.accent, 1.2) : mbTheme.accent;
                return mbArea.pressed ? mbTheme.pressedBg : mbArea.containsMouse ? mbTheme.hoverBg : "transparent";
            }
            Behavior on color {
                ColorAnimation {
                    duration: mbTheme.animFast
                }
            }

            Text {
                anchors.centerIn: parent
                text: mbRoot.icon
                color: mbRoot.highlight ? mbTheme.black : mbTheme.textPrimary
                font.pixelSize: mbRoot.iconSize
                font.family: mbTheme.fontIconFamily
                font.variableAxes: mbTheme.fontIconAxes
            }

            MouseArea {
                id: mbArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: mbRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (mbRoot.enabled)
                    mbRoot.clicked()
            }
        }
    }
}
