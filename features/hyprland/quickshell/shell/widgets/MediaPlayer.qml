pragma ComponentBehavior: Bound

import qs.components
import qs.widgets.media
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

    readonly property var players: Mpris.players.values // qmllint disable unresolved-type
    readonly property int playerCount: players ? players.length : 0
    property int selectedIndex: 0
    property int _targetIndex: 0
    property int _switchDir: 0

    function switchTo(idx: int) {
        root._switchDir = idx > root.selectedIndex ? 1 : -1;
        root._targetIndex = idx;
        switchAnim.restart();
    }

    // clamp index when player list changes
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
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing // qmllint disable unresolved-type

    // debounced display properties — update immediately on new data,
    // delay clearing so track changes don't flash "No title"
    readonly property string _rawTitle: player?.trackTitle ?? ""
    readonly property string _rawArtist: player?.trackArtist ?? ""
    readonly property string _rawAlbum: player?.trackAlbum ?? ""
    readonly property string _rawArtUrl: player?.trackArtUrl ?? ""

    property string title: _rawTitle
    property string artist: _rawArtist
    property string album: _rawAlbum
    property string artUrl: _rawArtUrl

    on_RawTitleChanged: {
        if (_rawTitle !== "")
            root.title = _rawTitle;
        else
            clearDelay.restart();
    }
    on_RawArtistChanged: {
        if (_rawArtist !== "")
            root.artist = _rawArtist;
        else
            clearDelay.restart();
    }
    on_RawAlbumChanged: {
        if (_rawAlbum !== "")
            root.album = _rawAlbum;
        else
            clearDelay.restart();
    }
    on_RawArtUrlChanged: {
        if (_rawArtUrl !== "")
            root.artUrl = _rawArtUrl;
        else
            clearDelay.restart();
    }

    Timer {
        id: clearDelay
        interval: 800
        onTriggered: {
            root.title = root._rawTitle;
            root.artist = root._rawArtist;
            root.album = root._rawAlbum;
            root.artUrl = root._rawArtUrl;
        }
    }

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

    // ── floating notes particle effect ──────────────────────────────────────
    FloatingNotes {
        anchors.centerIn: btn
        width: 70
        height: 50
        active: root.isPlaying && !popup.visible
    }

    // ── popup ───────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 300
        contentHeight: col.implicitHeight + theme.pillHPad * 2
        animateSize: true

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: theme.pillHPad
            }
            spacing: 10

            // ── player content (animated on switch) ─────────────────────
            ColumnLayout {
                id: playerContent
                Layout.fillWidth: true
                spacing: 10
                clip: true

                transform: Translate {
                    id: contentSlide
                }

                // ── album art (crossfade on track change) ──────────────
                Rectangle {
                    id: artContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    radius: theme.radiusMd
                    color: theme.withAlpha(theme.white, 0.06)
                    clip: true
                    visible: artA.status === Image.Ready || artB.status === Image.Ready

                    property bool showingA: true
                    property int slideDir: 1 // 1 = forward (slide left), -1 = backward (slide right)

                    Image {
                        id: artA
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        opacity: 1
                        transform: Translate {
                            id: slideA
                        }
                    }

                    Image {
                        id: artB
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        opacity: 0
                        transform: Translate {
                            id: slideB
                        }
                    }

                    // A out + B in
                    ParallelAnimation {
                        id: transitionAtoB
                        NumberAnimation {
                            target: artA
                            property: "opacity"
                            to: 0
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: slideA
                            property: "x"
                            from: 0
                            to: -artContainer.slideDir * artContainer.width
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: artB
                            property: "opacity"
                            to: 1
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: slideB
                            property: "x"
                            from: artContainer.slideDir * artContainer.width
                            to: 0
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }

                    // B out + A in
                    ParallelAnimation {
                        id: transitionBtoA
                        NumberAnimation {
                            target: artB
                            property: "opacity"
                            to: 0
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: slideB
                            property: "x"
                            from: 0
                            to: -artContainer.slideDir * artContainer.width
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: artA
                            property: "opacity"
                            to: 1
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                        NumberAnimation {
                            target: slideA
                            property: "x"
                            from: artContainer.slideDir * artContainer.width
                            to: 0
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }

                    function transition() {
                        if (artContainer.showingA) {
                            transitionAtoB.restart();
                        } else {
                            transitionBtoA.restart();
                        }
                        artContainer.showingA = !artContainer.showingA;
                    }

                    Connections {
                        target: artA
                        function onStatusChanged() {
                            if (!artContainer.showingA && artA.status === Image.Ready)
                                artContainer.transition();
                        }
                    }

                    Connections {
                        target: artB
                        function onStatusChanged() {
                            if (artContainer.showingA && artB.status === Image.Ready)
                                artContainer.transition();
                        }
                    }
                }

                Connections {
                    target: root
                    function onArtUrlChanged() {
                        if (root.artUrl === "")
                            return;
                        // first load — no animation
                        if (String(artA.source) === "" && String(artB.source) === "") {
                            artA.source = root.artUrl;
                            return;
                        }
                        // load into whichever image is NOT currently showing
                        if (artContainer.showingA)
                            artB.source = root.artUrl;
                        else
                            artA.source = root.artUrl;
                    }
                }

                // ── track info ──────────────────────────────────────────
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

                    Text {
                        visible: root.album !== ""
                        text: root.album
                        color: theme.textInactive
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        opacity: 0.7
                    }
                }

                // ── seek bar ────────────────────────────────────────────
                SeekBar {
                    player: root.player
                }

                // ── playback controls ───────────────────────────────────
                PlaybackControls {
                    player: root.player
                    onSkipped: direction => artContainer.slideDir = direction
                }

                // ── volume ──────────────────────────────────────────────
                VolumeSlider {
                    player: root.player
                }
            }

            // ── switch animation ────────────────────────────────────────
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

            // ── player identity / switcher ──────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                SpeedControl {
                    player: root.player
                }

                MediaButton {
                    visible: root.playerCount > 1
                    icon: icons.chevronLeft
                    iconSize: theme.fontMd
                    size: 24
                    enabled: root.selectedIndex > 0 && !switchAnim.running
                    onClicked: root.switchTo(root.selectedIndex - 1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.titleCase(root.player?.identity ?? "")
                    color: (root.player?.canRaise ?? false) ? (identityArea.containsMouse ? theme.textPrimary : theme.textInactive) : theme.textInactive
                    font.pixelSize: theme.fontXs
                    font.family: theme.fontFamily
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
                    icon: icons.chevronRight
                    iconSize: theme.fontMd
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
