import qs.components
import qs.lib
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    color: "transparent"

    property bool active: false

    readonly property int lockDuration: 1000
    readonly property int unlockDuration: 200
    property int animDuration: lockDuration

    property int animEasingType: Easing.BezierSpline  // swapped on unlock
    readonly property var animBezier: [0.15, 0.7, 0.25, 1.0, 1.0, 1.0]

    Item {
        id: backgroundLayer
        anchors.fill: parent

        ScreencopyView {
            id: background
            anchors.fill: parent
            captureSource: root.screen
            live: false
            paintCursor: false

            property real zoomScale: root.active ? 0.92 : 1.0

            transform: Scale {
                origin.x: background.width / 2
                origin.y: background.height / 2
                xScale: background.zoomScale
                yScale: background.zoomScale
            }

            Behavior on zoomScale {
                NumberAnimation {
                    duration: root.animDuration
                    easing.type: root.animEasingType
                    easing.bezierCurve: root.animBezier
                }
            }
        }

        layer.enabled: true
        // qmllint disable unqualified
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.active ? 1.0 : 0
            blurMax: 64

            Behavior on blur {
                NumberAnimation {
                    duration: root.animDuration
                    easing.type: root.animEasingType
                    easing.bezierCurve: root.animBezier
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.active ? 0.4 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.animDuration
                easing.type: root.animEasingType
                easing.bezierCurve: root.animBezier
            }
        }
    }

    property var _now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._now = new Date()
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: root.animDuration
                easing.type: root.animEasingType
                easing.bezierCurve: root.animBezier
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.animDuration
                easing.type: root.animEasingType
                easing.bezierCurve: root.animBezier
            }
        }

        Column {
            id: mainColumn
            anchors.centerIn: parent

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root._now, "HH:mm")
                color: Theme.textActive
                font.pixelSize: 96
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8
                text: Qt.formatDateTime(root._now, "dddd, MMMM d")
                color: Theme.textInactive
                font.pixelSize: 18
                font.family: Theme.fontFamily
            }

            Item {
                width: 1
                height: 48
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    text: Icons.lock
                    color: Theme.textInactive
                    font.pixelSize: 14
                    font.family: Theme.fontIconFamily
                    font.variableAxes: Theme.fontIconAxes
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Quickshell.env("USER") ?? ""
                    color: Theme.textInactive
                    font.pixelSize: 14
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: 1
                height: 16
            }

            InputField {
                id: passwordField
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.popupWidth
                height: 48
                radius: 8
                border.width: 2
                placeholderText: "Password"
                password: true
                error: root.pam.failed
                inputEnabled: !root.pam.authenticating

                transform: Translate {
                    id: shakeOffset
                }

                onAccepted: {
                    root.pam.submit(text);
                    clear();
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                spacing: 6
                opacity: root.pam.authenticating || root.pam.failed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animNormal
                    }
                }

                Spinner {
                    font.pixelSize: 14
                    // opacity, not visible, so the status text doesn't shift
                    opacity: root.pam.authenticating ? 1 : 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.pam.failed ? "Incorrect password" : "Authenticating..."
                    color: root.pam.failed ? Theme.danger : Theme.textInactive
                    font.pixelSize: 13
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }
                }
            }
        }

        NowPlaying {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mainColumn.bottom
            anchors.topMargin: 72
        }

        PowerOptions {
            anchors.fill: parent
            // cancel, or an action the session survives (suspend)
            onConfirmingChanged: if (!confirming)
                passwordField.forceActiveFocus()
        }
    }

    Connections {
        target: root.pam
        function onShake() {
            shakeAnim.start();
        }
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -10
            duration: 40
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 10
            duration: 80
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -5
            duration: 60
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 0
            duration: 40
            easing.type: Easing.InQuad
        }
    }

    Connections {
        target: root.lock

        function onUnlock() {
            // before toggling active, so the exit animations use it
            root.animDuration = root.unlockDuration;
            root.animEasingType = Easing.OutExpo;
            root.active = false;
            unlockFinish.start();
        }
    }

    // let the exit animation finish first
    Timer {
        id: unlockFinish
        interval: root.unlockDuration
        onTriggered: root.lock.locked = false
    }

    Component.onCompleted: {
        root.active = true;
        passwordField.forceActiveFocus();
    }
}
