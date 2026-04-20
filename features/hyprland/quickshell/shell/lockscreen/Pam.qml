import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

// Auth logic for the lockscreen — separated from the UI.
Item {
    id: root
    visible: false

    required property WlSessionLock lock

    property bool authenticating: false
    property bool failed: false

    signal shake

    function submit(password: string): void {
        if (password.trim() === "" || authenticating)
            return;

        _password = password;
        authenticating = true;
        failed = false;
        _pam.start();
    }

    property string _password: ""

    PamContext {
        id: _pam

        configDirectory: Qt.resolvedUrl("pam.d").toString().replace("file://", "")
        config: "quickshell"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root._password);
                root._password = "";
            }
        }

        onCompleted: result => {
            root._password = "";

            if (result === PamResult.Success) {
                root.authenticating = false;
                root.lock.unlock();
            } else {
                root.failed = true;
                root.authenticating = false;
                root.shake();
            }
        }
    }
}
