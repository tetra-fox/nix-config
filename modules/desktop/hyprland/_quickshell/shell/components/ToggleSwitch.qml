import qs.lib
import QtQuick

// pill-shaped toggle switch with click and drag support
Rectangle {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 34
    implicitHeight: 18
    radius: 9

    readonly property real _minX: 3
    readonly property real _maxX: width - knob.width - 3
    readonly property real _midX: (_minX + _maxX) / 2
    property bool _dragging: false

    function _lerp(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    color: {
        const active = hover.hovered;
        const pressed = root._dragging || tap.pressed;
        // blend between off/on colors based on knob position during drag
        const t = root._dragging ? Math.max(0, Math.min(1, (knob.x - root._minX) / (root._maxX - root._minX))) : root.checked ? 1.0 : 0.0;
        const offColor = pressed ? Theme.withAlpha(Theme.white, 0.2) : active ? Theme.withAlpha(Theme.white, 0.16) : Theme.withAlpha(Theme.white, 0.12);
        const onColor = pressed ? Theme.withAlpha(Theme.colorGreen, 0.5) : active ? Theme.withAlpha(Theme.colorGreen, 0.45) : Theme.withAlpha(Theme.colorGreen, 0.35);
        return root._lerp(offColor, onColor, t);
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Rectangle {
        id: knob
        x: root._dragging ? x : (root.checked ? root._maxX : root._minX)
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: {
            if (root._dragging)
                return knob.x > root._midX ? Theme.colorGreen : Theme.textInactive;
            return root.checked ? Theme.colorGreen : Theme.textInactive;
        }
        scale: (root._dragging || tap.pressed) ? 0.85 : hover.hovered ? 1.1 : 1.0
        Behavior on x {
            enabled: !root._dragging
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutQuad
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutQuad
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        onTapped: root.toggled()
    }

    DragHandler {
        id: drag
        target: knob
        xAxis.enabled: true
        yAxis.enabled: false
        xAxis.minimum: root._minX
        xAxis.maximum: root._maxX

        onActiveChanged: {
            if (active) {
                root._dragging = true;
            } else {
                const shouldBeChecked = knob.x > root._midX;
                if (shouldBeChecked !== root.checked)
                    root.toggled();
                // defer so x binding sees new checked state before drag ends
                Qt.callLater(() => root._dragging = false);
            }
        }
    }
}
