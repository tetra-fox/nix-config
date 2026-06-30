import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

// auth logic, separated from UI
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
        // start() returns false if the conversation never opens; in that case neither
        // completed nor the message handler ever fires, so recover here or the field
        // stays disabled forever (inputEnabled binds to !authenticating)
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

        // Qt.resolvedUrl returns a file:// URI, but PamContext needs a filesystem path
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
