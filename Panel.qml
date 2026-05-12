import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var  geometryPlaceholder:   panelContainer
    readonly property bool allowAttach:            true
    property string panelPage: "main"   // "main" | "usage" | "skills"
    property string expandedSkill: ""
    readonly property int skillsCount: main?.skills?.length ?? 0

    // Fixed-height panel — main page stays one size so adding sessions doesn't
    // shove the footer buttons around. Sub-pages get their own sizes.
    property real contentPreferredWidth: 380 * Style.uiScaleRatio
    property real contentPreferredHeight: (
        panelPage === "skills" ? 520 :
        panelPage === "usage"  ? 320 :
                                 640
    ) * Style.uiScaleRatio

    Behavior on contentPreferredHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function fmtTokens(t) {
        if (t >= 1000000) return (t / 1000000).toFixed(1) + "M"
        if (t >= 1000)    return Math.round(t / 1000) + "k"
        return t.toString()
    }

    function fmtReset(mins) {
        if (mins <= 0) return "Resets now"
        var d = Math.floor(mins / 1440)
        var h = Math.floor((mins % 1440) / 60)
        var m = mins % 60
        return d > 0 ? "Resets in " + d + "d " + h + "h" : "Resets in " + h + "h " + m + "m"
    }

    function barColor(pct) {
        if (pct >= 0.9) return "#ef5350"
        if (pct >= 0.7) return "#ff9800"
        return Color.mPrimary
    }

    // Plan badge — handles both bare ("pro", "max_5x") and prefixed
    // ("claude_pro") subscription strings returned by the API.
    function planNorm(t) {
        if (!t) return ""
        return t.toLowerCase().replace(/^claude_/, "")
    }
    function planDisplay(t) {
        var s = planNorm(t)
        if (!s) return ""
        if (s === "max_5x")  return "MAX 5×"
        if (s === "max_20x") return "MAX 20×"
        if (s === "max")     return "MAX"
        if (s === "pro")     return "PRO"
        if (s === "free")    return "FREE"
        return s.replace(/_/g, " ").toUpperCase()
    }

    readonly property var    main:       pluginApi?.mainInstance
    readonly property string rcStatus:   main?.rcStatus ?? "stopped"
    readonly property var    named:      main?.namedSessions ?? []
    readonly property int    namedCount: named.length
    readonly property var    favSet: {
        var s = new Set()
        var favs = main?.favourites ?? []
        for (var i = 0; i < favs.length; i++) s.add(favs[i])
        return s
    }

    // Suggested Skills — favourites first (pinned, shown with ★), then the
    // rest of the catalogue alphabetical; capped at quickLaunchMax.
    readonly property int  quickLaunchMax: 6
    readonly property var  quickLaunchSkills: {
        var all = main?.skills ?? []
        if (all.length === 0) return []
        var pinned  = all.filter(function(s) { return favSet.has(s.name) })
        var rest    = all.filter(function(s) { return !favSet.has(s.name) })
        return pinned.concat(rest).slice(0, quickLaunchMax)
    }
    readonly property bool quickLaunchVisible: quickLaunchSkills.length > 0

    // ── Derived state helpers ─────────────────────────────────────────────
    readonly property bool isStopped:     rcStatus === "stopped"
    readonly property bool didFail:       main?.startupFailed ?? false
    readonly property bool binaryMissing: isStopped &&  didFail && (main?.startupErrorType ?? "") === "binary"
    readonly property bool trustNeeded:   isStopped &&  didFail && (main?.startupErrorType ?? "") === "workspace"
    readonly property bool claudeAbsent:  isStopped && !didFail && (main?.preflightDone ?? false) && !(main?.claudeFound ?? true)
    readonly property bool readyToStart:  isStopped && !didFail && (!(main?.preflightDone ?? false) || (main?.claudeFound ?? true))

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color:  Color.mSurface
        radius: Style.radiusL

        // ── Main page ─────────────────────────────────────────────────────
        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM
            visible: panelPage === "main"

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                // Plan badge — dark-primary pill, mirroring the connected badge
                // pattern (dark muted bg + lighter text in the same colour
                // family) but using mPrimary instead of green.
                Rectangle {
                    visible: planText.text !== ""
                    Layout.preferredWidth:  planText.implicitWidth + Style.marginM * 2
                    Layout.preferredHeight: planText.implicitHeight + Style.marginXS * 2 + 2
                    radius: Style.radiusS
                    color: Qt.rgba(Color.mPrimary.r * 0.22,
                                   Color.mPrimary.g * 0.22,
                                   Color.mPrimary.b * 0.22, 1.0)

                    NText {
                        id: planText
                        anchors.centerIn: parent
                        text: planDisplay(main?.planType ?? "")
                        pointSize: Style.fontSizeS
                        color: Qt.rgba(Math.min(1, Color.mPrimary.r * 0.75 + 0.25),
                                       Math.min(1, Color.mPrimary.g * 0.75 + 0.25),
                                       Math.min(1, Color.mPrimary.b * 0.75 + 0.25), 1.0)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                NText {
                    text: "Claude Remote"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth:  badge.implicitWidth + Style.marginM * 2
                    Layout.preferredHeight: badge.implicitHeight + Style.marginXS * 2 + 2
                    radius: Style.radiusS
                    color: (rcStatus === "connected" || namedCount > 0) ? "#1e4620" : rcStatus === "connecting" ? "#4a3200" : "#4a1212"

                    NText {
                        id: badge
                        anchors.centerIn: parent
                        text: (rcStatus === "connected" || namedCount > 0) ? "Connected" : rcStatus === "connecting" ? "Connecting…" : "Stopped"
                        pointSize: Style.fontSizeS
                        color: (rcStatus === "connected" || namedCount > 0) ? "#81c784" : rcStatus === "connecting" ? "#ffb74d" : "#ef9a9a"
                    }
                }
            }

            NDivider { visible: main?.showUsage ?? true }

            // ── Rate limit usage ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: main?.showUsage ?? true

                NText {
                    text: "Rate Limit Usage"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    font.weight: Style.fontWeightSemiBold
                }

                // Session bar (5-hour) — click to open usage page
                Item {
                    Layout.fillWidth: true
                    implicitHeight: sessionBarCol.implicitHeight

                    ColumnLayout {
                        id: sessionBarCol
                        anchors { left: parent.left; right: parent.right }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            NText {
                                text: "Session (5-hour)"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: (main?.pct5h ?? -1) >= 0 ? Math.round((main?.pct5h ?? 0) * 100) + "%" : "—"
                                pointSize: Style.fontSizeS
                                color: barColor(main?.pct5h ?? 0)
                                font.weight: Style.fontWeightSemiBold
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Color.mSurfaceVariant

                            Rectangle {
                                width: (main?.pct5h ?? -1) >= 0
                                       ? Math.max(radius * 2, parent.width * Math.min(main?.pct5h ?? 0, 1.0))
                                       : radius * 2
                                height: parent.height
                                radius: 3
                                color: barColor(main?.pct5h ?? 0)
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }

                        NText {
                            text: fmtReset(main?.reset5hMins ?? 0)
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panelPage = "usage"
                    }
                }

                // Weekly bar (7-day) — click to open usage page
                Item {
                    Layout.fillWidth: true
                    implicitHeight: weeklyBarCol.implicitHeight

                    ColumnLayout {
                        id: weeklyBarCol
                        anchors { left: parent.left; right: parent.right }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            NText {
                                text: "Weekly (7-day)"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: (main?.pct7d ?? -1) >= 0 ? Math.round((main?.pct7d ?? 0) * 100) + "%" : "—"
                                pointSize: Style.fontSizeS
                                color: barColor(main?.pct7d ?? 0)
                                font.weight: Style.fontWeightSemiBold
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Color.mSurfaceVariant

                            Rectangle {
                                width: (main?.pct7d ?? -1) >= 0
                                       ? Math.max(radius * 2, parent.width * Math.min(main?.pct7d ?? 0, 1.0))
                                       : radius * 2
                                height: parent.height
                                radius: 3
                                color: barColor(main?.pct7d ?? 0)
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }

                        NText {
                            text: fmtReset(main?.reset7dMins ?? 0)
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panelPage = "usage"
                    }
                }

                // Token counter chip — neutral
                Rectangle {
                    Layout.fillWidth: true
                    height: tokenRow.implicitHeight + Style.marginS * 2
                    radius: Style.radiusS
                    color:  Color.mSurfaceVariant

                    RowLayout {
                        id: tokenRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                        spacing: Style.marginS

                        NIcon {
                            icon: "cpu"
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                        }

                        NText {
                            text: fmtTokens(main?.tokensToday ?? 0) + " tokens today"
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            NDivider { visible: main?.showUsage ?? true }

            // ── Max sessions warning ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: rcStatus === "connected" && (main?.activeSessions ?? 0) >= (main?.maxSessions ?? 32)

                NIcon { icon: "alert-triangle"; pointSize: Style.fontSizeM; color: Color.mError }
                NText {
                    text: "Max concurrent sessions reached"
                    pointSize: Style.fontSizeM
                    color: Color.mError
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: rcStatus !== "connected" && namedCount === 0

                // ── Connecting ────────────────────────────────────────────
                NText {
                    visible: rcStatus === "connecting"
                    text: "Establishing connection…"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                }

                // ── Status heading ────────────────────────────────────────
                NText {
                    visible: isStopped && didFail
                    text: "Daemon failed to start"
                    pointSize: Style.fontSizeM
                    color: Color.mError
                    Layout.fillWidth: true
                }

                NText {
                    visible: claudeAbsent
                    text: "Claude Code not found"
                    pointSize: Style.fontSizeM
                    color: Color.mError
                    Layout.fillWidth: true
                }

                NText {
                    visible: readyToStart && !(main?.preflightDone ?? false)
                    text: "Daemon is not running"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                }

                // ── Ready to start: workspace hint ────────────────────────
                NText {
                    visible: readyToStart
                    text: "Workspace: " + (main?.workspaceDir || "~") + "  ·  change in Settings if needed"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    opacity: 0.6
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                // ── Claude not installed (preflight or binary error) ───────
                NText {
                    visible: claudeAbsent || binaryMissing
                    text: binaryMissing
                        ? "Binary not found at \"" + (main?.claudeBin || "claude") + "\". " +
                          "If Claude Code is already installed, enter the correct path in Settings. " +
                          "Otherwise, install it first."
                        : "1. Download and install Claude Code from claude.ai/code\n" +
                          "2. Open a terminal and run: claude\n" +
                          "3. Sign in with your Anthropic account\n" +
                          "4. Accept any workspace trust prompts\n" +
                          "5. Come back here and click Start"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                NButton {
                    visible: claudeAbsent || binaryMissing
                    Layout.fillWidth: true
                    text: "Get Claude Code"
                    icon: "external-link"
                    outlined: true
                    onClicked: main?.openInstallPage()
                }

                // ── Workspace not trusted (startup failed, binary was found) ─
                NText {
                    visible: trustNeeded
                    text: "Your workspace may not be trusted by Claude.\n" +
                          "Click below to open a terminal there and run claude — " +
                          "accept the trust prompt, then click Start."
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                NButton {
                    visible: trustNeeded
                    Layout.fillWidth: true
                    text: "Set up workspace"
                    icon: "terminal"
                    outlined: true
                    onClicked: main?.setupWorkspace()
                }
            }

            // ── Named sessions list ───────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS
                visible: namedCount > 0

                NDivider {}

                NText {
                    text: "Named Sessions"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    font.weight: Style.fontWeightSemiBold
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(namedCount, 3) * 38 * Style.uiScaleRatio
                    Behavior on implicitHeight {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    Flickable {
                        id: sessionsFlick
                        anchors { fill: parent; rightMargin: 10 * Style.uiScaleRatio }
                        contentHeight: sessionsCol.implicitHeight
                        clip: true
                        interactive: contentHeight > height + 1

                        property bool needsScroll: contentHeight > height + 1

                        ColumnLayout {
                            id: sessionsCol
                            width: sessionsFlick.width
                            spacing: Style.marginXS

                            Repeater {
                                model: named
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    Rectangle { width: 6; height: 6; radius: 3; color: "#4caf50" }

                                    NText {
                                        text: modelData.name
                                        pointSize: Style.fontSizeM
                                        color: Color.mOnSurface
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    NButton {
                                        text: "Stop"
                                        icon: "player-stop"
                                        outlined: true
                                        Layout.preferredWidth: 72 * Style.uiScaleRatio
                                        textColor: Color.mError
                                        onClicked: main?.removeNamedSession(modelData.pid)
                                    }
                                }
                            }
                        }
                    }

                    // Scrollbar track + handle
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 5 * Style.uiScaleRatio
                        radius: 3 * Style.uiScaleRatio
                        color: Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.1)
                        visible: sessionsFlick.needsScroll

                        Rectangle {
                            width: parent.width
                            radius: parent.radius
                            color: Color.mOnSurface
                            opacity: 0.55

                            height: {
                                if (!sessionsFlick.needsScroll) return 0
                                var ratio = sessionsFlick.height / sessionsFlick.contentHeight
                                return Math.max(16 * Style.uiScaleRatio, sessionsFlick.height * ratio)
                            }
                            y: {
                                var scrollable = sessionsFlick.contentHeight - sessionsFlick.height
                                if (scrollable <= 0) return 0
                                return (sessionsFlick.contentY / scrollable) * (sessionsFlick.height - height)
                            }
                        }
                    }
                }
            }

            // ── Suggested Skills (always shown when skills exist) ─────────
            // Pinned skills (favourites) come first and carry a small ★
            // marker; the rest fill remaining slots alphabetically. Tap a
            // chip to launch the skill in a terminal.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: quickLaunchVisible

                NDivider {}

                NText {
                    text: "Suggested Skills"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    font.weight: Style.fontWeightSemiBold
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    Repeater {
                        model: quickLaunchSkills
                        delegate: Rectangle {
                            id: chip
                            readonly property bool isPinned: favSet.has(modelData.name)

                            width: chipRow.implicitWidth + Style.marginM * 2
                            height: chipRow.implicitHeight + Style.marginXS * 2 + 4
                            radius: height / 2
                            color: chipHover.containsMouse
                                ? Qt.lighter(Color.mSurfaceVariant, 1.18)
                                : Color.mSurfaceVariant
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5

                                NIcon {
                                    visible: chip.isPinned
                                    icon: "star-filled"
                                    pointSize: Style.fontSizeS - 1
                                    color: Color.mOnSurfaceVariant
                                }

                                NText {
                                    text: modelData.name
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurface
                                    font.weight: Style.fontWeightSemiBold
                                }
                            }

                            MouseArea {
                                id: chipHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: main?.runSkill(modelData.name)
                            }
                        }
                    }
                }
            }

            // Absorbs slack so the New Session + footer buttons stay pinned
            // to the bottom even when sessions count or content changes.
            Item { Layout.fillHeight: true }

            // ── New named session ─────────────────────────────────────────
            NDivider {}

            NButton {
                Layout.fillWidth: true
                text: "New Session"
                icon: "plus"
                onClicked: {
                    var now = new Date()
                    var hhmm = now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0")
                    main?.addNamedSession("Remote Session: " + hhmm)
                }
            }

            // ── Footer actions ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    Layout.fillWidth: true
                    outlined: true
                    text: "Skills"
                    icon: "sparkles"
                    onClicked: root.panelPage = "skills"
                }

                NButton {
                    Layout.fillWidth: true
                    outlined: true
                    text: rcStatus === "stopped" ? "Start" : "Restart"
                    icon: rcStatus === "stopped" ? "player-play" : "refresh"
                    textColor: rcStatus === "stopped" ? Color.mPrimary : Color.mOnSurfaceVariant
                    onClicked: {
                        if (rcStatus === "stopped") main?.start()
                        else main?.restart()
                    }
                }
            }
        }

        // ── Skills page ───────────────────────────────────────────────────
        // Stand-alone page (like Usage) with a scrollable list — keeps the
        // main panel a fixed height instead of growing tall with skills.
        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM
            visible: panelPage === "skills"

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    icon: "arrow-left"
                    outlined: true
                    Layout.preferredWidth: 36 * Style.uiScaleRatio
                    onClicked: { root.expandedSkill = ""; root.panelPage = "main" }
                }

                NText {
                    text: "Skills"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NText {
                    text: skillsCount + (skillsCount === 1 ? " skill" : " skills")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    opacity: 0.7
                }
            }

            NDivider {}

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: skillsFlick
                    anchors { fill: parent; rightMargin: 10 * Style.uiScaleRatio }
                    contentHeight: skillsCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height + 1
                    boundsBehavior: Flickable.StopAtBounds

                    property bool needsScroll: contentHeight > height + 1

                    ColumnLayout {
                        id: skillsCol
                        width: skillsFlick.width
                        spacing: Style.marginXS

                        NText {
                            visible: skillsCount === 0
                            Layout.fillWidth: true
                            text: "No skills found.\nAdd commands to ~/.claude/commands/ as .md files."
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Repeater {
                            model: main?.sortedSkills ?? []
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXS

                                readonly property bool isFavourite: favSet.has(modelData.name)
                                readonly property bool isExpanded: expandedSkill === modelData.name

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    NIcon {
                                        icon: isFavourite ? "star-filled" : "sparkles"
                                        pointSize: Style.fontSizeM
                                        color: Color.mOnSurfaceVariant
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: textCol.implicitHeight

                                        ColumnLayout {
                                            id: textCol
                                            anchors { left: parent.left; right: parent.right }
                                            spacing: 1

                                            NText {
                                                text: modelData.name
                                                pointSize: Style.fontSizeM
                                                color: isExpanded ? Color.mOnSurface : Color.mOnSurface
                                                font.weight: isExpanded ? Style.fontWeightSemiBold : Font.Normal
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            NText {
                                                text: modelData.description
                                                pointSize: Style.fontSizeS
                                                color: Color.mOnSurfaceVariant
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                visible: modelData.description.length > 0
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: expandedSkill = isExpanded ? "" : modelData.name
                                        }
                                    }

                                    NButton {
                                        icon: isFavourite ? "star-filled" : "star"
                                        outlined: true
                                        Layout.preferredWidth: 36 * Style.uiScaleRatio
                                        textColor: Color.mOnSurfaceVariant
                                        onClicked: main?.toggleFavourite(modelData.name)
                                    }

                                    NButton {
                                        text: "Run"
                                        icon: "player-play"
                                        outlined: true
                                        Layout.preferredWidth: 72 * Style.uiScaleRatio
                                        onClicked: main?.runSkill(modelData.name)
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: isExpanded
                                    implicitHeight: overviewText.implicitHeight + Style.marginM * 2
                                    radius: Style.radiusS
                                    color: Color.mSurfaceVariant

                                    NText {
                                        id: overviewText
                                        anchors {
                                            left: parent.left; right: parent.right
                                            top: parent.top; margins: Style.marginM
                                        }
                                        text: modelData.detail || modelData.description
                                        pointSize: Style.fontSizeS
                                        color: Color.mOnSurfaceVariant
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                // Scrollbar track + handle (same pattern as sessions list)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 5 * Style.uiScaleRatio
                    radius: 3 * Style.uiScaleRatio
                    color: Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.1)
                    visible: skillsFlick.needsScroll

                    Rectangle {
                        width: parent.width
                        radius: parent.radius
                        color: Color.mOnSurface
                        opacity: 0.55

                        height: {
                            if (!skillsFlick.needsScroll) return 0
                            var ratio = skillsFlick.height / skillsFlick.contentHeight
                            return Math.max(16 * Style.uiScaleRatio, skillsFlick.height * ratio)
                        }
                        y: {
                            var scrollable = skillsFlick.contentHeight - skillsFlick.height
                            if (scrollable <= 0) return 0
                            return (skillsFlick.contentY / scrollable) * (skillsFlick.height - height)
                        }
                    }
                }
            }
        }

        // ── Weekly Usage page ─────────────────────────────────────────────
        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM
            visible: panelPage === "usage"

            // Back + title
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    icon: "arrow-left"
                    outlined: true
                    Layout.preferredWidth: 36 * Style.uiScaleRatio
                    onClicked: root.panelPage = "main"
                }

                NText {
                    text: "Weekly Usage"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
            }

            NText {
                text: "Prompts per day — last 7 days"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NDivider {}

            // Bar chart — native QML rects, no Canvas
            Item {
                id: chartArea
                Layout.fillWidth: true
                implicitHeight: 160 * Style.uiScaleRatio

                readonly property var days: main?.usageDays ?? []
                readonly property int maxVal: {
                    var m = 1
                    for (var i = 0; i < days.length; i++) m = Math.max(m, days[i].prompts)
                    return m
                }
                readonly property int n: days.length
                readonly property real gap: 6 * Style.uiScaleRatio
                readonly property real barW: n > 0 ? (width - gap * (n - 1)) / n : width
                readonly property real labelH: 20 * Style.uiScaleRatio
                readonly property real chartH: height - labelH

                NText {
                    anchors.centerIn: parent
                    text: "No data yet"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    visible: chartArea.n === 0
                }

                Repeater {
                    model: chartArea.days
                    delegate: Item {
                        x: index * (chartArea.barW + chartArea.gap)
                        y: 0
                        width: chartArea.barW
                        height: chartArea.height

                        readonly property real frac: chartArea.maxVal > 0 ? modelData.prompts / chartArea.maxVal : 0

                        // Day label
                        NText {
                            id: dayLbl
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: Qt.formatDate(new Date(modelData.date + "T00:00:00"), "ddd")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }

                        // Bar
                        Rectangle {
                            id: barRect
                            anchors { bottom: dayLbl.top; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                            width: parent.width - 2
                            height: Math.max(4, chartArea.chartH * frac)
                            radius: 3
                            color: Color.mPrimary
                            opacity: 0.5 + 0.5 * frac
                        }

                        // Count above bar
                        NText {
                            anchors { bottom: barRect.top; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
                            text: modelData.prompts > 999
                                  ? (modelData.prompts / 1000).toFixed(1) + "k"
                                  : modelData.prompts.toString()
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurface
                            visible: modelData.prompts > 0
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
