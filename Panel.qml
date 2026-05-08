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
    property real contentPreferredWidth: 380 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.max(220,
        180 + namedCount * 38 + (namedCount > 0 ? 52 : 0) + 52) * Style.uiScaleRatio

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

            // ── Primary session info ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: rcStatus === "connected"

                NIcon { icon: "circles-relation"; pointSize: Style.fontSizeM; color: Color.mOnSurfaceVariant }
                NText {
                    text: {
                        var n = main?.activeSessions ?? 0
                        var m = main?.maxSessions ?? 32
                        return n + " / " + m + " concurrent sessions"
                    }
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
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
                            backgroundColor: Color.mErrorContainer
                            textColor: Color.mOnErrorContainer
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

            Item { Layout.fillHeight: true }

            // ── Footer actions ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

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
