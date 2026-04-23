import qs.components
import qs.lib
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow { // qmllint disable uncreatable-type
    id: root

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
            passwordInput.clear();
            passwordInput.forceActiveFocus();
        }
    }

    Connections {
        target: root.agent.flow ?? null

        function onIsResponseRequiredChanged() {
            passwordInput.clear();
            if (root.agent.flow?.isResponseRequired)
                passwordInput.forceActiveFocus();
        }

        function onAuthenticationFailed() {
            passwordInput.clear();
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
        height: col.implicitHeight + Theme.pillHPad * 4
        radius: Theme.radiusLg
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder
        transformOrigin: Item.Center

        ColumnLayout {
            id: col
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.pillHPad * 2
                rightMargin: Theme.pillHPad * 2
            }
            spacing: 0

            RowLayout {
                spacing: Theme.iconPadV

                Text {
                    text: Icons.lock
                    color: Theme.accent
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIconLg
                    font.variableAxes: Theme.fontIconAxes
                }

                Text {
                    text: "Authentication Required"
                    color: Theme.textActive
                    font.pixelSize: Theme.fontBase
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.iconPadV
                text: root.agent.flow?.message ?? ""
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Text {
                id: identityLabel
                Layout.fillWidth: true
                Layout.topMargin: Theme.iconPadV
                text: "Authenticating as " + (root.agent.flow?.selectedIdentity?.displayName ?? "")
                color: Theme.textInactive
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                visible: root.agent.flow?.selectedIdentity != null
            }

            InputField {
                id: passwordInput
                Layout.fillWidth: true
                Layout.topMargin: Theme.pillHPad
                implicitHeight: Theme.popupItemHeight
                placeholderText: "Password"
                password: !(root.agent.flow?.responseVisible ?? false)

                onAccepted: {
                    if (text.length > 0 && root.agent.flow) {
                        root.agent.flow.submit(text);
                        clear();
                    }
                }
            }

            Text {
                id: errorText
                Layout.fillWidth: true
                Layout.topMargin: Theme.iconPadV
                text: (root.agent.flow?.supplementaryIsError && root.agent.flow?.supplementaryMessage) ? root.agent.flow.supplementaryMessage : "Incorrect password, try again"
                color: Theme.danger
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                visible: root.agent.flow?.failed ?? false
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.pillHPad
                spacing: Theme.iconPadV

                DialogButton {
                    Layout.fillWidth: true
                    text: "Cancel"
                    bordered: true
                    onClicked: root.agent.flow?.cancelAuthenticationRequest()
                }

                DialogButton {
                    Layout.fillWidth: true
                    text: "Authenticate"
                    accentColor: Theme.accent
                    onClicked: {
                        if (passwordInput.text.length > 0 && root.agent.flow) {
                            root.agent.flow.submit(passwordInput.text);
                            passwordInput.clear();
                        }
                    }
                }
            }
        }
    }
}
