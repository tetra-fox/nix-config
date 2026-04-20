import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow { // qmllint disable uncreatable-type
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    required property var agent

    visible: agent.isActive

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

    color: "transparent"

    HyprlandFocusGrab {
        // qmllint disable unresolved-type
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.agent.isActive)
                root.agent.flow?.cancelAuthenticationRequest();
        }
    }

    onVisibleChanged: {
        if (visible) {
            openAnim.restart();
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    Connections {
        target: root.agent.flow ?? null

        function onIsResponseRequiredChanged() {
            passwordInput.text = "";
            if (root.agent.flow?.isResponseRequired)
                passwordInput.forceActiveFocus();
        }

        function onAuthenticationFailed() {
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
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
        width: 340
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

            // header: lock icon + title
            RowLayout {
                spacing: theme.iconPadV

                Text {
                    text: icons.lock
                    color: theme.accent
                    font.family: theme.fontIconFamily
                    font.pixelSize: theme.fontIconLg
                    font.variableAxes: theme.fontIconAxes
                }

                Text {
                    text: "Authentication Required"
                    color: theme.textActive
                    font.pixelSize: theme.fontBase
                    font.family: theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            Item {
                implicitHeight: theme.iconPadV
            }

            // message
            Text {
                Layout.fillWidth: true
                text: root.agent.flow?.message ?? ""
                color: theme.textSecondary
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Item {
                implicitHeight: theme.iconPadV
                visible: identityLabel.visible
            }

            // identity
            Text {
                id: identityLabel
                Layout.fillWidth: true
                text: "Authenticating as " + (root.agent.flow?.selectedIdentity?.displayName ?? "")
                color: theme.textInactive
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                visible: root.agent.flow?.selectedIdentity != null
            }

            Item {
                implicitHeight: theme.pillHPad
            }

            // password input
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: theme.popupItemHeight
                radius: theme.radiusMd
                color: "#10ffffff"
                border.width: 1
                border.color: passwordInput.activeFocus ? theme.accent : theme.panelBorder

                Behavior on border.color {
                    ColorAnimation {
                        duration: theme.animFast
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: theme.iconPadH
                    text: "Password"
                    color: theme.textInactive
                    font.pixelSize: theme.fontMd
                    font.family: theme.fontFamily
                    visible: !passwordInput.text
                }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: theme.iconPadH
                    anchors.rightMargin: theme.iconPadH
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.textPrimary
                    font.pixelSize: theme.fontMd
                    font.family: theme.fontFamily
                    echoMode: root.agent.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "\u2022"
                    clip: true
                    selectionColor: theme.accent
                    selectedTextColor: theme.textActive

                    onAccepted: {
                        if (text.length > 0 && root.agent.flow) {
                            root.agent.flow.submit(text);
                            text = "";
                        }
                    }
                }
            }

            // error spacer
            Item {
                implicitHeight: theme.iconPadV
                visible: errorText.visible
            }

            // error text
            Text {
                id: errorText
                Layout.fillWidth: true
                text: (root.agent.flow?.supplementaryIsError && root.agent.flow?.supplementaryMessage) ? root.agent.flow.supplementaryMessage : "Incorrect password, try again"
                color: theme.danger
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                visible: root.agent.flow?.failed ?? false
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
                        onClicked: root.agent.flow?.cancelAuthenticationRequest()
                    }
                }

                // authenticate
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: theme.popupItemHeight
                    radius: theme.radiusMd
                    color: authArea.pressed ? Qt.darker(theme.accent, 1.3) : authArea.containsMouse ? theme.accent : theme.withAlpha(theme.accent, 0.75)
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.animFast
                            easing.type: Easing.OutQuad
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Authenticate"
                        color: theme.textActive
                        font.pixelSize: theme.fontMd
                        font.family: theme.fontFamily
                    }

                    MouseArea {
                        id: authArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (passwordInput.text.length > 0 && root.agent.flow) {
                                root.agent.flow.submit(passwordInput.text);
                                passwordInput.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
