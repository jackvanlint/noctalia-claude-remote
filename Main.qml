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

    // ── Usage stats ───────────────────────────────────────────────────────
    property real pct5h:       -1.0  // 0–1 from API, -1 = unknown
    property real pct7d:       -1.0
    property int  reset5hMins: 0
    property int  reset7dMins: 0
    property int  tokensToday: 0
    property int  prompts5h:   0
    property int  prompts7d:   0
    property bool apiOk:       false
    property var  usageDays:   []    // [{date, tokens, prompts}] oldest→newest

    readonly property string usagePath:
        Qt.resolvedUrl("usage.py").toString().replace("file://", "")

    Timer {
        id: usagePoller
        interval: 300000   // every 5 min — matches the API's cache window
        repeat: true
        running: true
        onTriggered: usageProc.running = true
    }

    Process {
        id: usageProc
        running: false
        command: ["python3", root.usagePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    root.pct5h       = d.pct_5h       ?? -1
                    root.pct7d       = d.pct_7d       ?? -1
                    root.reset5hMins = d.reset_5h_mins ?? 0
                    root.reset7dMins = d.reset_7d_mins ?? 0
                    root.tokensToday = d.tokens_today  ?? 0
                    root.prompts5h   = d.prompts_5h    ?? 0
                    root.prompts7d   = d.prompts_7d    ?? 0
                    root.apiOk       = d.api_ok        ?? false
                    root.usageDays   = d.days          ?? []
                } catch(e) {}
            }
        }
    }

    // ── Skills: [{name, description}] ────────────────────────────────────
    property var skills: []
    property var favourites: []

    readonly property var sortedSkills: {
        var favSet = new Set(favourites)
        var favs = skills.filter(function(s) { return favSet.has(s.name) })
        var rest = skills.filter(function(s) { return !favSet.has(s.name) })
        return favs.concat(rest)
    }

    onPluginApiChanged: {
        if (!pluginApi) return
        var raw = pluginApi.pluginSettings?.favouriteSkills
        if (!raw) return
        if (Array.isArray(raw)) root.favourites = raw.slice()
        else try { root.favourites = JSON.parse(raw) } catch(e) {}
    }

    function toggleFavourite(name) {
        var favs = favourites.slice()
        var idx = favs.indexOf(name)
        if (idx >= 0) favs.splice(idx, 1)
        else favs.push(name)
        root.favourites = favs
        if (pluginApi) {
            pluginApi.pluginSettings.favouriteSkills = favs
            pluginApi.saveSettings()
        }
    }


    readonly property string configuredName:
        pluginApi?.pluginSettings?.sessionName || "Remote Session"
    readonly property string claudeBin:
        pluginApi?.pluginSettings?.claudeBin || "claude"
    readonly property string terminalBin:
        pluginApi?.pluginSettings?.terminalBin || "kitty"
    readonly property string scriptPath:
        Qt.resolvedUrl("start-session.sh").toString().replace("file://", "")

    // ── Primary status via running-state + timer ──────────────────────────
    Timer {
        id: connectionTimer
        interval: 6000
        onTriggered: {
            if (rcProcess.running) {
                root.rcStatus = "connected";
                sessionPoller.running = true;
                Logger.i("ClaudeRemote", "Primary daemon connected");
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

        onRunningChanged: {
            if (running) {
                root.rcStatus = "connecting";
                connectionTimer.restart();
            }
        }

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

    // ── Skill discovery ──────────────────────────────────────────────────
    Process {
        id: skillLister
        running: false
        command: ["sh", "-c",
            "for f in ~/.claude/commands/*.md; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  name=$(basename \"$f\" .md); " +
            "  desc=$(grep -m1 '^description:' \"$f\" | sed 's/^description: *//'); " +
            "  [ -z \"$desc\" ] && desc=$(head -1 \"$f\" | sed 's/^#* *//' | cut -c1-60); " +
            "  detail=$(awk 'BEGIN{f=0;c=0} /^---$/{f++;next} f==1{next} /^#/{next} NF{printf \"%s \",\$0; c++; if(c>=4) exit}' \"$f\" | sed 's/  */ /g' | cut -c1-300); " +
            "  [ -z \"$detail\" ] && detail=\"$desc\"; " +
            "  printf '%s\\x01%s\\x01%s\\n' \"$name\" \"$desc\" \"$detail\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(function(l) { return l.length > 0; })
                root.skills = lines.map(function(l) {
                    var parts = l.split("\x01")
                    return { name: parts[0] || "", description: parts[1] || "", detail: parts[2] || parts[1] || "" }
                })
            }
        }
    }

    function runSkill(name) {
        skillRunner.skillName = name
        skillRunner.running = true
    }

    Process {
        id: skillRunner
        property string skillName: ""
        running: false
        // alacritty uses "-e"; all other common terminals accept "--"
        command: root.terminalBin === "alacritty"
            ? [root.terminalBin, "-e", root.claudeBin, "/" + skillName]
            : [root.terminalBin, "--", root.claudeBin, "/" + skillName]
    }

    // ── Controls ──────────────────────────────────────────────────────────
    property bool _pendingRestart: false

    function start()   { if (!rcProcess.running) rcProcess.running = true; }
    function stop()    { connectionTimer.stop(); sessionPoller.running = false; rcProcess.running = false; }
    function restart() { _pendingRestart = true; stop(); }

    Component.onCompleted: {
        Logger.i("ClaudeRemote", "Main loaded — auto-start disabled, use button to start session");
        skillLister.running = true;
        usageProc.running  = true;
    }
}
