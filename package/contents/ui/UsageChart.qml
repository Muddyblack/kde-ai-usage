import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: usageChartContainer
    property Item rootItem

    visible: !rootItem.showSettings && rootItem.showUsageChart && rootItem.weeklyUsageHistory.length >= 1 && (rootItem.enabledTabs[rootItem.activeTab] === "claude" || (rootItem.enabledTabs[rootItem.activeTab] === "openai" && rootItem.codexUsageAvailable) || rootItem.enabledTabs[rootItem.activeTab] === "antigravity" || rootItem.enabledTabs[rootItem.activeTab] === "openrouter" || rootItem.enabledTabs[rootItem.activeTab] === "mistral")
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: 184
    radius: 10
    color: rootItem.resolvedCardBg
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)
    clip: true

    // subtle inner top highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
        radius: 10
    }

    // ── Chart navigation (top-left) ──
    RowLayout {
        id: chartNavRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 7
        anchors.leftMargin: 12
        spacing: 6

        // Left arrow button
        Rectangle {
            radius: 4
            implicitHeight: 16
            implicitWidth: 16
            color: leftNavMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            opacity: enabled ? 1.0 : 0.3
            enabled: {
                var key = rootItem._historyKey();
                var oldestT = 0;
                for (var i = 0; i < rootItem.usageHistory.length; i++) {
                    var p = rootItem.usageHistory[i];
                    if (p[key] !== undefined && p[key] !== null) {
                        oldestT = p.t;
                        break;
                    }
                }
                if (oldestT === 0)
                    return false;
                var now_ms = new Date().getTime();
                var winSize = rootItem.getChartWindowSize();
                var maxT = now_ms - rootItem.chartTimeOffset;
                var minT = maxT - winSize;
                return minT > oldestT;
            }
            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: "<"
                font.pixelSize: 9
                font.bold: true
                color: Kirigami.Theme.textColor
            }
            MouseArea {
                id: leftNavMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    rootItem.chartTimeOffset += rootItem.getChartWindowSize();
                }
            }
        }

        // Center label showing current range
        PlasmaComponents.Label {
            text: rootItem.getChartRangeText()
            font.pixelSize: 9
            font.bold: true
            opacity: 0.6
            color: Kirigami.Theme.textColor
        }

        // Right arrow button
        Rectangle {
            radius: 4
            implicitHeight: 16
            implicitWidth: 16
            color: rightNavMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            opacity: enabled ? 1.0 : 0.3
            enabled: rootItem.chartTimeOffset > 0
            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: ">"
                font.pixelSize: 9
                font.bold: true
                color: Kirigami.Theme.textColor
            }
            MouseArea {
                id: rightNavMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    var winSize = rootItem.getChartWindowSize();
                    rootItem.chartTimeOffset = Math.max(0, rootItem.chartTimeOffset - winSize);
                }
            }
        }
    }

    // ── Window toggle — Claude: 5H/7D, Codex: 5H/7D (single-series tabs: hidden) ──
    RowLayout {
        id: chartWindowToggle
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 8
        spacing: 4
        visible: {
            var tab = rootItem.enabledTabs[rootItem.activeTab];
            if (tab === "claude") {
                for (var i = 0; i < rootItem.usageHistory.length; i++)
                    if (rootItem.usageHistory[i].s !== undefined && rootItem.usageHistory[i].s !== null)
                        return true;
                return false;
            }
            if (tab === "openai") {
                for (var j = 0; j < rootItem.usageHistory.length; j++)
                    if (rootItem.usageHistory[j].cp !== undefined && rootItem.usageHistory[j].cp !== null)
                        return true;
            }
            return false;
        }
        Repeater {
            model: {
                var tab = rootItem.enabledTabs[rootItem.activeTab];
                if (tab === "openai")
                    return [
                        {
                            id: "codex_primary",
                            label: "5H"
                        },
                        {
                            id: "codex_weekly",
                            label: "7D"
                        }
                    ];
                return [
                    {
                        id: "session",
                        label: "5H"
                    },
                    {
                        id: "weekly",
                        label: "7D"
                    }
                ];
            }
            Rectangle {
                radius: 4
                implicitHeight: 16
                implicitWidth: winLabel.implicitWidth + 12
                color: rootItem.chartWindow === modelData.id ? rootItem.activeAccent : Qt.rgba(1, 1, 1, 0.06)
                opacity: rootItem.chartWindow === modelData.id ? 0.9 : 1.0
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                PlasmaComponents.Label {
                    id: winLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 9
                    font.bold: rootItem.chartWindow === modelData.id
                    color: rootItem.chartWindow === modelData.id ? "#ffffff" : Kirigami.Theme.textColor
                    opacity: rootItem.chartWindow === modelData.id ? 1.0 : 0.6
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        rootItem.chartWindow = modelData.id;
                        Plasmoid.configuration.chartWindow = modelData.id;
                    }
                }
            }
        }
    }

    // Y-axis labels. For most windows the axis is a 0-100% scale; for the mistral
    // (cost) window it's auto-scaled to the window's max spend, so labels show $.
    readonly property real chartMaxRaw: {
        if (rootItem.chartWindow !== "mistral")
            return 0;
        var pts = rootItem.weeklyUsageHistory;
        var m = 0;
        for (var i = 0; i < pts.length; i++)
            if (pts[i].raw !== undefined && pts[i].raw > m)
                m = pts[i].raw;
        return m;
    }
    function chartYLabel(fraction) {
        if (rootItem.chartWindow === "mistral")
            return chartMaxRaw > 0 ? "$" + (chartMaxRaw * fraction).toFixed(2) : "";
        return Math.round(fraction * 100) + "%";
    }
    PlasmaComponents.Label {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + 2
        text: usageChartContainer.chartYLabel(1.0)
        font.pixelSize: 9
        opacity: 0.35
        color: Kirigami.Theme.textColor
    }
    PlasmaComponents.Label {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + chartCanvas.height / 2 - 6
        text: usageChartContainer.chartYLabel(0.5)
        font.pixelSize: 9
        opacity: 0.35
        color: Kirigami.Theme.textColor
    }
    PlasmaComponents.Label {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + chartCanvas.height - 14
        text: usageChartContainer.chartYLabel(0.0)
        font.pixelSize: 9
        opacity: 0.35
        color: Kirigami.Theme.textColor
    }

    Canvas {
        id: chartCanvas
        anchors.top: parent.top
        anchors.bottom: xAxisRow.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 36
        anchors.rightMargin: 8
        anchors.topMargin: 28
        anchors.bottomMargin: 2

        property var history: rootItem.weeklyUsageHistory
        property color accentColor: rootItem.activeAccent
        // pulse phase 0..1, driven while usage is climbing fast; scales the latest dot's halo
        property real pulse: 0
        // hover-scrub index into history (-1 = none)
        property int scrubIndex: -1
        onHistoryChanged: requestPaint()
        onAccentColorChanged: requestPaint()
        onPulseChanged: requestPaint()
        onScrubIndexChanged: requestPaint()
        onVisibleChanged: if (visible)
            requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        // Pulse when the selected window is climbing >2%/h
        readonly property bool climbingFast: {
            var key = rootItem._historyKey();
            var slope = rootItem.usageSlopePerHour(key, 2 * 3600000);
            return slope !== null && slope > 2;
        }
        SequentialAnimation on pulse {
            running: chartCanvas.climbingFast && chartCanvas.visible
            loops: Animation.Infinite
            NumberAnimation {
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1
                to: 0
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
        onClimbingFastChanged: if (!climbingFast)
            pulse = 0

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var pts = history;
            if (!pts || pts.length < 1)
                return;

            var w = width, h = height;
            var now_ms = new Date().getTime();
            var maxT = now_ms - rootItem.chartTimeOffset;
            var minT = maxT - rootItem.getChartWindowSize();
            var tRange = rootItem.getChartWindowSize();

            function px(i) {
                return ((pts[i].t - minT) / tRange) * w;
            }
            // small top/bottom margin so the glow dot isn't clipped by the canvas edge
            function py(v) {
                return h - (v / 100) * h * 0.88 - h * 0.04;
            }

            // build rgba string from the QML color object (components are 0–1)
            var acR = Math.round(accentColor.r * 255);
            var acG = Math.round(accentColor.g * 255);
            var acB = Math.round(accentColor.b * 255);
            function acRgba(a) {
                return "rgba(" + acR + "," + acG + "," + acB + "," + a + ")";
            }

            // dashed grid lines at 25 / 50 / 75 / 100%
            ctx.save();
            ctx.setLineDash([3, 5]);
            ctx.strokeStyle = "rgba(255,255,255,0.08)";
            ctx.lineWidth = 1;
            [25, 50, 75, 100].forEach(function (pct) {
                var y = py(pct);
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
            });
            ctx.restore();

            if (pts.length === 1) {
                var sx = w / 2, sy = py(pts[0].v);
                ctx.beginPath();
                ctx.arc(sx, sy, 7, 0, Math.PI * 2);
                ctx.fillStyle = acRgba(0.18);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(sx, sy, 4, 0, Math.PI * 2);
                ctx.fillStyle = acRgba(1.0);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(sx, sy, 1.8, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(255,255,255,0.9)";
                ctx.fill();
                return;
            }

            // smooth cubic bezier path builder
            function buildPath() {
                ctx.moveTo(px(0), py(pts[0].v));
                for (var i = 0; i < pts.length - 1; i++) {
                    var x0 = px(i), y0 = py(pts[i].v);
                    var x1 = px(i + 1), y1 = py(pts[i + 1].v);
                    var cpx = x0 + (x1 - x0) * 0.5;
                    ctx.bezierCurveTo(cpx, y0, cpx, y1, x1, y1);
                }
            }

            // glow pass — wide soft stroke behind the crisp line (fast stroke-based glow instead of heavy CPU shadow blur)
            ctx.save();
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.beginPath();
            buildPath();
            ctx.strokeStyle = acRgba(0.08);
            ctx.lineWidth = 14;
            ctx.stroke();
            ctx.beginPath();
            buildPath();
            ctx.strokeStyle = acRgba(0.18);
            ctx.lineWidth = 8;
            ctx.stroke();
            ctx.beginPath();
            buildPath();
            ctx.strokeStyle = acRgba(0.40);
            ctx.lineWidth = 4;
            ctx.stroke();
            ctx.restore();

            // filled gradient area
            var grad = ctx.createLinearGradient(0, 0, 0, h);
            grad.addColorStop(0, acRgba(0.28));
            grad.addColorStop(0.6, acRgba(0.08));
            grad.addColorStop(1, acRgba(0.0));
            ctx.beginPath();
            buildPath();
            ctx.lineTo(px(pts.length - 1), h);
            ctx.lineTo(px(0), h);
            ctx.closePath();
            ctx.fillStyle = grad;
            ctx.fill();

            // crisp line on top
            ctx.beginPath();
            buildPath();
            ctx.strokeStyle = acRgba(1.0);
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();

            // latest point: pulsing halo + dot + white pip
            var lx = px(pts.length - 1);
            var ly = py(pts[pts.length - 1].v);
            // halo grows + fades with the pulse phase when climbing fast
            var haloR = 7 + pulse * 8;
            var haloA = 0.18 + (1 - pulse) * 0.10;
            ctx.beginPath();
            ctx.arc(lx, ly, haloR, 0, Math.PI * 2);
            ctx.fillStyle = acRgba(pulse > 0 ? haloA * (1 - pulse) + 0.06 : 0.18);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(lx, ly, 4, 0, Math.PI * 2);
            ctx.fillStyle = acRgba(1.0);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(lx, ly, 1.8, 0, Math.PI * 2);
            ctx.fillStyle = "rgba(255,255,255,0.9)";
            ctx.fill();

            // hover scrub: vertical guide + highlighted point
            if (scrubIndex >= 0 && scrubIndex < pts.length) {
                var hx = px(scrubIndex);
                var hy = py(pts[scrubIndex].v);
                ctx.save();
                ctx.setLineDash([2, 3]);
                ctx.strokeStyle = acRgba(0.5);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(hx, 0);
                ctx.lineTo(hx, h);
                ctx.stroke();
                ctx.restore();
                ctx.beginPath();
                ctx.arc(hx, hy, 5, 0, Math.PI * 2);
                ctx.fillStyle = acRgba(1.0);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(hx, hy, 2, 0, Math.PI * 2);
                ctx.fillStyle = "#ffffff";
                ctx.fill();
            }
        }

        // ── Hover scrub ──────────────────────────────────────
        MouseArea {
            id: scrubArea
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function (mouse) {
                var pts = chartCanvas.history;
                if (!pts || pts.length < 1) {
                    chartCanvas.scrubIndex = -1;
                    return;
                }
                // map mouse x → nearest point by timestamp (matches canvas px() formula)
                var now_ms = new Date().getTime();
                var maxT = now_ms - rootItem.chartTimeOffset;
                var tRange = rootItem.getChartWindowSize();
                var minT = maxT - tRange;
                var mouseT = minT + (mouse.x / chartCanvas.width) * tRange;
                var best = 0, bestDist = Math.abs(pts[0].t - mouseT);
                for (var i = 1; i < pts.length; i++) {
                    var d = Math.abs(pts[i].t - mouseT);
                    if (d < bestDist) {
                        bestDist = d;
                        best = i;
                    }
                }
                chartCanvas.scrubIndex = best;
            }
            onExited: chartCanvas.scrubIndex = -1

            // Custom tooltip positioned near the scrub dot
            Rectangle {
                id: scrubTooltip
                visible: chartCanvas.scrubIndex >= 0
                color: Qt.rgba(0, 0, 0, 0.72)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                radius: 6
                width: tooltipRow.implicitWidth + 14
                height: tooltipRow.implicitHeight + 8

                // Position above the dot, clamped to canvas bounds
                property real dotX: {
                    var pts = chartCanvas.history;
                    if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                        return 0;
                    var now_ms = new Date().getTime();
                    var maxT = now_ms - rootItem.chartTimeOffset;
                    var tRange = rootItem.getChartWindowSize();
                    return ((pts[chartCanvas.scrubIndex].t - (maxT - tRange)) / tRange) * chartCanvas.width;
                }
                property real dotY: {
                    var pts = chartCanvas.history;
                    if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                        return 0;
                    var v = pts[chartCanvas.scrubIndex].v;
                    var h = chartCanvas.height;
                    return h - (v / 100) * h * 0.88 - h * 0.04;
                }

                x: Math.max(0, Math.min(dotX - width / 2, chartCanvas.width - width - 4))
                y: Math.max(4, dotY - height - 8)

                Row {
                    id: tooltipRow
                    anchors.centerIn: parent
                    spacing: 0

                    PlasmaComponents.Label {
                        text: {
                            var pts = chartCanvas.history;
                            if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                                return "";
                            var pt = pts[chartCanvas.scrubIndex];
                            if (rootItem.chartWindow === "mistral")
                                return "$" + (pt.raw !== undefined ? pt.raw : 0).toFixed(4);
                            return Math.round(pt.v) + "%";
                        }
                        font.pixelSize: 11
                        font.bold: true
                        color: rootItem.activeAccent
                    }
                    PlasmaComponents.Label {
                        text: {
                            var pts = chartCanvas.history;
                            if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                                return "";
                            return "  ·  " + Qt.formatDateTime(new Date(pts[chartCanvas.scrubIndex].t), "MMM d, hh:mm");
                        }
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.75
                    }
                }
            }
        }
    }

    // X-axis date labels
    RowLayout {
        id: xAxisRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.rightMargin: 8
        anchors.bottomMargin: 5
        spacing: 0

        function formatLabel(timestamp) {
            if (rootItem.chartWindow === "session" || rootItem.chartWindow === "codex_primary") {
                return Qt.formatTime(new Date(timestamp), "hh:mm");
            }
            return Qt.formatDate(new Date(timestamp), "MMM d");
        }

        PlasmaComponents.Label {
            text: {
                var now_ms = new Date().getTime();
                var maxT = now_ms - rootItem.chartTimeOffset;
                var minT = maxT - rootItem.getChartWindowSize();
                return xAxisRow.formatLabel(minT);
            }
            font.pixelSize: 9
            opacity: 0.40
            color: Kirigami.Theme.textColor
        }
        Item {
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: {
                var now_ms = new Date().getTime();
                var maxT = now_ms - rootItem.chartTimeOffset;
                var winSize = rootItem.getChartWindowSize();
                var minT = maxT - winSize;
                return xAxisRow.formatLabel(minT + winSize / 2);
            }
            font.pixelSize: 9
            opacity: 0.40
            color: Kirigami.Theme.textColor
        }
        Item {
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: {
                var now_ms = new Date().getTime();
                var maxT = now_ms - rootItem.chartTimeOffset;
                return xAxisRow.formatLabel(maxT);
            }
            font.pixelSize: 9
            opacity: 0.40
            color: Kirigami.Theme.textColor
        }
    }
}
