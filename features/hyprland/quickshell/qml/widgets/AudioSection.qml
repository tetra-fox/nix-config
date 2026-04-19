pragma ComponentBehavior: Bound

import qs.components

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// volume slider + collapsible device selector for one audio direction (input or output)
ColumnLayout {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property string label
    property string icon
    property bool muted
    property real volume
    property list<PwNode> devices
    property PwNode activeDevice

    signal toggleMute
    signal setVolume(real v)
    signal selectDevice(PwNode d)

    spacing: 14

    // slider row
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        IconButton {
            icon: root.icon
            iconColor: root.muted ? theme.danger : theme.textPrimary
            iconSize: theme.fontIconLg
            onClicked: _ => root.toggleMute()
        }

        Slider {
            id: sl
            Layout.fillWidth: true
            from: 0
            to: 1.5
            value: root.volume

            property bool resetOnRelease: false

            onMoved: {
                if (!resetOnRelease)
                    root.setVolume(value);
            }
            onPressedChanged: {
                if (!pressed && resetOnRelease) {
                    resetOnRelease = false;
                    resetTimer.start();
                }
            }

            // defer one tick so the Behavior on x is enabled before the value changes
            Timer {
                id: resetTimer
                interval: 1
                onTriggered: root.setVolume(1.0)
            }

            // double-tap resets to 100%
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: parent.resetOnRelease = true
            }

            background: Item {
                x: sl.leftPadding
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                implicitWidth: sl.availableWidth
                implicitHeight: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: theme.inactiveBg

                    // filled portion — animates when changed externally, instant while dragging
                    Rectangle {
                        width: sl.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                        Behavior on width {
                            enabled: !sl.pressed
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutExpo
                            }
                        }
                    }

                    // 100% tick — subtle reminder of unity gain
                    Rectangle {
                        x: parent.width * (1.0 / 1.5) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 10
                        radius: 1
                        color: theme.withAlpha(theme.white, 0.18)
                    }
                }
            }

            handle: Item {
                x: sl.leftPadding + sl.visualPosition * sl.availableWidth - width / 2
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 16
                height: 16
                Behavior on x {
                    enabled: !sl.pressed
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutExpo
                    }
                }

                // glow ring — blooms when grabbed
                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: theme.withAlpha(theme.accent, sl.pressed ? 0.22 : sl.hovered ? 0.15 : 0)
                    scale: sl.pressed ? 1.7 : sl.hovered ? 1.2 : 0.7
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: theme.animNormal
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                }

                // handle — pill when dragging, circle at rest
                Rectangle {
                    anchors.centerIn: parent
                    width: sl.pressed ? 8 : sl.hovered ? 16 : 14
                    height: sl.pressed ? 20 : sl.hovered ? 16 : 14
                    radius: height / 2
                    color: sl.pressed ? theme.accent : theme.textPrimary
                    Behavior on width {
                        NumberAnimation {
                            duration: theme.animNormal
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.8
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: theme.animNormal
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.8
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animNormal
                            easing.type: Easing.OutExpo
                        }
                    }
                }
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

    // collapsible device selector
    Accordion {
        id: deviceSelector
        Layout.fillWidth: true
        label: root.label
        value: root.activeDevice ? (root.activeDevice.description || root.activeDevice.nickname || root.activeDevice.name) : "-"

            ScrollableList {
                width: parent.width
                maxItems: 5

                Repeater {
                    model: root.devices

                    delegate: SelectableItem {
                        required property PwNode modelData
                        required property int index

                        width: parent.width
                        text: modelData.description || modelData.nickname || modelData.name
                        active: modelData === root.activeDevice
                        showSeparator: index > 0
                        onSelected: {
                            root.selectDevice(modelData);
                            deviceSelector.expanded = false;
                        }
                    }
                }
            }
    }
}
