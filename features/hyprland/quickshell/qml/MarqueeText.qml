import QtQuick

// scrolls horizontally on hover when the content doesn't fit
Item {
    id: root

    property alias text:  label.text
    property alias color: label.color
    property alias font:  label.font

    property bool hovered: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflows: label.implicitWidth > root.width
    readonly property real scrollDist: Math.max(0, label.implicitWidth - root.width + 8)

    Text {
        id: label
        x: 0

        // scroll forward then snap back, loops while hovered and overflowing
        SequentialAnimation on x {
            id: scrollAnim
            running: root.hovered && root.overflows
            loops: Animation.Infinite

            PauseAnimation   { duration: 700 }
            NumberAnimation  { to: -root.scrollDist; duration: root.scrollDist * 18; easing.type: Easing.Linear }
            PauseAnimation   { duration: 700 }
            NumberAnimation  { to: 0; duration: 300; easing.type: Easing.InOutQuad }
        }

        // snap back when hover ends mid-scroll
        NumberAnimation on x {
            id: resetAnim
            running: !root.hovered && label.x !== 0
            to: 0
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
}
