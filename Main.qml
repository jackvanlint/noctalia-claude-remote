import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // ── State ─────────────────────────────────────────────────────────────
    property string rcStatus: "stopped"   // "connecting" | "connected" | "stopped"
    property string envUrl: ""
    property string sessionName: ""
    property int activeSessions: 0
    property int maxSessions: 32

    // ── Output parser ─────────────────────────────────────────────────────
    function parseOutput(text) {
        var clean = text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");

        if (clean.indexOf("Connected") >= 0)
            rcStatus = "connected";
        else if (clean.indexOf("Connecting") >= 0)
            rcStatus = "connecting";

        var envMatch = clean.match(/https:\/\/claude\.ai\/code\?environment=(env_[A-Za-z0-9]+)/);
        if (envMatch)
            envUrl = "https://claude.ai/code?environment=" + envMatch[1];

        var capMatches = clean.match(/Capacity:\s*(\d+)\/(\d+)/g);
        if (capMatches && capMatches.length > 0) {
            var nums = capMatches[capMatches.length - 1].match(/(\d+)\/(\d+)/);
            if (nums) {
                activeSessions = parseInt(nums[1]);
                maxSessions    = parseInt(nums[2]);
            }
        }

        var fromCli = text.match(/from=cli([a-z][a-z0-9-]+)/g);
        if (fromCli) {
            for (var i = fromCli.length - 1; i >= 0; i--) {
                var name = fromCli[i].replace("from=cli", "");
                if (name && name !== "Attached") {
                    sessionName = name;
                    break;
                }
            }
        }
    }

    // ── Process controls ──────────────────────────────────────────────────
    function start()   { rcProcess.running = true; }
    function stop()    { rcProcess.running = false; }
    function restart() { rcProcess.running = false; restartTimer.restart(); }

    Timer {
        id: restartTimer
        interval: 800
        onTriggered: rcProcess.running = true
    }

    // ── The process ───────────────────────────────────────────────────────
    Process {
        id: rcProcess
        running: true
        command: ["/home/jack/.local/bin/claude", "remote-control"]

        stdout: StdioCollector {
            onTextChanged: root.parseOutput(text)
        }

        onExited: {
            root.rcStatus  = "stopped";
            root.sessionName = "";
            root.activeSessions = 0;
            Logger.i("ClaudeRemote", "process exited with code " + exitCode);
        }
    }

    Component.onCompleted: Logger.i("ClaudeRemote", "Main loaded — daemon starting")
}
