import qs.theme
import QtQuick

// text input with placeholder + optional password reveal toggle
Rectangle {
    id: root

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
    radius: Theme.radiusMd
    color: "#10ffffff"
    border.width: 1
    border.color: root.error ? Theme.danger : input.activeFocus ? Theme.accent : Theme.panelBorder

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.iconPadH
        text: root.placeholderText
        color: Theme.textInactive
        font.pixelSize: Theme.fontMd
        font.family: Theme.fontFamily
        visible: !input.text
    }

    // sets IBeamCursor over the whole field; accepted=false passes the
    // press through so TextInput still gets focus/selection events
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
        anchors.leftMargin: Theme.iconPadH
        anchors.rightMargin: root.password ? revealBtn.width + Theme.iconPadH : Theme.iconPadH
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.textPrimary
        font.pixelSize: Theme.fontMd
        font.family: Theme.fontFamily
        echoMode: root.password && !root._revealed ? TextInput.Password : TextInput.Normal
        passwordCharacter: "\u2022"
        clip: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.textActive
        enabled: root.inputEnabled

        onAccepted: root.accepted()
    }

    Text {
        id: revealBtn
        anchors.right: parent.right
        anchors.rightMargin: Theme.iconPadH
        anchors.verticalCenter: parent.verticalCenter
        visible: root.password && input.text
        text: root._revealed ? Icons.visibilityOff : Icons.visibility
        color: revealArea.containsMouse ? Theme.textPrimary : Theme.textInactive
        font.pixelSize: Theme.fontIcon
        font.family: Theme.fontIconFamily
        font.variableAxes: Theme.fontIconAxes

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
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
