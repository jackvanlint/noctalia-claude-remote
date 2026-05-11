import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    // ── Required by noctalia bar plugin API ───────────────────────────────
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property real baseSize: Style.capsuleHeight
    property bool applyUiScale: false
    property string tooltipDirection: BarService.getTooltipDirection()
    property bool enabled: true
    property bool allowClickWhenDisabled: false
    property bool hovering: false

    property color colorBg:           Color.mSurfaceVariant
    property color colorFg:           Color.mPrimary
    property color colorBgHover:      Color.mHover
    property color colorFgHover:      Color.mOnHover
    property color colorBorder:       Color.mOutline
    property color colorBorderHover:  Color.mOutline
    property real  customRadius:      Style.radiusL

    signal entered()
    signal exited()
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int angleDelta)

    // ── Data from Main.qml ────────────────────────────────────────────────
    readonly property var    main:       pluginApi?.mainInstance
    readonly property string rcStatus:   main?.rcStatus ?? "stopped"
    readonly property int    namedCount: main?.namedSessions?.length ?? 0
    readonly property bool   anyActive:  rcStatus === "connected" || namedCount > 0

    readonly property real contentWidth:  applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)
    readonly property real contentHeight: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)

    implicitWidth:  contentWidth
    implicitHeight: contentHeight

    property string tooltipText: {
        switch (rcStatus) {
            case "connected":
                var name = main?.sessionName ?? ""
                var n    = main?.activeSessions ?? 0
                return "Claude Remote\n" + (name ? name : "Connected") + (n > 0 ? "\n" + n + " active session" + (n === 1 ? "" : "s") : "")
            case "connecting":
                return "Claude Remote\nConnecting…"
            default:
                return "Claude Remote\nNot running"
        }
    }

    // ── Visual ────────────────────────────────────────────────────────────
    Rectangle {
        id: capsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width:  root.contentWidth
        height: root.contentHeight
        color:        hovering ? colorBgHover : colorBg
        radius:       Math.min((customRadius >= 0 ? customRadius : Style.iRadiusL), width / 2)
        border.color: hovering ? colorBorderHover : colorBorder
        border.width: Style.borderS

        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Brain icon — represents Claude/AI
        NIcon {
            anchors.centerIn: parent
            icon:  "brain"
            color: anyActive
                   ? (hovering ? colorFgHover : colorFg)
                   : Color.mOnSurfaceVariant
        }

        // Status dot — top-right corner
        Rectangle {
            z: 1
            anchors.top:        parent.top
            anchors.right:      parent.right
            anchors.topMargin:  3
            anchors.rightMargin: 3
            width:  6
            height: 6
            radius: 3
            border.width: 1
            border.color: capsule.color

            color: {
                if (rcStatus === "connected" || namedCount > 0) return "#4caf50"
                if (rcStatus === "connecting") return "#ff9800"
                return "#f44336"
            }

            // Pulse while connecting
            SequentialAnimation on opacity {
                running:  rcStatus === "connecting"
                loops:    Animation.Infinite
                NumberAnimation { to: 0.3; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }
    }

    // ── Right-click context menu ──────────────────────────────────────────
    QQC.Popup {
        id: contextMenu
        parent: root
        x: 0
        y: root.height + 4
        padding: 0
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

        background: Rectangle {
            color:        Color.mSurface
            radius:       Style.radiusM
            border.color: Color.mOutline
            border.width: Style.borderS
        }

        contentItem: ColumnLayout {
            spacing: 0
            width: 200 * Style.uiScaleRatio

            // ── Toggle: Auto-start on login ───────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 40 * Style.uiScaleRatio

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusM
                    color: autoStartHover.containsMouse ? Color.mHover : "transparent"
                }

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.marginM; rightMargin: Style.marginM
                    }
                    spacing: Style.marginS

                    NText {
                        text: "Auto-start on login"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    // Toggle switch
                    Rectangle {
                        width: 28 * Style.uiScaleRatio
                        height: 16 * Style.uiScaleRatio
                        radius: height / 2
                        color: (main?.autoStart ?? true) ? Color.mPrimary : Color.mSurfaceVariant

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 12 * Style.uiScaleRatio
                            height: 12 * Style.uiScaleRatio
                            radius: height / 2
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (main?.autoStart ?? true) ? parent.width - width - 2 : 2

                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
                        }
                    }
                }

                MouseArea {
                    id: autoStartHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: main?.toggleAutoStart()
                }
            }

            // ── Toggle: Show usage bars ───────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 40 * Style.uiScaleRatio

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusM
                    color: showUsageHover.containsMouse ? Color.mHover : "transparent"
                }

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.marginM; rightMargin: Style.marginM
                    }
                    spacing: Style.marginS

                    NText {
                        text: "Show usage bars"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 28 * Style.uiScaleRatio
                        height: 16 * Style.uiScaleRatio
                        radius: height / 2
                        color: (main?.showUsage ?? true) ? Color.mPrimary : Color.mSurfaceVariant

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 12 * Style.uiScaleRatio
                            height: 12 * Style.uiScaleRatio
                            radius: height / 2
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (main?.showUsage ?? true) ? parent.width - width - 2 : 2

                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
                        }
                    }
                }

                MouseArea {
                    id: showUsageHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: main?.toggleShowUsage()
                }
            }

            // ── Separator ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: Style.borderS
                color: Color.mOutline
                opacity: 0.6
            }

            // ── Action: Start / Stop ──────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 40 * Style.uiScaleRatio

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusM
                    color: startStopHover.containsMouse ? Color.mHover : "transparent"
                }

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.marginM; rightMargin: Style.marginM
                    }
                    spacing: Style.marginS

                    NIcon {
                        icon: rcStatus === "stopped" ? "player-play" : "player-stop"
                        pointSize: Style.fontSizeM
                        color: rcStatus === "stopped" ? Color.mPrimary : Color.mError
                    }

                    NText {
                        text: rcStatus === "stopped" ? "Start daemon" : "Stop daemon"
                        pointSize: Style.fontSizeM
                        color: rcStatus === "stopped" ? Color.mPrimary : Color.mError
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: startStopHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rcStatus === "stopped") main?.start()
                        else main?.stop()
                        contextMenu.close()
                    }
                }
            }
        }
    }

    // ── Interaction ───────────────────────────────────────────────────────
    MouseArea {
        anchors.fill:    parent
        hoverEnabled:    true
        cursorShape:     Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered:  { root.hovering = true;  root.entered() }
        onExited:   { root.hovering = false; root.exited()  }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.open()
            } else {
                if (pluginApi) pluginApi.openPanel(root.screen, this)
            }
        }
        onPressAndHold: root.rightClicked()
        onWheel: (wheel) => root.wheel(wheel.angleDelta.y)
    }
}
