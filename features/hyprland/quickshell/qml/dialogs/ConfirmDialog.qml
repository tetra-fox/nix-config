import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// centered confirmation dialog with a countdown auto-confirm
// Usage:
//   ConfirmDialog {
//       id: dialog
//       title: "Shut down?"
//       body: "Are you sure you want to shut down?"
//       actionLabel: "Shut down"
//       countdown: 30
//       onConfirmed: { /* run your command */ }
//   }
//   dialog.open()
PanelWindow { // qmllint disable uncreatable-type
    id: root

    Theme {
        id: theme
    }

    property string title: ""
    property string body: ""
    property string icon: ""
    property string actionLabel: "Confirm"
    property int countdown: 30
    property int remaining: countdown

    signal confirmed
    signal cancelled

    function open() {
        remaining = root.countdown;
        visible = true;
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    anchors.top: false
    anchors.bottom: false
    anchors.left: false
    anchors.right: false

    implicitWidth: panel.width
    implicitHeight: panel.height

    visible: false
    color: "transparent"

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            root.visible = false;
            root.cancelled();
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0) {
                root.visible = false;
                root.confirmed();
            }
        }
    }

    onVisibleChanged: {
        if (visible)
            openAnim.restart();
        else
            countdownTimer.stop();
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            PropertyAction {
                target: panel
                property: "scale"
                value: 0.88
            }
            PropertyAction {
                target: panel
                property: "opacity"
                value: 0
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "scale"
                to: 1.0
                duration: 260
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                to: 1.0
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 300
        height: col.implicitHeight + theme.pillHPad * 4
        radius: theme.radiusLg
        color: theme.panelBg
        border.width: 1
        border.color: theme.panelBorder
        transformOrigin: Item.Center

        ColumnLayout {
            id: col
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: theme.pillHPad * 2
                rightMargin: theme.pillHPad * 2
            }
            spacing: 0

            // title
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    visible: root.icon !== ""
                    text: root.icon
                    color: theme.textActive
                    font.pixelSize: theme.fontIconLg
                    font.family: theme.fontIconFamily
                    font.variableAxes: theme.fontIconAxes
                }

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: theme.textActive
                    font.pixelSize: theme.fontBase
                    font.family: theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            Item {
                implicitHeight: theme.iconPadV
            }

            // body
            Text {
                Layout.fillWidth: true
                text: root.body
                color: theme.textSecondary
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Item {
                implicitHeight: theme.pillHPad
            }

            // buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: theme.iconPadV

                // cancel
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: theme.popupItemHeight
                    radius: theme.radiusMd
                    color: cancelArea.pressed ? theme.pressedBg : cancelArea.containsMouse ? theme.hoverBg : theme.withAlpha(theme.hoverBg, 0)
                    border.width: 1
                    border.color: theme.panelBorder
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                            easing.type: Easing.OutQuad
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.textPrimary
                        font.pixelSize: theme.fontMd
                        font.family: theme.fontFamily
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.visible = false;
                            root.cancelled();
                        }
                    }
                }

                // confirm
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: theme.popupItemHeight
                    radius: theme.radiusMd
                    color: confirmArea.pressed ? Qt.darker(theme.danger, 1.3) : confirmArea.containsMouse ? theme.danger : theme.withAlpha(theme.danger, 0.75)
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                            easing.type: Easing.OutQuad
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.actionLabel + "  (" + root.remaining + ")"
                        color: theme.textActive
                        font.pixelSize: theme.fontMd
                        font.family: theme.fontFamily
                    }

                    MouseArea {
                        id: confirmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.visible = false;
                            root.confirmed();
                        }
                    }
                }
            }
        }
    }
}
