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
    property bool showSkills: false
    property string expandedSkill: ""
    property string panelPage: "main"
    readonly property int skillsCount: main?.skills?.length ?? 0

    property real contentPreferredWidth: 380 * Style.uiScaleRatio
    property real contentPreferredHeight: panelPage === "usage"
        ? 320 * Style.uiScaleRatio
        : Math.max(220,
            340 +
            namedCount * 38 + (namedCount > 0 ? 52 : 0) + 52 +
            (showSkills ? skillsCount * 54 + 44 + (expandedSkill !== "" ? 110 : 0) : 0)) * Style.uiScaleRatio

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

    readonly property var    main:       pluginApi?.mainInstance
    readonly property string rcStatus:   main?.rcStatus ?? "stopped"
    readonly property var    named:      main?.namedSessions ?? []
    readonly property int    namedCount: named.length

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

                NIcon { icon: "brain"; color: rcStatus === "connected" ? Color.mPrimary : Color.mOnSurfaceVariant; pointSize: Style.fontSizeXL }

                NText {
                    text: "Claude Remote"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                Rectangle {
                    width:  badge.implicitWidth + Style.marginM * 2
                    height: badge.implicitHeight + Style.marginXS * 2
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

            NDivider {}

            // ── Rate limit usage ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

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

                // Token counter chip
                Rectangle {
                    Layout.fillWidth: true
                    height: tokenRow.implicitHeight + Style.marginS * 2
                    radius: Style.radiusS
                    color:  Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.07)

                    RowLayout {
                        id: tokenRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                        spacing: Style.marginS

                        NIcon { icon: "cpu"; pointSize: Style.fontSizeM; color: Color.mPrimary; opacity: 0.6 }

                        NText {
                            text: fmtTokens(main?.tokensToday ?? 0) + " tokens today"
                            pointSize: Style.fontSizeS
                            color: Color.mPrimary
                            opacity: 0.65
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            NDivider {}

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

            NText {
                visible: rcStatus !== "connected" && namedCount === 0
                text: rcStatus === "connecting" ? "Establishing connection…" : "Daemon is not running"
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
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

            // ── Skills ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS
                visible: showSkills

                NDivider {}

                NText {
                    text: "Skills"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    font.weight: Style.fontWeightSemiBold
                }

                Repeater {
                    model: main?.sortedSkills ?? []
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        readonly property bool isFavourite: (main?.favourites ?? []).indexOf(modelData.name) >= 0
                        readonly property bool isExpanded: expandedSkill === modelData.name

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NIcon {
                                icon: "sparkles"
                                pointSize: Style.fontSizeM
                                color: isFavourite ? Color.mPrimary : Color.mOnSurfaceVariant
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
                                        color: isExpanded ? Color.mPrimary : Color.mOnSurface
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
                                textColor: isFavourite ? "#FFD700" : Color.mOnSurfaceVariant
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

            Item { Layout.fillHeight: true }

            // ── Footer actions ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    Layout.fillWidth: true
                    outlined: true
                    text: showSkills ? "Hide Skills" : "Skills"
                    icon: "sparkles"
                    onClicked: showSkills = !showSkills
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
