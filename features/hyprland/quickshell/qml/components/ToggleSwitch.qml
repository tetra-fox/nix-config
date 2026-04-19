import QtQuick

// Pill-shaped toggle switch — click or drag the knob to toggle.
Rectangle {
    id: root

    Theme {
        id: theme
    }

    property bool checked: false
    signal toggled

    implicitWidth: 34
    implicitHeight: 18
    radius: 9

    readonly property real _minX: 3
    readonly property real _maxX: width - knob.width - 3
    readonly property real _midX: (_minX + _maxX) / 2
    property bool _dragging: false

    color: {
        const active = hover.hovered;
        const pressed = root._dragging || tap.pressed;
        // during drag, blend between off/on colors based on knob position
        const t = root._dragging
            ? Math.max(0, Math.min(1, (knob.x - root._minX) / (root._maxX - root._minX)))
            : root.checked ? 1.0 : 0.0;
        const offColor = pressed
            ? theme.withAlpha(theme.white, 0.2)
            : active
                ? theme.withAlpha(theme.white, 0.16)
                : theme.withAlpha(theme.white, 0.12);
        const onColor = pressed
            ? theme.withAlpha(theme.colorGreen, 0.5)
            : active
                ? theme.withAlpha(theme.colorGreen, 0.45)
                : theme.withAlpha(theme.colorGreen, 0.35);
        return Qt.rgba(
            offColor.r + (onColor.r - offColor.r) * t,
            offColor.g + (onColor.g - offColor.g) * t,
            offColor.b + (onColor.b - offColor.b) * t,
            offColor.a + (onColor.a - offColor.a) * t
        );
    }
    Behavior on color { ColorAnimation { duration: theme.animFast } }

    Rectangle {
        id: knob
        x: root._dragging ? x : (root.checked ? root._maxX : root._minX)
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 12; radius: 6
        color: {
            if (root._dragging)
                return knob.x > root._midX ? theme.colorGreen : theme.textInactive;
            return root.checked ? theme.colorGreen : theme.textInactive;
        }
        scale: (root._dragging || tap.pressed) ? 0.85 : hover.hovered ? 1.1 : 1.0
        Behavior on x {
            enabled: !root._dragging
            NumberAnimation { duration: theme.animNormal; easing.type: Easing.OutQuad }
        }
        Behavior on color { ColorAnimation { duration: theme.animNormal } }
        Behavior on scale { NumberAnimation { duration: theme.animFast; easing.type: Easing.OutQuad } }
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
                // defer releasing drag so the x binding sees the new checked state
                Qt.callLater(() => root._dragging = false);
            }
        }
    }
}
