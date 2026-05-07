import QtQuick
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
    readonly property var    main:     pluginApi?.mainInstance
    readonly property string rcStatus: main?.rcStatus ?? "stopped"

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
            color: rcStatus === "connected"
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
                switch (rcStatus) {
                    case "connected":  return "#4caf50"
                    case "connecting": return "#ff9800"
                    default:           return "#f44336"
                }
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

    // ── Interaction ───────────────────────────────────────────────────────
    MouseArea {
        anchors.fill:  parent
        hoverEnabled:  true
        cursorShape:   Qt.PointingHandCursor

        onEntered:  { root.hovering = true;  root.entered() }
        onExited:   { root.hovering = false; root.exited()  }

        onClicked:      { if (pluginApi) pluginApi.openPanel(root.screen, this) }
        onPressAndHold: root.rightClicked()
        onWheel: (wheel) => root.wheel(wheel.angleDelta.y)
    }
}
