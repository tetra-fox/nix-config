import qs.lib
import QtQuick

Item {
    id: root

    property int maxItems: 8
    // overrides maxItems when > 0, for non-uniform row heights
    property int maxHeight: 0
    property int spacing
    default property alias content: contentCol.data

    implicitHeight: Math.min(contentCol.implicitHeight, maxHeight > 0 ? maxHeight : maxItems * Theme.popupItemHeight)

    function ensureVisible(item) {
        // Column defers relayout to a polish pass
        contentCol.forceLayout();
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
            duration: Theme.animSlow
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const maxY = flick.contentHeight - flick.height;
                // angleDelta is 120 per notch, so ~48px
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
