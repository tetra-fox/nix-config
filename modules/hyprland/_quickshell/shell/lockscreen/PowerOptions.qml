pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Io
import QtQuick

// power buttons + inline confirm overlay for the lock screen
Item {
    id: root

    readonly property bool confirming: _confirming
    signal cancelled

    property bool _confirming: false
    property string _confirmLabel: ""
    property string _confirmIcon: ""
    property list<string> _confirmCmd: []
    property int _confirmRemaining: 30

    function _requestConfirm(label: string, icon: string, cmd: list<string>): void {
        _confirmLabel = label;
        _confirmIcon = icon;
        _confirmCmd = cmd;
        _confirmRemaining = 30;
        _confirming = true;
        confirmOverlay.forceActiveFocus();
    }

    function _cancelConfirm(): void {
        _confirming = false;
        root.cancelled();
    }

    function _executeConfirm(): void {
        powerProc.command = _confirmCmd;
        powerProc.running = true;
    }

    Process {
        id: powerProc
    }

    Timer {
        running: root._confirming
        interval: 1000
        repeat: true
        onTriggered: {
            root._confirmRemaining -= 1;
            if (root._confirmRemaining <= 0)
                root._executeConfirm();
        }
    }

    // -- buttons --

    component PowerButton: Column {
        property string icon
        property string label
        property list<string> cmd
        spacing: 8

        Rectangle {
            width: 48
            height: 48
            radius: 24
            anchors.horizontalCenter: parent.horizontalCenter
            color: powerArea.pressed ? Theme.pressedBg : powerArea.containsMouse ? Theme.hoverBg : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Text {
                anchors.centerIn: parent
                text: icon
                color: Theme.textInactive
                font.pixelSize: 20
                font.family: Theme.fontIconFamily
                font.variableAxes: Theme.fontIconAxes
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._requestConfirm(label, icon, cmd)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: label
            color: Theme.textInactive
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        spacing: 24

        PowerButton {
            icon: Icons.sleep
            label: "Suspend"
            cmd: ["systemctl", "suspend"]
        }

        PowerButton {
            icon: Icons.restart
            label: "Reboot"
            cmd: ["systemctl", "reboot"]
        }

        PowerButton {
            icon: Icons.power
            label: "Shut down"
            cmd: ["systemctl", "poweroff"]
        }
    }

    // -- confirm overlay --

    Item {
        id: confirmOverlay
        anchors.fill: parent
        opacity: root._confirming ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuad
            }
        }

        Keys.onEscapePressed: root._cancelConfirm()
        Keys.onReturnPressed: root._executeConfirm()

        // dim backdrop
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.5
        }

        Rectangle {
            anchors.centerIn: parent
            width: 300
            height: confirmCol.implicitHeight + Theme.pillHPad * 4
            radius: Theme.radiusLg
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder
            scale: root._confirming ? 1 : 0.88

            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutExpo
                }
            }

            Column {
                id: confirmCol
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.pillHPad * 2
                    rightMargin: Theme.pillHPad * 2
                }
                spacing: 0

                Row {
                    spacing: 8

                    Text {
                        text: root._confirmIcon
                        color: Theme.textActive
                        font.pixelSize: Theme.fontIconLg
                        font.family: Theme.fontIconFamily
                        font.variableAxes: Theme.fontIconAxes
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root._confirmLabel + "?"
                        color: Theme.textActive
                        font.pixelSize: Theme.fontBase
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    width: 1
                    height: Theme.iconPadV
                }

                Text {
                    width: parent.width
                    text: "Are you sure you want to " + root._confirmLabel.toLowerCase() + "?"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: 1
                    height: Theme.pillHPad
                }

                Row {
                    width: parent.width
                    spacing: Theme.iconPadV

                    DialogButton {
                        width: (parent.width - parent.spacing) / 2
                        text: "Cancel"
                        bordered: true
                        onClicked: root._cancelConfirm()
                    }

                    DialogButton {
                        width: (parent.width - parent.spacing) / 2
                        text: root._confirmLabel + "  (" + root._confirmRemaining + ")"
                        accentColor: Theme.danger
                        onClicked: root._executeConfirm()
                    }
                }
            }
        }
    }
}
