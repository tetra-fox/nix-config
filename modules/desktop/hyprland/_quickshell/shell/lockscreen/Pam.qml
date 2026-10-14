import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

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
        // if the conversation never opens no handler fires, and the field stays disabled
        if (!_pam.start()) {
            authenticating = false;
            failed = true;
            _password = "";
            shake();
        }
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
