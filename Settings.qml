import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.sessionName = nameInput.text.trim() || "Remote Session";
        pluginApi.saveSettings();
        Logger.i("ClaudeRemote", "Settings saved — session name: " + pluginApi.pluginSettings.sessionName);
    }

    spacing: Style.marginM

    Component.onCompleted: {
        nameInput.text = pluginApi?.pluginSettings?.sessionName || "Remote Session";
    }

    NHeader {
        label: "Session Name"
        description: "The name shown in claude.ai/code and the mobile app. Changing this takes effect after the next daemon restart."
    }

    NTextInput {
        id: nameInput
        Layout.fillWidth: true
        placeholderText: "Remote Session"
        onEditingFinished: root.saveSettings()
    }
}
