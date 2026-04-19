import QtQuick
import QtQuick.Layouts

// Animated expand/collapse container with optional toggle header.
// Set label to show a clickable header with a rotating chevron.
// Put any content inside — it clips to the expanded height.
ColumnLayout {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property bool expanded: false
    property bool loading: false
    property string label: ""
    property string value: ""
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: 2

    // ── toggle header (visible when label is set) ─────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 14
        radius: theme.radiusMd
        visible: root.label !== ""
        color: headerHover.containsMouse ? theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
            }
        }

        RowLayout {
            id: headerRow
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 6
                bottomMargin: 6
            }
            spacing: 8

            Text {
                text: root.label
                color: theme.textLabel
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
            }

            Text {
                Layout.fillWidth: true
                text: root.value
                color: theme.textPrimary
                font.pixelSize: theme.fontMd
                font.family: theme.fontFamily
                elide: Text.ElideRight
                visible: root.value !== ""
            }

            // spacer when no value text
            Item {
                Layout.fillWidth: true
                visible: root.value === ""
            }

            Canvas {
                id: spinner
                width: theme.fontSm; height: theme.fontSm
                visible: root.loading
                property real angle: 0

                RotationAnimation on angle {
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 800
                    running: spinner.visible
                }

                onAngleChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    const s = width / 24;
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.scale(s, s);
                    ctx.translate(12, 12);
                    ctx.rotate(angle * Math.PI / 180);
                    ctx.translate(-12, -12);
                    ctx.beginPath();
                    ctx.arc(12, 12, 8, 0.75 * Math.PI, 0.5 * Math.PI, false);
                    ctx.strokeStyle = theme.textInactive;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.stroke();
                    ctx.restore();
                }
            }

            Text {
                text: icons.expandMore
                color: headerHover.containsMouse ? theme.textActive : theme.textLabel
                font.pixelSize: theme.fontIcon
                font.family: theme.fontIconFamily
                font.variableAxes: theme.fontIconAxes
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: theme.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: theme.animFast
                    }
                }
            }
        }

        MouseArea {
            id: headerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── collapsible content ───────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: _height
        clip: true

        property real _height: root.expanded ? inner.implicitHeight : 0
        Behavior on _height {
            NumberAnimation {
                duration: theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            id: inner
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            implicitHeight: childrenRect.height
        }
    }
}
