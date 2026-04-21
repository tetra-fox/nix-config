import qs.theme
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var player: null

    Layout.fillWidth: true
    spacing: 4

    visible: root.player?.lengthSupported === true

    Item {
        Layout.fillWidth: true
        height: seekArea.containsMouse || seekArea.pressed ? 6 : 3
        Behavior on height {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        Rectangle {
            id: seekTrack
            anchors.fill: parent
            radius: height / 2
            color: Theme.withAlpha(Theme.white, 0.1)

            Rectangle {
                id: seekFill
                width: {
                    if (seekArea.pressed)
                        return seekArea.mouseX;
                    const len = root.player?.length ?? 0;
                    const pos = root.player?.position ?? 0;
                    if (len <= 0)
                        return 0;
                    return Math.min(1, pos / len) * seekTrack.width;
                }
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            Rectangle {
                x: Math.max(0, Math.min(seekFill.width - width / 2, seekTrack.width - width))
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.accent
                visible: seekArea.containsMouse || seekArea.pressed
                scale: seekArea.pressed ? 1.2 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }
            }
        }

        MouseArea {
            id: seekArea
            anchors {
                fill: parent
                // extend hit area beyond the thin visual track
                topMargin: -6
                bottomMargin: -6
            }
            hoverEnabled: true
            cursorShape: (root.player?.canSeek ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.player?.canSeek ?? false
            function seekTo(mouseX: real) {
                const fraction = Math.max(0, Math.min(1, mouseX / seekTrack.width));
                const len = root.player?.length ?? 0;
                if (root.player && len > 0)
                    root.player.position = fraction * len;
            }
            onClicked: mouse => seekTo(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    seekTo(mouse.x);
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: {
                if (seekArea.pressed) {
                    const fraction = Math.max(0, Math.min(1, seekArea.mouseX / seekTrack.width));
                    return root.formatTime(fraction * (root.player?.length ?? 0));
                }
                return root.formatTime(root.player?.position ?? 0);
            }
            color: Theme.textInactive
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.formatTime(root.player?.length ?? 0)
            color: Theme.textInactive
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
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
