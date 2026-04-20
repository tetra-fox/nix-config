import qs.components
import QtQuick
import QtQuick.Layouts

// Seek bar with position/length display and draggable handle.
ColumnLayout {
    id: root

    Theme {
        id: theme
    }

    property var player: null

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

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const total = Math.floor(seconds);
        const hrs = Math.floor(total / 3600);
        const mins = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        const mm = hrs > 0 ? String(mins).padStart(2, "0") : String(mins);
        const ss = String(secs).padStart(2, "0");
        return hrs > 0 ? hrs + ":" + mm + ":" + ss : mm + ":" + ss;
    }
}
