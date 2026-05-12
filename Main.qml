import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // ── Primary daemon state ──────────────────────────────────────────────
    property string rcStatus: "stopped"   // "connecting" | "connected" | "stopped"
    property bool startupFailed: false    // true when daemon exits within the 6-second connect window
    property string startupErrorType: ""  // "binary" | "workspace"
    property bool claudeFound: true       // false if preflight cannot locate the claude binary
    property bool preflightDone: false    // true once the preflight check has completed
    property int activeSessions: 0
    property int maxSessions: 32

    // ── Named extra sessions: [{name, pid}] ───────────────────────────────
    property var namedSessions: []

    // ── Usage stats ───────────────────────────────────────────────────────
    property real   pct5h:       -1.0  // 0–1 from API, -1 = unknown
    property real   pct7d:       -1.0
    property int    reset5hMins: 0
    property int    reset7dMins: 0
    property int    tokensToday: 0
    property int    prompts5h:   0
    property int    prompts7d:   0
    property bool   apiOk:       false
    property var    usageDays:   []    // [{date, tokens, prompts}] oldest→newest
    property string planType:    ""    // e.g. "claude_max_5x", "claude_pro"
    property string planTier:    ""    // e.g. "standard", "priority"

    readonly property string usagePath:
        Qt.resolvedUrl("usage.py").toString().replace("file://", "")

    Timer {
        id: usagePoller
        interval: 300000   // every 5 min — matches the API's cache window
        repeat: true
        running: true
        // Guard: don't re-trigger if a previous poll is still running
        onTriggered: { if (!usageProc.running) usageProc.running = true }
    }

    Process {
        id: usageProc
        running: false
        command: ["python3", root.usagePath]
        stdout: StdioCollector {
            onStreamFinished: {
                // Take the last non-empty line — handles any StdioCollector
                // accumulation across repeated runs without losing data.
                var lines = text.trim().split("\n")
                var last = ""
                for (var i = lines.length - 1; i >= 0; i--) {
                    var l = lines[i].trim()
                    if (l.startsWith("{")) { last = l; break }
                }
                if (!last) return
                try {
                    var d = JSON.parse(last)
                    // Only overwrite rate-limit percentages when the API
                    // returned fresh data — avoids blanking bars on a
                    // transient API failure.
                    var p5  = d.pct_5h ?? -1
                    var p7  = d.pct_7d ?? -1
                    if (p5 >= 0 || root.pct5h < 0) root.pct5h = p5
                    if (p7 >= 0 || root.pct7d < 0) root.pct7d = p7
                    root.reset5hMins = d.reset_5h_mins ?? 0
                    root.reset7dMins = d.reset_7d_mins ?? 0
                    root.tokensToday = d.tokens_today  ?? 0
                    root.prompts5h   = d.prompts_5h    ?? 0
                    root.prompts7d   = d.prompts_7d    ?? 0
                    root.apiOk       = d.api_ok        ?? false
                    root.usageDays   = d.days          ?? []
                    root.planType    = d.plan_type      ?? ""
                    root.planTier    = d.plan_tier      ?? ""
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
    readonly property string workspaceDir:
        pluginApi?.pluginSettings?.workspaceDir || ""
    readonly property bool autoStart:
        pluginApi?.pluginSettings?.autoStart ?? true
    readonly property bool showUsage:
        pluginApi?.pluginSettings?.showUsage ?? true

    function toggleAutoStart() {
        var val = !(pluginApi?.pluginSettings?.autoStart ?? true)
        pluginApi.pluginSettings.autoStart = val
        pluginApi.saveSettings()
    }

    function toggleShowUsage() {
        var val = !(pluginApi?.pluginSettings?.showUsage ?? true)
        pluginApi.pluginSettings.showUsage = val
        pluginApi.saveSettings()
    }
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
    // If workspaceDir is set, run inside a tiny sh wrapper that cd's first
    // (handles ~ expansion safely; positional args avoid quote-injection).
    readonly property var _primaryCmd: {
        if (!workspaceDir || workspaceDir.length === 0) {
            return [claudeBin, "remote-control",
                    "--name", configuredName,
                    "--spawn", "session"]
        }
        var script =
            'case "$1" in "~") set -- "$HOME" "$2" "$3";; ' +
            '"~/"*) set -- "$HOME/${1#"~/"}" "$2" "$3";; esac; ' +
            'cd "$1" || exit 1; ' +
            'exec "$2" remote-control --name "$3" --spawn session'
        return ["sh", "-c", script, "_", workspaceDir, claudeBin, configuredName]
    }

    Process {
        id: rcProcess
        running: false
        command: root._primaryCmd

        onRunningChanged: {
            if (running) {
                root.rcStatus = "connecting";
                connectionTimer.restart();
            }
        }

        stdout: StdioCollector { onTextChanged: root.parseOutput(text) }

        onExited: (exitCode, exitStatus) => {
            var wasConnecting = connectionTimer.running;
            root.rcStatus       = "stopped";
            root.activeSessions = 0;
            connectionTimer.stop();
            sessionPoller.running = false;
            Logger.i("ClaudeRemote", "Primary daemon exited — code " + exitCode);
            if (wasConnecting) {
                root.startupFailed = true;
                root.startupErrorType = root.claudeFound ? "workspace" : "binary";
                Logger.i("ClaudeRemote", "Quick exit — type: " + root.startupErrorType);
            }
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
        command: [root.scriptPath, pendingName, root.claudeBin, root.workspaceDir]
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

    // Returns the right argv for launching `cmd arg` inside a terminal emulator.
    // Different terminals use different flags for "run this command":
    //   -e:        alacritty, ghostty, konsole, xterm
    //   start --:  wezterm
    //   --:        kitty, foot, gnome-terminal (and unknown fallback)
    function buildTermCmd(terminal, cmd, arg) {
        var slash = terminal.lastIndexOf("/")
        var base = slash >= 0 ? terminal.substring(slash + 1) : terminal
        if (base === "alacritty" || base === "ghostty" || base === "konsole" || base === "xterm") {
            return [terminal, "-e", cmd, arg]
        }
        if (base === "wezterm") {
            return [terminal, "start", "--", cmd, arg]
        }
        return [terminal, "--", cmd, arg]
    }

    Process {
        id: skillRunner
        property string skillName: ""
        running: false
        command: root.buildTermCmd(root.terminalBin, root.claudeBin, "/" + skillName)
    }

    // ── Controls ──────────────────────────────────────────────────────────
    property bool _pendingRestart: false

    function start() {
        if (!rcProcess.running) {
            root.startupFailed = false;
            root.startupErrorType = "";
            rcProcess.running = true;
        }
    }
    function stop()    { connectionTimer.stop(); sessionPoller.running = false; rcProcess.running = false; }
    function restart() { _pendingRestart = true; stop(); }

    // Opens a terminal in the configured workspace dir running claude, so the
    // user can accept the trust prompt and set up the workspace interactively.
    readonly property var _setupCmd: {
        var dir = workspaceDir.length > 0 ? workspaceDir : "~"
        // Expand ~ safely via positional args — $1 = dir, $2 = claudeBin
        var snippet =
            'case "$1" in "~") set -- "$HOME" "$2";; ' +
            '"~/"*) set -- "$HOME/${1#"~/"}" "$2";; esac; ' +
            'cd "$1" && exec "$2"'
        var slash = terminalBin.lastIndexOf("/")
        var base = slash >= 0 ? terminalBin.substring(slash + 1) : terminalBin
        if (base === "alacritty" || base === "ghostty" || base === "konsole" || base === "xterm")
            return [terminalBin, "-e", "sh", "-c", snippet, "_", dir, claudeBin]
        if (base === "wezterm")
            return [terminalBin, "start", "--", "sh", "-c", snippet, "_", dir, claudeBin]
        return [terminalBin, "--", "sh", "-c", snippet, "_", dir, claudeBin]
    }

    function setupWorkspace() { setupProc.running = true }

    Process {
        id: setupProc
        running: false
        command: root._setupCmd
    }

    // ── Claude binary preflight ───────────────────────────────────────────
    Process {
        id: preflightProc
        running: false
        // Pass claudeBin as $1 to avoid interpolation issues with non-standard paths
        command: ["sh", "-c",
            'command -v "$1" >/dev/null 2>&1 && echo found || echo missing',
            "_", root.claudeBin]
        stdout: StdioCollector {
            onStreamFinished: {
                root.claudeFound  = text.trim() === "found"
                root.preflightDone = true
                Logger.i("ClaudeRemote", "Preflight: " + root.claudeBin
                    + (root.claudeFound ? " found" : " not found"))
            }
        }
    }

    // Re-check if the user changes the binary path in Settings
    onClaudeBinChanged: {
        root.claudeFound   = true
        root.preflightDone = false
        preflightProc.running = true
    }

    Process {
        id: openBrowserProc
        running: false
        command: ["xdg-open", "https://claude.ai/code"]
    }

    function openInstallPage() { openBrowserProc.running = true }

    Component.onCompleted: {
        preflightProc.running = true;
        skillLister.running   = true;
        usageProc.running     = true;
        if (root.autoStart) {
            root.start();
            Logger.i("ClaudeRemote", "Auto-start: starting daemon");
        } else {
            Logger.i("ClaudeRemote", "Auto-start disabled");
        }
    }
}
