import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Per-screen lock surface — clock, date, and password input.
WlSessionLockSurface {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    required property WlSessionLock lock
    required property Pam pam

    color: "transparent"

    // -- animation state -----------------------------------------------------

    // false → true on lock (entrance), true → false on unlock (exit)
    property bool active: false

    readonly property int lockDuration: 1000
    readonly property int unlockDuration: 200
    property int animDuration: lockDuration

    // lock uses the slow-settle bezier, unlock uses a clean InQuad
    property int animEasingType: Easing.BezierSpline
    readonly property var animBezier: [0.15, 0.7, 0.25, 1.0, 1.0, 1.0]

    // -- background ----------------------------------------------------------

    Item {
        id: backgroundLayer
        anchors.fill: parent

        ScreencopyView {
            id: background
            anchors.fill: parent
            captureSource: root.screen
            live: false
            paintCursor: false

            // zoom out for depth/recess effect
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

    // dim overlay
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

    // -- clock ---------------------------------------------------------------

    property string _time: Qt.formatDateTime(new Date(), "HH:mm")
    property string _date: Qt.formatDateTime(new Date(), "dddd, MMMM d")

    Timer {
        id: syncTimer

        interval: {
            const sub = Date.now() % 1000;
            return sub === 0 ? 1000 : (1000 - sub);
        }
        running: true
        repeat: false

        onTriggered: {
            root._tick();
            tickTimer.running = true;
        }
    }

    Timer {
        id: tickTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: root._tick()
    }

    function _tick() {
        const now = new Date();
        _time = Qt.formatDateTime(now, "HH:mm");
        _date = Qt.formatDateTime(now, "dddd, MMMM d");
    }

    // -- content -------------------------------------------------------------

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
            anchors.centerIn: parent
            spacing: 0

            // time
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root._time
                color: theme.textActive
                font.pixelSize: 96
                font.family: theme.fontFamily
                font.weight: Font.Bold
            }

            // date
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8
                text: root._date
                color: theme.textInactive
                font.pixelSize: 18
                font.family: theme.fontFamily
            }

            Item {
                width: 1
                height: 48
            }

            // user
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    text: icons.lock
                    color: theme.textInactive
                    font.pixelSize: 14
                    font.family: theme.fontIconFamily
                    font.variableAxes: theme.fontIconAxes
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Quickshell.env("USER") ?? ""
                    color: theme.textInactive
                    font.pixelSize: 14
                    font.family: theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: 1
                height: 16
            }

            // password
            InputField {
                id: passwordField
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 48
                radius: 8
                border.width: 2
                placeholderText: "Password"
                password: true
                error: root.pam.failed
                inputEnabled: !root.pam.authenticating

                transform: Translate {
                    id: shakeOffset
                    x: 0
                }

                onAccepted: {
                    root.pam.submit(text);
                    clear();
                }
            }

            // status
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                spacing: 6
                opacity: root.pam.authenticating || root.pam.failed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: theme.animNormal
                    }
                }

                Text {
                    id: spinnerIcon
                    text: icons.progressActivity
                    color: theme.textInactive
                    font.pixelSize: 14
                    font.family: theme.fontIconFamily
                    font.variableAxes: theme.fontIconAxes
                    visible: root.pam.authenticating
                    anchors.verticalCenter: parent.verticalCenter

                    RotationAnimator {
                        target: spinnerIcon
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.pam.authenticating
                    }
                }

                Text {
                    text: root.pam.failed ? "Incorrect password" : "Authenticating..."
                    color: root.pam.failed ? theme.danger : theme.textInactive
                    font.pixelSize: 13
                    font.family: theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                        }
                    }
                }
            }
        }
    }

    // -- shake animation -----------------------------------------------------

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

    // -- unlock animation ----------------------------------------------------

    Connections {
        target: root.lock

        function onUnlock() {
            root.animDuration = root.unlockDuration;
            root.animEasingType = Easing.OutExpo;
            root.active = false;
            unlockFinish.start();
        }
    }

    // wait for exit animation, then actually unlock
    Timer {
        id: unlockFinish
        interval: root.unlockDuration
        onTriggered: root.lock.locked = false
    }

    // -- init ----------------------------------------------------------------

    Component.onCompleted: {
        background.captureFrame();
        root.active = true;
        passwordField.forceActiveFocus();
    }
}
