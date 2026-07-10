import qs.components
import qs.lib
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

DialogSurface {
    id: root

    required property var agent

    visible: agent.isActive
    cardWidth: 340

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
        placeholderText: "Password"
        password: !(root.agent.flow?.responseVisible ?? false)

        function submit(): void {
            if (text.length > 0 && root.agent.flow) {
                root.agent.flow.submit(text);
                clear();
            }
        }

        onAccepted: submit()
    }

    Text {
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
            onClicked: passwordInput.submit()
        }
    }
}
