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
    property real contentPreferredWidth:  360 * Style.uiScaleRatio
    property real contentPreferredHeight: 220 * Style.uiScaleRatio

    readonly property var    main:     pluginApi?.mainInstance
    readonly property string rcStatus: main?.rcStatus ?? "stopped"

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color:        Color.mSurface
        radius:       Style.radiusL

        ColumnLayout {
            anchors {
                fill:    parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon:      "brain"
                    color:     rcStatus === "connected" ? Color.mPrimary : Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXL
                }

                NText {
                    text:       "Claude Remote"
                    pointSize:  Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color:      Color.mOnSurface
                    Layout.fillWidth: true
                }

                Rectangle {
                    width:  statusLabel.implicitWidth + Style.marginM * 2
                    height: statusLabel.implicitHeight + Style.marginXS * 2
                    radius: Style.radiusS
                    color: {
                        switch (rcStatus) {
                            case "connected":  return "#1e4620"
                            case "connecting": return "#4a3200"
                            default:           return "#4a1212"
                        }
                    }

                    NText {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: {
                            switch (rcStatus) {
                                case "connected":  return "Connected"
                                case "connecting": return "Connecting…"
                                default:           return "Stopped"
                            }
                        }
                        pointSize: Style.fontSizeS
                        color: {
                            switch (rcStatus) {
                                case "connected":  return "#81c784"
                                case "connecting": return "#ffb74d"
                                default:           return "#ef9a9a"
                            }
                        }
                    }
                }
            }

            NDivider {}

            // ── Session info ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS
                visible: rcStatus === "connected"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS
                    visible: (main?.sessionName ?? "") !== ""

                    NIcon { icon: "tag"; pointSize: Style.fontSizeM; color: Color.mOnSurfaceVariant }
                    NText {
                        text:       main?.sessionName ?? ""
                        pointSize:  Style.fontSizeM
                        color:      Color.mOnSurface
                        Layout.fillWidth: true
                        elide:      Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NIcon { icon: "circles-relation"; pointSize: Style.fontSizeM; color: Color.mOnSurfaceVariant }
                    NText {
                        text: {
                            var n = main?.activeSessions ?? 0
                            var m = main?.maxSessions ?? 32
                            return n + " / " + m + " sessions"
                        }
                        pointSize: Style.fontSizeM
                        color:     Color.mOnSurface
                    }
                }
            }

            NText {
                visible:   rcStatus !== "connected"
                text:      rcStatus === "connecting" ? "Establishing connection…" : "Daemon is not running"
                pointSize: Style.fontSizeM
                color:     Color.mOnSurfaceVariant
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            // ── Action buttons ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    Layout.fillWidth: true
                    text:     "Open claude.ai/code"
                    icon:     "external-link"
                    enabled:  rcStatus === "connected" && (main?.envUrl ?? "") !== ""
                    outlined: true
                    onClicked: Qt.openUrlExternally(main.envUrl)
                }

                NButton {
                    Layout.preferredWidth: 90 * Style.uiScaleRatio
                    text: rcStatus === "stopped" ? "Start" : "Restart"
                    icon: rcStatus === "stopped" ? "player-play" : "refresh"
                    backgroundColor: rcStatus === "stopped" ? Color.mPrimary : Color.mSecondaryContainer
                    textColor:       rcStatus === "stopped" ? Color.mOnPrimary : Color.mOnSecondaryContainer
                    onClicked: {
                        if (rcStatus === "stopped") main?.start()
                        else main?.restart()
                    }
                }
            }
        }
    }
}
