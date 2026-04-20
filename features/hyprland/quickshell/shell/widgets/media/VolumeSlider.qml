import qs.components
import QtQuick
import QtQuick.Layouts

// Per-player volume slider, visible only when the player supports volume.
RowLayout {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property var player: null

    Layout.fillWidth: true
    spacing: 8
    visible: root.player?.volumeSupported === true

    Text {
        text: icons.volumeSource
        color: theme.textInactive
        font.pixelSize: theme.fontIconLg
        font.family: theme.fontIconFamily
        font.variableAxes: theme.fontIconAxes
    }

    Item {
        Layout.fillWidth: true
        height: volArea.containsMouse || volArea.pressed ? 6 : 3
        Behavior on height {
            NumberAnimation {
                duration: theme.animFast
            }
        }

        Rectangle {
            id: volTrack
            anchors.fill: parent
            radius: height / 2
            color: theme.withAlpha(theme.white, 0.1)

            Rectangle {
                width: {
                    if (volArea.pressed)
                        return Math.max(0, Math.min(1, volArea.mouseX / volTrack.width)) * volTrack.width;
                    return (root.player?.volume ?? 1.0) * volTrack.width;
                }
                height: parent.height
                radius: parent.radius
                color: theme.accent
            }
        }

        MouseArea {
            id: volArea
            anchors {
                fill: parent
                topMargin: -6
                bottomMargin: -6
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.player?.canControl ?? false
            onClicked: mouse => {
                if (root.player)
                    root.player.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width));
            }
            onPositionChanged: mouse => {
                if (pressed && root.player)
                    root.player.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width));
            }
        }
    }

    Text {
        text: Math.round((root.player?.volume ?? 1.0) * 100) + "%"
        color: theme.textInactive
        font.pixelSize: theme.fontXs
        font.family: theme.fontFamily
        Layout.preferredWidth: 28
        horizontalAlignment: Text.AlignRight
    }
}
