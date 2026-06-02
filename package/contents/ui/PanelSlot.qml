import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Compact panel readout: icon + optional spark-line + animated % / cost text.
RowLayout {
    id: slot
    property real pct: 0
    property color iconColor: "#cc785c"
    property bool stale: false
    property string tooltipText: ""
    property bool showCost: false
    property string costText: ""
    // Optional mini-trend series ({t,v}) drawn as a spark-line behind the readout
    property var spark: []

    // usage-level thresholds (kept local so this component is self-contained)
    readonly property color dangerColor: "#ff4d4d"
    readonly property color warningColor: "#ffa64d"

    // Animated value that eases toward `pct` so the readout rolls up/down
    property real displayPct: 0
    onPctChanged: displayPct = pct
    Component.onCompleted: displayPct = pct
    Behavior on displayPct {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    spacing: 5
    opacity: stale ? 0.55 : 1.0
    Behavior on opacity {
        NumberAnimation {
            duration: 300
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        QQC2.ToolTip.visible: containsMouse && slot.tooltipText !== ""
        QQC2.ToolTip.text: slot.tooltipText
        QQC2.ToolTip.delay: 500
    }

    Item {
        width: 16
        height: 16
        Layout.alignment: Qt.AlignVCenter
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
            isMask: true
            color: slot.iconColor
            opacity: 0.22
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
            isMask: true
            color: slot.iconColor
        }
    }

    PlasmaComponents.Label {
        text: slot.showCost ? slot.costText : Math.round(slot.displayPct) + "%"
        font.pixelSize: 12
        font.bold: true
        color: slot.showCost ? slot.iconColor : (slot.pct >= 90 ? slot.dangerColor : slot.pct >= 70 ? slot.warningColor : Kirigami.Theme.textColor)
        Layout.alignment: Qt.AlignVCenter
    }
}
