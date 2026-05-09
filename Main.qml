import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // ── Primary daemon state ──────────────────────────────────────────────
    property string rcStatus: "stopped"   // "connecting" | "connected" | "stopped"
    property int activeSessions: 0
    property int maxSessions: 32

    // ── Named extra sessions: [{name, pid}] ───────────────────────────────
    property var namedSessions: []


    readonly property string configuredName:
        pluginApi?.pluginSettings?.sessionName || "Remote Session"
    readonly property string claudeBin:
        pluginApi?.pluginSettings?.claudeBin || "claude"
    readonly property string scriptPath:
        Qt.resolvedUrl("start-session.sh").toString().replace("file://", "")

    // ── Primary status via running-state + timer ──────────────────────────
    Timer {
        id: connectionTimer
        interval: 6000
        onTriggered: {
            if (rcProcess.running) {
                rcStatus = "connected";
                sessionPoller.running = true;
                Logger.i("ClaudeRemote", "Primary daemon connected");
            }
        }
    }

    Connections {
        target: rcProcess
        function onRunningChanged() {
            if (rcProcess.running) {
                rcStatus = "connecting";
                connectionTimer.restart();
            }
        }
    }

    // ── Session count poller (child-process count of primary daemon) ───────
    Timer {
        id: sessionPoller
        interval: 5000
        repeat: true
        running: false
        onTriggered: {
            if (rcProcess.running) countProc.running = true;
            else running = false;
        }
    }

    Process {
        id: countProc
        running: false
        command: ["sh", "-c",
            "pgrep -P " + rcProcess.pid + " | wc -l 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(text.trim());
                if (!isNaN(n)) root.activeSessions = Math.max(0, n - 1);
            }
        }
    }

    // ── Stdout parser (best-effort) ───────────────────────────────────────
    function parseOutput(text) {
        var clean = text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
        if (rcStatus === "connecting") {
            rcStatus = "connected";
            connectionTimer.stop();
        }
    }

    // ── Primary daemon process ────────────────────────────────────────────
    Process {
        id: rcProcess
        running: false
        command: [root.claudeBin, "remote-control",
                  "--name", root.configuredName,
                  "--spawn", "session"]

        stdout: StdioCollector { onTextChanged: root.parseOutput(text) }

        onExited: (exitCode, exitStatus) => {
            root.rcStatus       = "stopped";
            root.activeSessions = 0;
            connectionTimer.stop();
            sessionPoller.running = false;
            Logger.i("ClaudeRemote", "Primary daemon exited — code " + exitCode);
            if (root._pendingRestart) {
                root._pendingRestart = false;
                rcProcess.running = true;
            }
        }
    }

    // ── Named session management ──────────────────────────────────────────
    function addNamedSession(topic) {
        var name = topic.startsWith("Remote Session:")
            ? topic.trim()
            : "Remote Session: " + topic.trim();
        spawnProc.pendingName = name;
        spawnProc.running = true;
    }

    Process {
        id: spawnProc
        property string pendingName: ""
        running: false
        command: [root.scriptPath, pendingName, root.claudeBin]
        stdout: StdioCollector {
            onStreamFinished: {
                var pid = parseInt(text.trim());
                if (pid > 0) {
                    root.namedSessions = root.namedSessions.concat([{
                        name: spawnProc.pendingName,
                        pid:  pid
                    }]);
                    Logger.i("ClaudeRemote",
                        "Started '" + spawnProc.pendingName + "' PID " + pid);
                }
            }
        }
    }

    function removeNamedSession(pid) {
        killProc.targetPid = pid;
        killProc.running   = true;
        root.namedSessions = root.namedSessions.filter(s => s.pid !== pid);
    }

    Process {
        id: killProc
        property int targetPid: 0
        running: false
        command: ["kill", targetPid.toString()]
    }

    // Prune dead extra sessions every 10 s
    Timer {
        interval: 10000
        repeat: true
        running: root.namedSessions.length > 0
        onTriggered: pruneProc.running = true
    }

    Process {
        id: pruneProc
        running: false
        command: ["sh", "-c", buildPruneCmd()]

        function buildPruneCmd() {
            if (root.namedSessions.length === 0) return "true";
            return root.namedSessions
                .map(s => "kill -0 " + s.pid + " 2>/dev/null && echo " + s.pid)
                .join("; ");
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var alive = new Set(
                    text.trim().split("\n")
                        .map(l => parseInt(l.trim()))
                        .filter(n => n > 0)
                );
                if (alive.size !== root.namedSessions.length) {
                    root.namedSessions = root.namedSessions.filter(s => alive.has(s.pid));
                }
            }
        }
    }

    // ── Controls ──────────────────────────────────────────────────────────
    property bool _pendingRestart: false

    function start()   { if (!rcProcess.running) rcProcess.running = true; }
    function stop()    { connectionTimer.stop(); sessionPoller.running = false; rcProcess.running = false; }
    function restart() { _pendingRestart = true; stop(); }

    Component.onCompleted: {
        Logger.i("ClaudeRemote", "Main loaded — starting '" + root.configuredName + "'");
        rcProcess.running = true;
    }
}
