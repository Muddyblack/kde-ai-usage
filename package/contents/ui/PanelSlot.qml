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

    // ── Spark-line (mini trend) ─────────────────────────────────────────
    Canvas {
        id: sparkCanvas
        visible: !slot.showCost && slot.spark && slot.spark.length >= 2
        width: visible ? 28 : 0
        height: 14
        Layout.alignment: Qt.AlignVCenter
        property var pts: slot.spark
        property color lineColor: slot.iconColor
        onPtsChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var p = pts;
            if (!p || p.length < 2)
                return;
            var minT = p[0].t, maxT = p[p.length - 1].t;
            var tr = maxT - minT || 1;
            // autoscale y to the visible value range so small movements still read
            var minV = p[0].v, maxV = p[0].v;
            for (var k = 0; k < p.length; k++) {
                if (p[k].v < minV)
                    minV = p[k].v;
                if (p[k].v > maxV)
                    maxV = p[k].v;
            }
            var vr = (maxV - minV) || 1;
            var pad = 2;
            function X(i) {
                return ((p[i].t - minT) / tr) * (width - pad * 2) + pad;
            }
            function Y(v) {
                return (height - pad) - ((v - minV) / vr) * (height - pad * 2);
            }
            var r = Math.round(lineColor.r * 255), g = Math.round(lineColor.g * 255), b = Math.round(lineColor.b * 255);
            ctx.beginPath();
            ctx.moveTo(X(0), Y(p[0].v));
            for (var i = 1; i < p.length; i++)
                ctx.lineTo(X(i), Y(p[i].v));
            ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ",0.85)";
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
            // endpoint dot
            ctx.beginPath();
            ctx.arc(X(p.length - 1), Y(p[p.length - 1].v), 1.6, 0, Math.PI * 2);
            ctx.fillStyle = "rgba(" + r + "," + g + "," + b + ",1)";
            ctx.fill();
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
