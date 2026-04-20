import qs.components
import QtQuick

// Styled text input with placeholder, I-beam cursor, and optional password mode.
// When password is true, a reveal/hide toggle button appears on the right.
Rectangle {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    property alias text: input.text
    property string placeholderText: ""
    property bool password: false
    property bool error: false
    property bool inputEnabled: true

    signal accepted

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function clear() {
        input.text = "";
    }

    property bool _revealed: false

    implicitHeight: 32
    radius: theme.radiusMd
    color: "#10ffffff"
    border.width: 1
    border.color: root.error ? theme.danger : input.activeFocus ? theme.accent : theme.panelBorder

    Behavior on border.color {
        ColorAnimation {
            duration: theme.animFast
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: theme.iconPadH
        text: root.placeholderText
        color: theme.textInactive
        font.pixelSize: theme.fontMd
        font.family: theme.fontFamily
        visible: !input.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            input.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: theme.iconPadH
        anchors.rightMargin: root.password ? revealBtn.width + theme.iconPadH : theme.iconPadH
        verticalAlignment: TextInput.AlignVCenter
        color: theme.textPrimary
        font.pixelSize: theme.fontMd
        font.family: theme.fontFamily
        echoMode: root.password && !root._revealed ? TextInput.Password : TextInput.Normal
        passwordCharacter: "\u2022"
        clip: true
        selectionColor: theme.accent
        selectedTextColor: theme.textActive
        enabled: root.inputEnabled

        onAccepted: root.accepted()
    }

    // reveal/hide toggle
    Text {
        id: revealBtn
        anchors.right: parent.right
        anchors.rightMargin: theme.iconPadH
        anchors.verticalCenter: parent.verticalCenter
        visible: root.password && input.text
        text: root._revealed ? icons.visibilityOff : icons.visibility
        color: revealArea.containsMouse ? theme.textPrimary : theme.textInactive
        font.pixelSize: theme.fontIcon
        font.family: theme.fontIconFamily
        font.variableAxes: theme.fontIconAxes

        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
            }
        }

        MouseArea {
            id: revealArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._revealed = !root._revealed
        }
    }
}
