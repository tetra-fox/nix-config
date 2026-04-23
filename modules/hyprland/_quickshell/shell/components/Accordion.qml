import qs.lib
import QtQuick
import QtQuick.Layouts

// animated expand/collapse container. set label for a clickable toggle header
ColumnLayout {
    id: root

    property bool expanded: false
    property bool loading: false
    property string label: ""
    property string value: ""
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: 2

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 14
        radius: Theme.radiusMd
        visible: root.label !== ""
        color: headerHover.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
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
                color: Theme.textLabel
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
            }

            Text {
                Layout.fillWidth: true
                text: root.value
                color: Theme.textPrimary
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                visible: root.value !== ""
            }

            Item {
                Layout.fillWidth: true
                visible: root.value === ""
            }

            Canvas {
                id: spinner
                width: Theme.fontSm
                height: Theme.fontSm
                visible: root.loading
                property real angle: 0

                RotationAnimation on angle {
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 800
                    running: spinner.visible
                }

                onAngleChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    // 24 = material icon viewport; scale canvas to match actual size
                    const s = width / 24;
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.scale(s, s);
                    ctx.translate(12, 12);
                    ctx.rotate(angle * Math.PI / 180);
                    ctx.translate(-12, -12);
                    ctx.beginPath();
                    ctx.arc(12, 12, 8, 0.75 * Math.PI, 0.5 * Math.PI, false);
                    ctx.strokeStyle = Theme.textInactive;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.stroke();
                    ctx.restore();
                }
            }

            Text {
                text: Icons.expandMore
                color: headerHover.containsMouse ? Theme.textActive : Theme.textLabel
                font.pixelSize: Theme.fontIcon
                font.family: Theme.fontIconFamily
                font.variableAxes: Theme.fontIconAxes
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
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

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: _height
        clip: true

        property real _height: root.expanded ? inner.implicitHeight : 0
        Behavior on _height {
            NumberAnimation {
                duration: Theme.animSlow
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
