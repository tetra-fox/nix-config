import qs.lib
import QtQuick

// scrollable column with gradient fade edges on overflow
Item {
    id: root

    property int maxItems: 8
    property int spacing: 0
    default property alias content: contentCol.data

    implicitHeight: Math.min(contentCol.implicitHeight, maxItems * Theme.popupItemHeight)

    function ensureVisible(item) {
        const mapped = item.mapToItem(contentCol, 0, 0);
        const itemBottom = mapped.y + item.height;
        const viewBottom = flick.scrollTarget + flick.height;
        if (itemBottom > viewBottom) {
            flick.scrollTarget = Math.min(itemBottom - flick.height, flick.contentHeight - flick.height);
            scrollAnim.restart();
        }
    }

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
                // 0.4 converts angle delta (120 per notch) to ~48px per scroll notch
                const step = event.pixelDelta.y !== 0 ? -event.pixelDelta.y : -event.angleDelta.y * 0.4;
                flick.scrollTarget = Math.max(0, Math.min(maxY, flick.scrollTarget + step));
                scrollAnim.restart();
            }
        }

        Column {
            id: contentCol
            width: flick.width
            spacing: root.spacing
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 24
        visible: flick.contentY > 1
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.panelBg
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 24
        visible: flick.contentY < flick.contentHeight - flick.height - 1
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Theme.panelBg
            }
        }
    }
}
