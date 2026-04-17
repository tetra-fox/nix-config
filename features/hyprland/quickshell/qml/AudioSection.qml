import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    Theme { id: theme }

    property string label
    property string icon
    property bool   muted
    property real   volume
    property list<PwNode> devices
    property PwNode activeDevice

    signal toggleMute()
    signal setVolume(real v)
    signal selectDevice(PwNode d)

    spacing: 14

    // ── slider row ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        // Mute toggle
        BarButton {
            icon: root.icon
            iconColor: root.muted ? theme.danger : theme.textPrimary
            iconSize: theme.fontIconLg
            onClicked: _ => root.toggleMute()
        }

        Slider {
            Layout.fillWidth: true
            from: 0
            to: 1.5
            value: root.volume

            property bool resetOnRelease: false

            onMoved: {
                if (!resetOnRelease)
                    root.setVolume(value)
            }

            onPressedChanged: {
                if (!pressed && resetOnRelease) {
                    resetOnRelease = false
                    root.setVolume(1.0)
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: parent.resetOnRelease = true
            }
        }

        Text {
            text: Math.round(root.volume * 100) + "%"
            color: theme.textSecondary
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            Layout.minimumWidth: 40
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── collapsible device selector ──────────────────────────────────────────
    ColumnLayout {
        id: deviceSelector
        Layout.fillWidth: true
        spacing: 2

        property bool expanded: false

        // header
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + 14
            radius: theme.radiusMd
            color: headerHover.containsMouse ? theme.hoverBg : "transparent"

            Behavior on color { ColorAnimation { duration: theme.animFast } }

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
                    text: root.activeDevice
                        ? (root.activeDevice.description || root.activeDevice.nickname || root.activeDevice.name)
                        : "—"
                    color: theme.textPrimary
                    font.pixelSize: theme.fontMd
                    font.family: theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    text: deviceSelector.expanded ? "▴" : "▾"
                    color: headerHover.containsMouse ? theme.textActive : theme.textLabel
                    font.pixelSize: theme.fontXs

                    Behavior on color { ColorAnimation { duration: theme.animFast } }
                }
            }

            MouseArea {
                id: headerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: deviceSelector.expanded = !deviceSelector.expanded
            }
        }

        // clip container — items stay rendered, implicitHeight animates so
        // the layout reflows properly instead of children overlapping
        Item {
            Layout.fillWidth: true
            clip: true
            implicitHeight: deviceSelector.expanded ? deviceList.implicitHeight : 0

            Behavior on implicitHeight {
                NumberAnimation { duration: theme.animSlow; easing.type: Easing.InOutQuad }
            }

            Column {
                id: deviceList
                width: parent.width

                Repeater {
                    model: root.devices

                    delegate: Item {
                        required property PwNode modelData
                        required property int index

                        width: parent.width
                        implicitHeight: deviceRow.implicitHeight + 16

                        Rectangle {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                leftMargin: 8
                                rightMargin: 8
                            }
                            height: 1
                            color: theme.separatorBg
                            visible: index > 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusMd
                            color: deviceItemHover.containsMouse ? theme.hoverBg : "transparent"

                            Behavior on color { ColorAnimation { duration: theme.animFast } }
                        }

                        RowLayout {
                            id: deviceRow
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 8
                                topMargin: 6
                                bottomMargin: 6
                            }
                            spacing: 10

                            Text {
                                text: "󰓃"
                                font.pixelSize: theme.fontMd
                                font.family: theme.fontFamily
                                color: modelData === root.activeDevice ? theme.accent : "transparent"

                                Behavior on color { ColorAnimation { duration: theme.animNormal } }
                            }

                            MarqueeText {
                                Layout.fillWidth: true
                                text: modelData.description || modelData.nickname || modelData.name
                                color: modelData === root.activeDevice ? theme.textActive : theme.textInactive
                                hovered: deviceItemHover.containsMouse
                                font.pixelSize: theme.fontMd
                                font.family: theme.fontFamily

                                Behavior on color { ColorAnimation { duration: theme.animNormal } }
                            }
                        }

                        MouseArea {
                            id: deviceItemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectDevice(modelData)
                                deviceSelector.expanded = false
                            }
                        }
                    }
                }
            }
        }
    }
}
