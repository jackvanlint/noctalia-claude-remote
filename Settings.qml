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
        pluginApi.pluginSettings.claudeBin   = binInput.text.trim()  || "claude";
        pluginApi.saveSettings();
        Logger.i("ClaudeRemote", "Settings saved — claudeBin: " + pluginApi.pluginSettings.claudeBin);
    }

    spacing: Style.marginM

    Component.onCompleted: {
        nameInput.text = pluginApi?.pluginSettings?.sessionName || "Remote Session";
        binInput.text  = pluginApi?.pluginSettings?.claudeBin   || "claude";
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

    NHeader {
        label: "Claude Binary"
        description: "Path to the claude CLI. Leave as 'claude' if it's on your PATH, or enter the full path (e.g. /home/you/.local/bin/claude)."
    }

    NTextInput {
        id: binInput
        Layout.fillWidth: true
        placeholderText: "claude"
        onEditingFinished: root.saveSettings()
    }
}
