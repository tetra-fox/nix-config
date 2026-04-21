import qs.theme
import Quickshell.Io
import QtQuick

// right-aligned text that copies to clipboard on click
Item {
    id: root

    property alias text: innerText.text
    property alias elide: innerText.elide
    property bool disabled: false
    property color baseColor: Theme.textPrimary

    implicitWidth: innerText.implicitWidth
    implicitHeight: innerText.implicitHeight

    Text {
        id: innerText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width)

        font.pixelSize: Theme.fontSm
        font.family: Theme.fontFamily
        color: root.disabled ? Theme.textInactive : area.containsMouse ? Theme.accent : root.baseColor
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }
    }

    Process {
        id: clip
        command: ["wl-copy", innerText.text]
    }

    MouseArea {
        id: area
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: innerText.width
        hoverEnabled: !root.disabled
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!root.disabled && innerText.text) {
                clip.running = true;
                floatAnim.restart();
            }
        }
    }

    Item {
        id: toast
        z: 999
        opacity: 0
        width: label.implicitWidth + 10
        height: label.implicitHeight + 5
        x: innerText.x + innerText.width / 2 - width / 2
        y: -(height + 4)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSm
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: "copied"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
        }
    }

    ParallelAnimation {
        id: floatAnim
        NumberAnimation {
            target: toast
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 700
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: toast
            property: "y"
            from: -(toast.height + 4)
            to: -(toast.height + 22)
            duration: 700
            easing.type: Easing.OutCubic
        }
    }
}
