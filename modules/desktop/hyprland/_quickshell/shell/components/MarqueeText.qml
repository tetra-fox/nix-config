import QtQuick

// scrolls horizontally on hover when text overflows
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font

    property bool hovered: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflows: label.implicitWidth > root.width
    // +8 so text doesn't butt against the clip edge at max scroll
    readonly property real scrollDist: Math.max(0, label.implicitWidth - root.width + 8)

    Text {
        id: label

        SequentialAnimation on x {
            id: scrollAnim
            running: root.hovered && root.overflows
            loops: Animation.Infinite

            PauseAnimation {
                duration: 700
            }
            NumberAnimation {
                to: -root.scrollDist
                // 18ms per pixel - constant scroll speed regardless of text length
                duration: root.scrollDist * 18
                easing.type: Easing.Linear
            }
            PauseAnimation {
                duration: 700
            }
            NumberAnimation {
                to: 0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        NumberAnimation on x {
            id: resetAnim
            running: !root.hovered && label.x !== 0
            to: 0
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
}
