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
    readonly property int skillsCount: main?.skills?.length ?? 0

    property real contentPreferredWidth: 380 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.max(220,
        180 + namedCount * 38 + (namedCount > 0 ? 52 : 0) + 52 +
        (showSkills ? skillsCount * 54 + 44 + (expandedSkill !== "" ? 110 : 0) : 0)) * Style.uiScaleRatio

    readonly property var    main:       pluginApi?.mainInstance
    readonly property string rcStatus:   main?.rcStatus ?? "stopped"
    readonly property var    named:      main?.namedSessions ?? []
    readonly property int    namedCount: named.length

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color:  Color.mSurface
        radius: Style.radiusL

        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            // ── Header ────────────────────────────────────────────────────
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
                    color: rcStatus === "connected" ? "#1e4620" : rcStatus === "connecting" ? "#4a3200" : "#4a1212"

                    NText {
                        id: badge
                        anchors.centerIn: parent
                        text: rcStatus === "connected" ? "Connected" : rcStatus === "connecting" ? "Connecting…" : "Stopped"
                        pointSize: Style.fontSizeS
                        color: rcStatus === "connected" ? "#81c784" : rcStatus === "connecting" ? "#ffb74d" : "#ef9a9a"
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
                visible: rcStatus !== "connected"
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
    }
}
