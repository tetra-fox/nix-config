import QtQuick

// Scrollable container with fade edges. Clips content to maxHeight
// and shows gradient fades when content overflows.
Item {
    id: root

    Theme {
        id: theme
    }

    property int maxItems: 8
    default property alias content: contentCol.data

    implicitHeight: Math.min(contentCol.implicitHeight, maxItems * theme.popupItemHeight)

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        property real scrollTarget: contentY

        NumberAnimation {
            id: scrollAnim
            target: flick
            property: "contentY"
            to: flick.scrollTarget
            duration: 150
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const maxY = flick.contentHeight - flick.height;
                const step = event.pixelDelta.y !== 0 ? -event.pixelDelta.y : -event.angleDelta.y * 0.4;
                flick.scrollTarget = Math.max(0, Math.min(maxY, flick.scrollTarget + step));
                scrollAnim.restart();
            }
        }

        Column {
            id: contentCol
            width: flick.width
            spacing: 0
        }
    }

    // fade edges
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 24
        visible: flick.contentY > 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.panelBg }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 24
        visible: flick.contentY < flick.contentHeight - flick.height - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: theme.panelBg }
        }
    }
}
