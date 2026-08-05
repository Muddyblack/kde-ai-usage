import QtQuick
import QtQuick.Layouts
import "../package/contents/code/UsageHistory.js" as UsageHistory

// Usage-history chart, ported from the Plasma UsageChart. Self-contained:
// feed it the unified history array plus the window list for the active tab.
Rectangle {
    id: chart

    // Full unified history: [{t, s?, w?, cp?, cw?, kr?, ag?, or?, mv?, gr?, za?, gh?, ds?}]
    property var usageHistory: []
    // Chart ranges for the active tab, straight from the provider contract:
    // [{id, key, label, size, granularity, raw, resets}] (size in ms)
    property var windows: []
    property string chartWindow: ""
    property color accent: "#7dd3fc"
    property string currency: ""
    property real chartTimeOffset: 0
    // Gate from the host (settings toggle / settings page open) combined with
    // the "have at least one data point" check below.
    property bool extraVisible: true

    signal windowSelected(string id)

    onChartWindowChanged: chartTimeOffset = 0

    readonly property var currentWindow: {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].id === chartWindow)
                return windows[i];
        return windows.length > 0 ? windows[0] : null;
    }
    readonly property string historyKey: currentWindow ? currentWindow.key : "w"
    readonly property real windowSize: currentWindow ? currentWindow.size : 7 * 24 * 3600000
    // Money series (Mistral spend, DeepSeek balance) are absolute amounts the
    // chart auto-scales; rolling plan windows are the ones that drop at a reset.
    readonly property bool isCost: currentWindow ? currentWindow.raw === true : false
    readonly property bool windowHasResets: currentWindow ? currentWindow.resets === true : false

    // {t, v[, raw]} view of the selected series inside the visible window
    readonly property var series: {
        var out = [];
        var now_ms = new Date().getTime();
        var maxT = now_ms - chart.chartTimeOffset;
        var minT = maxT - chart.windowSize;
        for (var i = 0; i < usageHistory.length; i++) {
            var p = usageHistory[i];
            var v = p[chart.historyKey];
            if (v === undefined || v === null)
                continue;
            if (p.t >= minT && p.t <= maxT)
                out.push({
                    t: p.t,
                    v: v
                });
        }
        if (chart.windowHasResets && chart.currentWindow)
            out = UsageHistory.withResets(out, chart.currentWindow.resetAt * 1000, chart.currentWindow.periodMs, minT, maxT);
        if (chart.isCost && out.length > 0) {
            var maxV = 0;
            for (var j = 0; j < out.length; j++)
                if (out[j].v > maxV)
                    maxV = out[j].v;
            if (maxV > 0)
                for (var k = 0; k < out.length; k++)
                    out[k] = {
                        t: out[k].t,
                        v: (out[k].v / maxV) * 100,
                        raw: out[k].v
                    };
        }
        return out;
    }

    // True if the selected series has ANY point in the whole history (not just
    // inside the visible window). Used to keep the chart frame on screen while
    // paging back past the data, instead of vanishing and trapping the user.
    readonly property bool hasAnySeriesData: {
        for (var i = 0; i < usageHistory.length; i++) {
            var v = usageHistory[i][chart.historyKey];
            if (v !== undefined && v !== null)
                return true;
        }
        return false;
    }

    readonly property var resetTimestamps: {
        if (!windowHasResets)
            return [];
        var pts = chart.series;
        var out = [];
        for (var i = 1; i < pts.length; i++)
            if (pts[i - 1].v - pts[i].v > 6)
                out.push(pts[i].t);
        return out;
    }

    readonly property real chartMaxRaw: {
        if (!isCost)
            return 0;
        var pts = chart.series;
        var m = 0;
        for (var i = 0; i < pts.length; i++)
            if (pts[i].raw !== undefined && pts[i].raw > m)
                m = pts[i].raw;
        return m;
    }

    function chartYLabel(fraction) {
        if (isCost) {
            var symbol = currency === "CNY" ? "¥" : (currency === "USD" || historyKey === "mv" ? "$" : "");
            return chartMaxRaw > 0 ? symbol + (chartMaxRaw * fraction).toFixed(2) + (symbol === "" && currency !== "" ? " " + currency : "") : "";
        }
        return Math.round(fraction * 100) + "%";
    }

    function rangeText() {
        var now_ms = new Date().getTime();
        var maxT = now_ms - chartTimeOffset;
        var minT = maxT - windowSize;
        var minDate = new Date(minT);
        var maxDate = new Date(maxT);
        if (windowSize <= 24 * 3600000) {
            if (minDate.toDateString() === maxDate.toDateString())
                return Qt.formatDateTime(minDate, "hh:mm") + " - " + Qt.formatDateTime(maxDate, "hh:mm") + " (" + Qt.formatDateTime(maxDate, "MMM d") + ")";
            return Qt.formatDateTime(minDate, "MMM d, hh:mm") + " - " + Qt.formatDateTime(maxDate, "MMM d, hh:mm");
        }
        return Qt.formatDateTime(minDate, "MMM d") + " - " + Qt.formatDateTime(maxDate, "MMM d");
    }

    // Usage slope in %/hour over the trailing lookback, for the pulse effect.
    function usageSlopePerHour(lookbackMs) {
        var now_ms = new Date().getTime();
        var first = null, last = null;
        for (var i = 0; i < usageHistory.length; i++) {
            var p = usageHistory[i];
            var v = p[chart.historyKey];
            if (v === undefined || v === null)
                continue;
            if (p.t < now_ms - lookbackMs)
                continue;
            if (first === null)
                first = p;
            last = p;
        }
        if (first === null || last === null || last.t <= first.t)
            return null;
        var lv = last[chart.historyKey], fv = first[chart.historyKey];
        return (lv - fv) / ((last.t - first.t) / 3600000);
    }

    visible: extraVisible && hasAnySeriesData
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: 184
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.045)
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

        Rectangle {
            radius: 4
            implicitHeight: 16
            implicitWidth: 16
            color: leftNavMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            opacity: enabled ? 1.0 : 0.3
            enabled: {
                var oldestT = 0;
                for (var i = 0; i < chart.usageHistory.length; i++) {
                    var p = chart.usageHistory[i];
                    if (p[chart.historyKey] !== undefined && p[chart.historyKey] !== null) {
                        oldestT = p.t;
                        break;
                    }
                }
                if (oldestT === 0)
                    return false;
                var now_ms = new Date().getTime();
                var minT = (now_ms - chart.chartTimeOffset) - chart.windowSize;
                return minT > oldestT;
            }
            Text {
                anchors.centerIn: parent
                text: "<"
                font.pixelSize: 9
                font.bold: true
                color: "#f8fafc"
            }
            MouseArea {
                id: leftNavMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: chart.chartTimeOffset += chart.windowSize
            }
        }

        Text {
            text: chart.rangeText()
            font.pixelSize: 9
            font.bold: true
            opacity: 0.6
            color: "#f8fafc"
        }

        Rectangle {
            radius: 4
            implicitHeight: 16
            implicitWidth: 16
            color: rightNavMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            opacity: enabled ? 1.0 : 0.3
            enabled: chart.chartTimeOffset > 0
            Text {
                anchors.centerIn: parent
                text: ">"
                font.pixelSize: 9
                font.bold: true
                color: "#f8fafc"
            }
            MouseArea {
                id: rightNavMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: chart.chartTimeOffset = Math.max(0, chart.chartTimeOffset - chart.windowSize)
            }
        }
    }

    // ── Window toggle (5H / 24H / 7D) ──
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 8
        spacing: 4
        visible: chart.windows.length > 1

        Repeater {
            model: chart.windows

            Rectangle {
                required property var modelData
                radius: 4
                implicitHeight: 16
                implicitWidth: winLabel.implicitWidth + 12
                color: chart.chartWindow === modelData.id ? chart.accent : Qt.rgba(1, 1, 1, 0.06)
                opacity: chart.chartWindow === modelData.id ? 0.9 : 1.0
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Text {
                    id: winLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 9
                    font.bold: chart.chartWindow === modelData.id
                    color: chart.chartWindow === modelData.id ? "#ffffff" : "#f8fafc"
                    opacity: chart.chartWindow === modelData.id ? 1.0 : 0.6
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chart.windowSelected(modelData.id)
                }
            }
        }
    }

    // ── Y-axis labels ──
    Text {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + 2
        text: chart.chartYLabel(1.0)
        font.pixelSize: 9
        opacity: 0.35
        color: "#f8fafc"
    }
    Text {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + chartCanvas.height / 2 - 6
        text: chart.chartYLabel(0.5)
        font.pixelSize: 9
        opacity: 0.35
        color: "#f8fafc"
    }
    Text {
        anchors.right: chartCanvas.left
        anchors.rightMargin: 4
        y: chartCanvas.y + chartCanvas.height - 14
        text: chart.chartYLabel(0.0)
        font.pixelSize: 9
        opacity: 0.35
        color: "#f8fafc"
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

        property var history: chart.series
        property color accentColor: chart.accent
        property real pulse: 0
        property int scrubIndex: -1
        onHistoryChanged: requestPaint()
        onAccentColorChanged: requestPaint()
        onPulseChanged: requestPaint()
        onScrubIndexChanged: requestPaint()
        onVisibleChanged: if (visible)
            requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        readonly property bool climbingFast: {
            var slope = chart.usageSlopePerHour(2 * 3600000);
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
            var maxT = now_ms - chart.chartTimeOffset;
            var tRange = chart.windowSize;
            var minT = maxT - tRange;

            function px(i) {
                return ((pts[i].t - minT) / tRange) * w;
            }
            function py(v) {
                return h - (v / 100) * h * 0.88 - h * 0.04;
            }

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

            function buildPath() {
                ctx.moveTo(px(0), py(pts[0].v));
                for (var i = 0; i < pts.length - 1; i++) {
                    var x0 = px(i), y0 = py(pts[i].v);
                    var x1 = px(i + 1), y1 = py(pts[i + 1].v);
                    var cpx = x0 + (x1 - x0) * 0.5;
                    ctx.bezierCurveTo(cpx, y0, cpx, y1, x1, y1);
                }
            }

            // glow pass — wide soft strokes behind the crisp line
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

            // ── Reset-boundary markers ──
            function drawResetLine(resetMs, label, drawLabel) {
                var rx = ((resetMs - minT) / tRange) * w;
                ctx.save();
                ctx.setLineDash([2, 4]);
                ctx.strokeStyle = "rgba(255,255,255,0.22)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(rx, 12);
                ctx.lineTo(rx, h);
                ctx.stroke();
                ctx.restore();
                if (drawLabel) {
                    ctx.save();
                    ctx.font = "9px sans-serif";
                    ctx.fillStyle = "rgba(255,255,255,0.45)";
                    var tw = ctx.measureText(label).width;
                    var tx = Math.min(Math.max(rx + 3, 0), w - tw);
                    ctx.fillText(label, tx, 9);
                    ctx.restore();
                }
                ctx.save();
                ctx.beginPath();
                ctx.arc(rx, h, 2, 0, Math.PI * 2);
                ctx.fillStyle = acRgba(0.85);
                ctx.fill();
                ctx.restore();
            }
            var resets = chart.resetTimestamps;
            var resetLabel = chart.chartWindow.indexOf("weekly") >= 0 ? "week reset" : "5h reset";
            var labelDrawn = false;
            for (var ri = resets.length - 1; ri >= 0; ri--) {
                var rt = resets[ri];
                if (rt > minT && rt < maxT) {
                    drawResetLine(rt, resetLabel, !labelDrawn);
                    labelDrawn = true;
                }
            }

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

        // Empty-window hint: shown while paging back (or forward) into a range
        // that has no recorded points, so the chart keeps its frame + nav arrows
        // instead of disappearing.
        Text {
            anchors.centerIn: parent
            visible: chart.series.length === 0
            text: "No data in this range"
            color: "#94a3b8"
            font.pixelSize: 11
            opacity: 0.7
        }

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
                var now_ms = new Date().getTime();
                var maxT = now_ms - chart.chartTimeOffset;
                var tRange = chart.windowSize;
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

            Rectangle {
                id: scrubTooltip
                visible: chartCanvas.scrubIndex >= 0
                color: Qt.rgba(0, 0, 0, 0.72)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                radius: 6
                width: tooltipRow.implicitWidth + 14
                height: tooltipRow.implicitHeight + 8

                property real dotX: {
                    var pts = chartCanvas.history;
                    if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                        return 0;
                    var now_ms = new Date().getTime();
                    var maxT = now_ms - chart.chartTimeOffset;
                    var tRange = chart.windowSize;
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

                    Text {
                        text: {
                            var pts = chartCanvas.history;
                            if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                                return "";
                            var pt = pts[chartCanvas.scrubIndex];
                            if (chart.isCost) {
                                var value = (pt.raw !== undefined ? pt.raw : 0).toFixed(4);
                                if (chart.currency === "CNY")
                                    return "¥" + value;
                                if (chart.currency === "USD" || chart.historyKey === "mv")
                                    return "$" + value;
                                return value + (chart.currency !== "" ? " " + chart.currency : "");
                            }
                            return Math.round(pt.v) + "%";
                        }
                        font.pixelSize: 11
                        font.bold: true
                        color: chart.accent
                    }
                    Text {
                        text: {
                            var pts = chartCanvas.history;
                            if (chartCanvas.scrubIndex < 0 || !pts || chartCanvas.scrubIndex >= pts.length)
                                return "";
                            return "  ·  " + Qt.formatDateTime(new Date(pts[chartCanvas.scrubIndex].t), "MMM d, hh:mm");
                        }
                        font.pixelSize: 11
                        color: "#f8fafc"
                        opacity: 0.75
                    }
                }
            }
        }
    }

    // ── X-axis endpoint labels ──
    RowLayout {
        id: xAxisRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.rightMargin: 8
        anchors.bottomMargin: 5
        spacing: 0

        readonly property int tickCount: 2
        readonly property bool hourlyWindow: chart.windowSize <= 24 * 3600000

        function formatLabel(timestamp) {
            var d = new Date(timestamp);
            if (hourlyWindow)
                return Qt.formatTime(d, "hh:mm");
            return Qt.formatDate(d, "MMM d") + "\n" + Qt.formatTime(d, "hh:mm");
        }

        function endpointCrowded(endpointFrac) {
            var resets = chart.resetTimestamps;
            var now_ms = new Date().getTime();
            var minT = (now_ms - chart.chartTimeOffset) - chart.windowSize;
            for (var i = 0; i < resets.length; i++) {
                var f = (resets[i] - minT) / chart.windowSize;
                if (f > 0 && f < 1 && Math.abs(f - endpointFrac) < 0.1)
                    return true;
            }
            return false;
        }

        Repeater {
            model: xAxisRow.tickCount
            delegate: RowLayout {
                readonly property real frac: index / (xAxisRow.tickCount - 1)
                Layout.fillWidth: index > 0
                spacing: 0
                Item {
                    Layout.fillWidth: index > 0
                }
                Text {
                    visible: !xAxisRow.endpointCrowded(parent.frac)
                    text: {
                        var now_ms = new Date().getTime();
                        var maxT = now_ms - chart.chartTimeOffset;
                        var minT = maxT - chart.windowSize;
                        return xAxisRow.formatLabel(minT + chart.windowSize * parent.frac);
                    }
                    font.pixelSize: 9
                    opacity: 0.40
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.9
                    color: "#f8fafc"
                }
            }
        }
    }

    // Reset-time labels centered under each reset line
    Item {
        id: resetLabelsRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.rightMargin: 8
        anchors.bottomMargin: 5
        height: xAxisRow.height

        Repeater {
            model: chart.resetTimestamps
            delegate: Text {
                readonly property real frac: {
                    var now_ms = new Date().getTime();
                    var maxT = now_ms - chart.chartTimeOffset;
                    var minT = maxT - chart.windowSize;
                    return (modelData - minT) / chart.windowSize;
                }
                visible: frac > 0 && frac < 1
                text: chart.chartWindow.indexOf("weekly") >= 0 ? Qt.formatDate(new Date(modelData), "MMM d") : Qt.formatTime(new Date(modelData), "hh:mm")
                font.pixelSize: 9
                color: chart.accent
                opacity: 0.85
                x: Math.max(0, Math.min(frac * resetLabelsRow.width - implicitWidth / 2, resetLabelsRow.width - implicitWidth))
            }
        }
    }
}
