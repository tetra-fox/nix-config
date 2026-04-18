import Quickshell.Io
import QtQuick

// right-aligned text that copies to clipboard on click, with a floating "copied" toast
Item {
    id: root

    Theme { id: theme }

    property alias text:  innerText.text
    property alias elide: innerText.elide

    implicitWidth:  innerText.implicitWidth
    implicitHeight: innerText.implicitHeight

    Text {
        id: innerText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width)

        font.pixelSize: theme.fontSm
        font.family:    theme.fontFamily
        color: area.containsMouse ? theme.accent : theme.textPrimary
        Behavior on color { ColorAnimation { duration: theme.animFast } }
    }

    Process {
        id: clip
        command: ["wl-copy", innerText.text]
    }

    MouseArea {
        id: area
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  innerText.width
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (innerText.text && innerText.text !== "-") {
                clip.running = true
                floatAnim.restart()
            }
        }
    }

    // "copied" toast
    Item {
        id: toast
        z: 999
        opacity: 0
        width:  label.implicitWidth + 10
        height: label.implicitHeight + 5
        x: innerText.x + innerText.width / 2 - width / 2
        y: -(height + 4)

        Rectangle {
            anchors.fill: parent
            radius:       theme.radiusSm
            color:        theme.panelBg
            border.width: 1
            border.color: theme.panelBorder
        }

        Text {
            id: label
            anchors.centerIn: parent
            text:           "copied"
            color:          theme.textPrimary
            font.pixelSize: theme.fontXs
            font.family:    theme.fontFamily
        }
    }

    ParallelAnimation {
        id: floatAnim
        NumberAnimation { target: toast; property: "opacity"; from: 1.0; to: 0.0; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: toast; property: "y"; from: -(toast.height + 4); to: -(toast.height + 22); duration: 700; easing.type: Easing.OutCubic }
    }
}
