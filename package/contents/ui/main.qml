import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    toolTipMainText: "AI API Usage"
    toolTipSubText: {
        var lines = [];
        if (root.activeTab === 0) {
            var fCountdown = root.sessionCountdown === "resetting..." ? " · resetting..." : (root.sessionCountdown ? " (" + root.sessionCountdown + ")" : "");
            var sCountdown = root.weeklyCountdown === "resetting..." ? " · resetting..." : (root.weeklyCountdown ? " (" + root.weeklyCountdown + ")" : "");
            lines.push("Claude 5H: " + Math.round(root.sessionPct) + "%" + fCountdown);
            if (root.sessionTokenLimit > 0)
                lines.push("  " + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens");
            lines.push("Claude 7D: " + Math.round(root.weeklyPct) + "%" + sCountdown);
            if (root.claudeExtraTokens > 0)
                lines.push("Extra budget: " + root.formatTokens(root.claudeExtraTokens) + " tokens left");
            if (root.claudeExtraUsageEnabled && root.claudeExtraUsageLimit > 0)
                lines.push("Extra usage: " + root.claudeExtraUsageUsed.toFixed(2) + " / " + root.claudeExtraUsageLimit.toFixed(2) + " " + root.claudeExtraUsageCurrency);
            if (root.claudeTotalCostUSD > 0)
                lines.push("API Cost (30d): $" + root.claudeTotalCostUSD.toFixed(2));
        } else {
            lines.push("Gemini: " + Math.round(root.antigravityPct) + "%");
            if (root.antigravityPlanType)
                lines.push("Plan: " + root.antigravityPlanType);
            if (root.antigravityPromptCreditsMonthly > 0)
                lines.push("Credits: " + root.antigravityPromptCreditsAvailable + " / " + root.antigravityPromptCreditsMonthly);
            if (root.antigravityResetTime)
                lines.push("Resets: " + root.antigravityResetTime);
        }
        if (root.errorMsg !== "")
            lines.push("⚠ " + root.errorMsg);
        else if (root.lastUpdate !== "")
            lines.push("Updated " + root.lastUpdate + (root.stale ? " (stale)" : ""));
        return lines.join("\n");
    }

    // ── Tab: 0 = Claude, 1 = Antigravity/Gemini ──────────────────────────────
    property int activeTab: 0

    // ── Claude data ───────────────────────────────────────────────────────────
    property real sessionPct: 0
    property real sessionTokensUsed: 0
    property real sessionTokenLimit: 0
    property string sessionResetTime: ""
    property var sessionResetDate: null
    property string sessionCountdown: ""

    property real weeklyPct: 0
    property real weeklyTokensUsed: 0
    property real weeklyTokenLimit: 0
    property string weeklyResetTime: ""
    property var weeklyResetDate: null
    property string weeklyCountdown: ""

    property real claudeExtraTokens: 0   // extra budget tokens remaining if present

    property string claudeSubscriptionType: ""
    property string claudeRateLimitTier: ""
    property bool claudeExtraUsageEnabled: false
    property real claudeExtraUsageLimit: 0
    property real claudeExtraUsageUsed: 0
    property real claudeExtraUsagePct: 0
    property string claudeExtraUsageCurrency: "USD"

    property string _claudeToken: ""
    property string _claudeAdminToken: ""

    // Claude API cost tracking (30d)
    property var claudeModels: ({})
    property real claudeTotalCostUSD: 0
    property real claudeTotalInputTokens: 0
    property real claudeTotalOutputTokens: 0

    // ── Antigravity / Gemini data ─────────────────────────────────────────────
    property real antigravityPct: 0
    property string antigravityResetTime: ""
    property var antigravityResetDate: null
    property string antigravityCountdown: ""
    property string antigravityEmail: ""
    property string antigravityPlanType: ""
    property real antigravityPromptCreditsMonthly: 0
    property real antigravityPromptCreditsAvailable: 0

    property string _antigravityToken: ""
    property string _antigravityProjectId: ""

    // { modelId: { displayName, usedPct, resetTime, isExhausted } }
    property var antigravityModels: ({})

    // ── Common ────────────────────────────────────────────────────────────────
    property string errorMsg: ""
    property bool stale: false
    property string lastUpdate: ""
    property int backoffMs: 0

    // ── Colors ────────────────────────────────────────────────────────────────
    readonly property color claudeOrange: "#cc785c"
    readonly property color googleBlue: "#4285f4"
    readonly property color googleGreen: "#34a853"
    readonly property color sessionColor: "#e05252"
    readonly property color weeklyColor: "#f5a623"
    readonly property color warningColor: "#ffa64d"
    readonly property color dangerColor: "#ff4d4d"

    // ── Pricing (USD per million tokens) ─────────────────────────────────────
    readonly property var claudePricing: ({
            "claude-opus-4": {
                input: 15.0,
                output: 75.0
            },
            "claude-sonnet-4": {
                input: 3.0,
                output: 15.0
            },
            "claude-sonnet-3-5": {
                input: 3.0,
                output: 15.0
            },
            "claude-haiku-4": {
                input: 0.8,
                output: 4.0
            },
            "claude-haiku-3-5": {
                input: 0.8,
                output: 4.0
            },
            "claude-3-5-sonnet-20241022": {
                input: 3.0,
                output: 15.0
            },
            "claude-3-5-sonnet-20240620": {
                input: 3.0,
                output: 15.0
            },
            "claude-3-5-haiku-20241022": {
                input: 0.8,
                output: 4.0
            },
            "claude-3-opus-20240229": {
                input: 15.0,
                output: 75.0
            }
        })

    // ── Helpers ───────────────────────────────────────────────────────────────
    function formatTokens(n) {
        if (n >= 1000000)
            return (n / 1000000).toFixed(2) + "M";
        if (n >= 1000)
            return (n / 1000).toFixed(1) + "K";
        return Math.round(n).toString();
    }

    function formatCountdown(targetDate) {
        if (!targetDate)
            return "";
        var now = new Date();
        var diffMs = targetDate.getTime() - now.getTime();
        if (diffMs <= 0)
            return "resetting...";
        var totalMins = Math.floor(diffMs / 60000);
        var d = Math.floor(totalMins / 1440);
        var h = Math.floor((totalMins % 1440) / 60);
        var m = totalMins % 60;
        var parts = [];
        if (d > 0)
            parts.push(d + "d");
        if (h > 0 || d > 0)
            parts.push(h + "h");
        parts.push(m + "m");
        return parts.join(" ");
    }

    function updateCountdowns() {
        root.sessionCountdown = root.formatCountdown(root.sessionResetDate);
        root.weeklyCountdown = root.formatCountdown(root.weeklyResetDate);
        root.antigravityCountdown = root.formatCountdown(root.antigravityResetDate);
    }

    function usageColor(pct) {
        if (pct >= 90)
            return root.dangerColor;
        if (pct >= 70)
            return root.warningColor;
        return Kirigami.Theme.textColor;
    }

    // ── Credentials ──────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: credSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.activeTab !== 0)
                return;
            try {
                var creds = JSON.parse((data["stdout"] || "").trim());
                root._claudeToken = (creds.claudeAiOauth || {}).accessToken || "";
                root._claudeAdminToken = creds.claudeAdminApiKey || "";
                root.claudeSubscriptionType = (creds.claudeAiOauth || {}).subscriptionType || "";
                root.claudeRateLimitTier = (creds.claudeAiOauth || {}).rateLimitTier || "";
            } catch (_) {
                root._claudeToken = "";
                root._claudeAdminToken = "";
                root.claudeSubscriptionType = "";
                root.claudeRateLimitTier = "";
            }
            if (root._claudeToken) {
                fetchClaudeUsage();
                if (root._claudeAdminToken)
                    fetchClaudeApiUsage();
            } else if (root._claudeAdminToken) {
                root.sessionPct = 0;
                root.weeklyPct = 0;
                root.sessionTokenLimit = 0;
                root.weeklyTokenLimit = 0;
                fetchClaudeApiUsage();
                root.errorMsg = "OAuth missing — API stats only";
            } else {
                root.errorMsg = "Claude not logged in";
            }
        }
    }

    Plasma5Support.DataSource {
        id: antigravityUsageSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.activeTab !== 1)
                return;
            var output = (data["stdout"] || "").trim();
            if (!output) {
                root.errorMsg = "Antigravity not configured";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error) {
                    var cleanErr = res.error.split("\n")[0] || res.error;
                    if (cleanErr.indexOf("Antigravity is not running") !== -1) {
                        cleanErr = "Antigravity is not running in IDE";
                    }
                    root.errorMsg = cleanErr;
                    root.stale = true;
                    return;
                }

                root.antigravityEmail = res.email || "";

                // Parse prompt credits
                var credits = res.promptCredits || {};
                root.antigravityPromptCreditsMonthly = credits.monthly || 0;
                root.antigravityPromptCreditsAvailable = credits.available || 0;
                root.antigravityPlanType = res.planType || (res.method === "local" ? "LOCAL" : "CLOUD");

                // Parse models
                var modelsList = res.models || [];
                var newModels = {};
                var totalUsed = 0;
                var modelCount = 0;
                var earliestReset = null;

                for (var i = 0; i < modelsList.length; i++) {
                    var m = modelsList[i];
                    var remaining = m.remainingPercentage !== undefined ? m.remainingPercentage : -1;
                    var usedPct = remaining !== -1 ? Math.max(0, Math.min(100, (1.0 - remaining) * 100)) : 0;

                    newModels[m.modelId] = {
                        displayName: m.label || m.modelId,
                        usedPct: usedPct,
                        resetTime: m.resetTime || "",
                        isExhausted: !!m.isExhausted,
                        hasQuota: remaining !== -1
                    };

                    if (remaining !== -1) {
                        totalUsed += usedPct;
                        modelCount++;
                    }

                    if (m.resetTime) {
                        var rd = new Date(m.resetTime);
                        if (!isNaN(rd.getTime()) && (earliestReset === null || rd < earliestReset)) {
                            earliestReset = rd;
                        }
                    }
                }

                root.antigravityModels = newModels;
                root.antigravityPct = modelCount > 0 ? totalUsed / modelCount : 0;

                if (earliestReset) {
                    root.antigravityResetDate = earliestReset;
                    root.antigravityResetTime = Qt.formatDateTime(earliestReset, "MMM d, hh:mm");
                } else {
                    root.antigravityResetDate = null;
                    root.antigravityResetTime = "";
                }

                root.updateCountdowns();
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
            } catch (e) {
                console.log("Antigravity parse error: " + e);
                root.errorMsg = "parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    function loadCreds() {
        if (root.activeTab === 0) {
            var s = Qt.resolvedUrl("get_claude_credentials.sh").toString().replace("file://", "");
            var cmd = "bash " + s;
            credSource.disconnectSource(cmd);
            credSource.connectSource(cmd);
        } else {
            var s = Qt.resolvedUrl("get_antigravity_usage.sh").toString().replace("file://", "");
            var cmd = "bash " + s;
            antigravityUsageSource.disconnectSource(cmd);
            antigravityUsageSource.connectSource(cmd);
        }
    }

    // ── Claude usage ─────────────────────────────────────────────────────────
    function fetchClaudeUsage() {
        if (root.backoffMs > 0)
            return;
        var reqTab = root.activeTab;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.anthropic.com/api/oauth/usage");
        xhr.setRequestHeader("Authorization", "Bearer " + root._claudeToken);
        xhr.setRequestHeader("anthropic-beta", "oauth-2025-04-20");
        xhr.setRequestHeader("User-Agent", "claude-code/2.1.0");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (root.activeTab !== reqTab)
                return;
            if (xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    var f = d.five_hour || {};
                    var s = d.seven_day || {};

                    root.sessionPct = f.utilization || 0;
                    root.sessionTokensUsed = f.tokens_used || 0;
                    root.sessionTokenLimit = f.token_limit || 0;

                    root.weeklyPct = s.utilization || 0;
                    root.weeklyTokensUsed = s.tokens_used || 0;
                    root.weeklyTokenLimit = s.token_limit || 0;

                    // Extra budget (Max subscribers) — don't fall through on explicit 0
                    var extra = d.extra || d.extra_budget || {};
                    root.claudeExtraTokens = extra.tokens_remaining !== undefined ? extra.tokens_remaining : (extra.token_limit || 0);

                    // Parse extra_usage
                    var extraUsage = d.extra_usage || {};
                    root.claudeExtraUsageEnabled = !!extraUsage.is_enabled;
                    root.claudeExtraUsageLimit = extraUsage.monthly_limit || 0;
                    root.claudeExtraUsageUsed = extraUsage.used_credits || 0;
                    root.claudeExtraUsagePct = extraUsage.utilization || 0;
                    root.claudeExtraUsageCurrency = extraUsage.currency || "USD";

                    var fReset = new Date(f.resets_at || "");
                    root.sessionResetDate = !isNaN(fReset.getTime()) ? fReset : null;
                    root.sessionResetTime = !isNaN(fReset.getTime()) ? Qt.formatTime(fReset, "hh:mm") : "";

                    var sReset = new Date(s.resets_at || "");
                    root.weeklyResetDate = !isNaN(sReset.getTime()) ? sReset : null;
                    root.weeklyResetTime = !isNaN(sReset.getTime()) ? Qt.formatDateTime(sReset, "MMM d, hh:mm") : "";

                    root.updateCountdowns();
                    root.errorMsg = "";
                    root.stale = false;
                    root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                } catch (_) {
                    root.errorMsg = "parse error";
                    root.stale = root.lastUpdate !== "";
                }
            } else if (xhr.status === 429) {
                var retry = parseInt(xhr.getResponseHeader("retry-after") || "0");
                root.backoffMs = retry > 0 ? retry * 1000 : 300000;
                backoffTimer.interval = root.backoffMs;
                backoffTimer.restart();
                root.errorMsg = "rate limited";
                root.stale = root.lastUpdate !== "";
            } else if (xhr.status === 401) {
                root.errorMsg = "token expired";
                root.stale = root.lastUpdate !== "";
            } else {
                root.errorMsg = "err " + xhr.status;
                root.stale = root.lastUpdate !== "";
            }
        };
        xhr.send();
    }

    function fetchClaudeApiUsage() {
        if (root.backoffMs > 0 || !root._claudeAdminToken)
            return;
        var reqTab = root.activeTab;
        var endDate = new Date();
        var startDate = new Date();
        startDate.setDate(startDate.getDate() - 30);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.anthropic.com/v1/organization/usage?" + "start_date=" + startDate.toISOString().split('T')[0] + "&end_date=" + endDate.toISOString().split('T')[0]);
        xhr.setRequestHeader("x-api-key", root._claudeAdminToken);
        xhr.setRequestHeader("anthropic-version", "2023-06-01");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (root.activeTab !== reqTab)
                return;
            if (xhr.status !== 200)
                return;
            try {
                var d = JSON.parse(xhr.responseText);
                // Build a fresh object so QML reassignment notifies bindings.
                var models = {};
                var totalIn = 0;
                var totalOut = 0;
                var totalCost = 0;
                var usageData = d.data || [];
                for (var i = 0; i < usageData.length; i++) {
                    var entry = usageData[i];
                    var modelName = entry.model || "unknown";
                    var inTok = parseInt(entry.input_tokens || 0);
                    var outTok = parseInt(entry.output_tokens || 0);
                    if (!models[modelName])
                        models[modelName] = {
                            input_tokens: 0,
                            output_tokens: 0,
                            cost_usd: 0,
                            priced: false
                        };
                    models[modelName].input_tokens += inTok;
                    models[modelName].output_tokens += outTok;
                    var pricing = root.claudePricing[modelName];
                    if (pricing) {
                        models[modelName].cost_usd += (inTok / 1000000) * pricing.input + (outTok / 1000000) * pricing.output;
                        models[modelName].priced = true;
                    }
                    totalIn += inTok;
                    totalOut += outTok;
                }
                for (var m in models)
                    totalCost += models[m].cost_usd;
                root.claudeModels = models;
                root.claudeTotalInputTokens = totalIn;
                root.claudeTotalOutputTokens = totalOut;
                root.claudeTotalCostUSD = totalCost;
            } catch (e) {
                console.log("Claude API usage parse error: " + e);
            }
        };
        xhr.send();
    }

    function refresh() {
        loadCreds();
    }

    // ── Timers ────────────────────────────────────────────────────────────────
    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateCountdowns()
    }
    Timer {
        id: backoffTimer
        interval: 300000
        running: false
        repeat: false
        onTriggered: {
            root.backoffMs = 0;
            root.errorMsg = "";
            root.refresh();
        }
    }

    // ── Compact (panel) ───────────────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot

        implicitWidth: compactRow.implicitWidth + 18
        implicitHeight: Kirigami.Units.iconSizes.medium

        Layout.preferredWidth: implicitWidth
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumHeight: implicitHeight

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                radius: Math.min(height / 2, 8)
                color: compactMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 8

            // Error dot
            Rectangle {
                visible: root.errorMsg !== ""
                width: 6
                height: 6
                radius: 3
                color: root.dangerColor
                Layout.alignment: Qt.AlignVCenter
                SequentialAnimation on opacity {
                    running: root.errorMsg !== ""
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.3
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Claude 5H slot
            PanelSlot {
                pct: root.sessionPct
                iconColor: root.sessionColor
                stale: root.stale && root.activeTab === 0
                visible: root.activeTab === 0
                tooltipText: "Claude 5-hour: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) : "")
            }

            Rectangle {
                visible: root.activeTab === 0
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }

            // Claude 7D slot
            PanelSlot {
                pct: root.weeklyPct
                iconColor: root.weeklyColor
                stale: root.stale && root.activeTab === 0
                visible: root.activeTab === 0
                tooltipText: "Claude 7-day: " + Math.round(root.weeklyPct) + "%" + (root.weeklyTokenLimit > 0 ? "\n" + root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) : "")
            }

            // Antigravity slot
            PanelSlot {
                pct: root.antigravityPct
                iconColor: root.googleBlue
                stale: root.stale && root.activeTab === 1
                visible: root.activeTab === 1
                tooltipText: "Gemini quota: " + Math.round(root.antigravityPct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: popupRoot
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: mainColumn.implicitHeight + (Kirigami.Units.largeSpacing + 4) * 2
        Layout.preferredHeight: Layout.minimumHeight
        Layout.maximumHeight: Layout.minimumHeight

        ColumnLayout {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Kirigami.Units.largeSpacing + 4
            anchors.rightMargin: Kirigami.Units.largeSpacing + 4
            anchors.topMargin: Kirigami.Units.largeSpacing + 4
            spacing: Kirigami.Units.largeSpacing

            // ── Header ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    width: 22
                    height: 22
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        isMask: true
                        color: root.activeTab === 0 ? root.claudeOrange : root.googleBlue
                        opacity: 0.22
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        isMask: true
                        color: root.activeTab === 0 ? root.claudeOrange : root.googleBlue
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        text: "AI Usage Monitor"
                        font.bold: true
                        font.pixelSize: 15
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: root.activeTab === 0 ? "Claude API tracking" : "Gemini / Code Assist quota"
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: root.refresh()
                    opacity: hovered ? 1.0 : 0.6
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }

            // ── Tab bar ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        {
                            name: "Claude",
                            icon: root.claudeOrange
                        },
                        {
                            name: "Antigravity",
                            icon: root.googleBlue
                        }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 6
                        color: root.activeTab === index ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        border.width: 1
                        border.color: root.activeTab === index ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = index;
                                root.errorMsg = "";
                                root.refresh();
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.parent.radius
                                color: parent.containsMouse && root.activeTab !== index ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: modelData.icon
                                opacity: root.activeTab === index ? 1.0 : 0.5
                            }
                            PlasmaComponents.Label {
                                text: modelData.name
                                font.pixelSize: 12
                                font.bold: root.activeTab === index
                                color: Kirigami.Theme.textColor
                                opacity: root.activeTab === index ? 1.0 : 0.6
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // ── Claude tab ───────────────────────────────────────────────────
            ColumnLayout {
                visible: root.activeTab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Subscription info row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.claudeSubscriptionType !== ""

                    Kirigami.Icon {
                        source: "user-identity"
                        width: 14
                        height: 14
                        color: root.claudeOrange
                        isMask: true
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "Claude Code User"
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        height: 18
                        width: planLabelClaude.implicitWidth + 12
                        radius: 4
                        color: root.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.8, 0.47, 0.36, 0.18)
                        border.width: 1
                        border.color: root.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.8, 0.47, 0.36, 0.35)
                        PlasmaComponents.Label {
                            id: planLabelClaude
                            anchors.centerIn: parent
                            text: root.claudeSubscriptionType.toUpperCase()
                            font.pixelSize: 9
                            font.bold: true
                            color: root.claudeSubscriptionType === "free" ? Kirigami.Theme.textColor : root.claudeOrange
                        }
                    }
                }

                PopupRow {
                    label: "5 Hours"
                    resetText: root.sessionResetTime ? "resets " + root.sessionResetTime : ""
                    countdownText: root.sessionCountdown === "resetting..." ? "resetting..." : (root.sessionCountdown ? "in " + root.sessionCountdown : "")
                    value: root.sessionPct
                    barColor: root.sessionColor
                    tokenText: root.sessionTokenLimit > 0 ? root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens" : ""
                    tooltipText: "Claude 5-hour rolling window\nUsage: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens" : "") + (root.sessionResetTime ? "\nResets: " + root.sessionResetTime : "")
                }

                PopupRow {
                    label: "7 Days"
                    resetText: root.weeklyResetTime ? "resets " + root.weeklyResetTime : ""
                    countdownText: root.weeklyCountdown === "resetting..." ? "resetting..." : (root.weeklyCountdown ? "in " + root.weeklyCountdown : "")
                    value: root.weeklyPct
                    barColor: root.weeklyColor
                    tokenText: root.weeklyTokenLimit > 0 ? root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) + " tokens" : ""
                    tooltipText: "Claude 7-day rolling window\nUsage: " + Math.round(root.weeklyPct) + "%" + (root.weeklyTokenLimit > 0 ? "\n" + root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) + " tokens" : "") + (root.weeklyResetTime ? "\nResets: " + root.weeklyResetTime : "")
                }

                // Extra budget pill (Claude Max subscribers)
                Rectangle {
                    visible: root.claudeExtraTokens > 0
                    Layout.fillWidth: true
                    height: 30
                    radius: 6
                    color: Qt.rgba(0.8, 0.47, 0.36, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(0.8, 0.47, 0.36, 0.25)

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: root.claudeOrange
                        }
                        PlasmaComponents.Label {
                            text: "Extra budget"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.claudeOrange
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: root.formatTokens(root.claudeExtraTokens) + " tokens remaining"
                            font.pixelSize: 11
                            color: Kirigami.Theme.textColor
                            opacity: 0.8
                        }
                    }
                }

                // Extra usage (pay-as-you-go) credit spend if enabled
                PopupRow {
                    visible: root.claudeExtraUsageEnabled && root.claudeExtraUsageLimit > 0
                    label: "Extra Purchases"
                    value: root.claudeExtraUsagePct
                    barColor: root.claudeOrange
                    tokenText: root.claudeExtraUsageUsed.toFixed(2) + " / " + root.claudeExtraUsageLimit.toFixed(2) + " " + root.claudeExtraUsageCurrency + " used"
                    tooltipText: "Claude pay-as-you-go credit spend\nLimit: " + root.claudeExtraUsageLimit + " " + root.claudeExtraUsageCurrency
                }

                // API cost section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Object.keys(root.claudeModels).length > 0

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PlasmaComponents.Label {
                            text: "API Usage (30d)"
                            font.bold: true
                            font.pixelSize: 11
                            opacity: 0.7
                            color: Kirigami.Theme.textColor
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: "$" + root.claudeTotalCostUSD.toFixed(2)
                            font.bold: true
                            font.pixelSize: 13
                            color: root.claudeOrange
                        }
                    }

                    PlasmaComponents.Label {
                        text: root.formatTokens(root.claudeTotalInputTokens) + " in  ·  " + root.formatTokens(root.claudeTotalOutputTokens) + " out"
                        font.pixelSize: 9
                        opacity: 0.45
                        color: Kirigami.Theme.textColor
                    }

                    Repeater {
                        model: {
                            // Sort models by cost descending
                            var keys = Object.keys(root.claudeModels);
                            keys.sort(function (a, b) {
                                return root.claudeModels[b].cost_usd - root.claudeModels[a].cost_usd;
                            });
                            return keys;
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.text: {
                                    var m = root.claudeModels[modelData];
                                    if (!m)
                                        return modelData;
                                    return modelData + "\nInput:  " + root.formatTokens(m.input_tokens) + " tokens" + "\nOutput: " + root.formatTokens(m.output_tokens) + " tokens" + "\nCost:   " + (m.priced ? "$" + m.cost_usd.toFixed(4) : "unpriced");
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: modelData.replace(/claude-3-5-/g, "3.5-").replace(/claude-3-/g, "3-").replace(/claude-/g, "").replace(/-\d{8}$/, "")
                                    font.pixelSize: 10
                                    opacity: 0.65
                                    Layout.preferredWidth: 90
                                    elide: Text.ElideRight
                                    color: Kirigami.Theme.textColor
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: root.formatTokens(root.claudeModels[modelData].input_tokens) + " in"
                                    font.pixelSize: 9
                                    opacity: 0.4
                                    color: Kirigami.Theme.textColor
                                }
                                PlasmaComponents.Label {
                                    text: root.formatTokens(root.claudeModels[modelData].output_tokens) + " out"
                                    font.pixelSize: 9
                                    opacity: 0.4
                                    color: Kirigami.Theme.textColor
                                }
                                PlasmaComponents.Label {
                                    text: root.claudeModels[modelData].priced ? "$" + root.claudeModels[modelData].cost_usd.toFixed(3) : "—"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Kirigami.Theme.textColor
                                    opacity: root.claudeModels[modelData].priced ? 1.0 : 0.4
                                    Layout.preferredWidth: 52
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // mini cost bar
                            Item {
                                Layout.fillWidth: true
                                height: 3
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 1.5
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    radius: 1.5
                                    color: root.claudeOrange
                                    opacity: 0.7
                                    width: root.claudeTotalCostUSD > 0 ? parent.width * (root.claudeModels[modelData].cost_usd / root.claudeTotalCostUSD) : 0
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 500
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // ── Antigravity / Gemini tab ──────────────────────────────────────
            ColumnLayout {
                visible: root.activeTab === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // Account + plan info row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.antigravityEmail !== "" || root.antigravityPlanType !== ""

                    Kirigami.Icon {
                        source: "user-identity"
                        width: 14
                        height: 14
                        color: root.googleBlue
                        isMask: true
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: root.antigravityEmail || "Gemini Code Assist"
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: root.antigravityPlanType !== ""
                        height: 18
                        width: planLabel.implicitWidth + 12
                        radius: 4
                        color: root.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.26, 0.66, 0.33, 0.18)
                        border.width: 1
                        border.color: root.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.26, 0.66, 0.33, 0.35)
                        PlasmaComponents.Label {
                            id: planLabel
                            anchors.centerIn: parent
                            text: root.antigravityPlanType
                            font.pixelSize: 9
                            font.bold: true
                            color: root.antigravityPlanType === "Free" ? Kirigami.Theme.textColor : root.googleGreen
                        }
                    }
                }

                // Prompt credits bar (when plan has monthly credits)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.antigravityPromptCreditsMonthly > 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        PlasmaComponents.Label {
                            text: "Prompt Credits"
                            font.bold: true
                            font.pixelSize: 12
                            color: Kirigami.Theme.textColor
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: root.antigravityPromptCreditsAvailable + " / " + root.formatTokens(root.antigravityPromptCreditsMonthly) + " left"
                            font.pixelSize: 11
                            font.bold: true
                            color: {
                                var pct = root.antigravityPromptCreditsMonthly > 0 ? (1 - root.antigravityPromptCreditsAvailable / root.antigravityPromptCreditsMonthly) * 100 : 0;
                                return root.usageColor(pct);
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 8
                        Row {
                            anchors.fill: parent
                            spacing: 3
                            property int segCount: 20
                            Repeater {
                                model: 20
                                Rectangle {
                                    id: segRect
                                    property real usedPct: root.antigravityPromptCreditsMonthly > 0 ? (1 - root.antigravityPromptCreditsAvailable / root.antigravityPromptCreditsMonthly) * 100 : 0
                                    property real segThresh: (index + 1) * 5
                                    property real prevThresh: index * 5
                                    property real fillRatio: {
                                        if (usedPct >= segThresh)
                                            return 1.0;
                                        if (usedPct <= prevThresh)
                                            return 0.0;
                                        return (usedPct - prevThresh) / 5;
                                    }
                                    width: (parent.width - 19 * 3) / 20
                                    height: parent.height
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.10)
                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            bottom: parent.bottom
                                            margins: 1
                                        }
                                        width: Math.max(0, (parent.width - 2) * fillRatio)
                                        radius: 1.5
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop {
                                                position: 0.0
                                                color: Qt.lighter(root.usageColor(segRect.usedPct), 1.2)
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: root.usageColor(segRect.usedPct)
                                            }
                                        }
                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 500
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Overall quota bar (when no prompt credits, show average of models)
                PopupRow {
                    visible: root.antigravityPromptCreditsMonthly === 0 && Object.keys(root.antigravityModels).length > 0
                    label: "Overall Quota"
                    resetText: root.antigravityResetTime ? "resets " + root.antigravityResetTime : ""
                    countdownText: root.antigravityCountdown === "resetting..." ? "resetting..." : (root.antigravityCountdown ? "in " + root.antigravityCountdown : "")
                    value: root.antigravityPct
                    barColor: root.googleBlue
                    tooltipText: "Average quota usage across Gemini models\n" + Math.round(root.antigravityPct) + "% used" + (root.antigravityResetTime ? "\nResets: " + root.antigravityResetTime : "")
                }

                // Per-model breakdown
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: Object.keys(root.antigravityModels).length > 0

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    PlasmaComponents.Label {
                        text: "Model Quotas"
                        font.bold: true
                        font.pixelSize: 11
                        opacity: 0.7
                        color: Kirigami.Theme.textColor
                    }

                    Repeater {
                        model: Object.keys(root.antigravityModels).sort()

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.text: {
                                    var m = root.antigravityModels[modelData];
                                    var txt = (m.displayName || modelData) + "\n" + Math.round(m.usedPct) + "% used";
                                    if (m.isExhausted)
                                        txt += "\n⚠ Quota exhausted";
                                    if (m.resetTime)
                                        txt += "\nResets: " + Qt.formatDateTime(new Date(m.resetTime), "MMM d, hh:mm");
                                    return txt;
                                }
                            }

                            PlasmaComponents.Label {
                                text: root.antigravityModels[modelData].displayName || modelData
                                font.pixelSize: 10
                                color: root.antigravityModels[modelData].isExhausted ? root.dangerColor : Kirigami.Theme.textColor
                                opacity: root.antigravityModels[modelData].isExhausted ? 1.0 : 0.65
                                Layout.preferredWidth: 120
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.10)

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        bottom: parent.bottom
                                        margins: 1
                                    }
                                    width: Math.max(0, (parent.width - 2) * (root.antigravityModels[modelData].usedPct / 100))
                                    radius: 2
                                    color: root.antigravityModels[modelData].isExhausted ? root.dangerColor : root.antigravityModels[modelData].usedPct >= 70 ? root.warningColor : root.googleBlue
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 500
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            PlasmaComponents.Label {
                                text: root.antigravityModels[modelData].isExhausted ? "100%" : Math.round(root.antigravityModels[modelData].usedPct) + "%"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.usageColor(root.antigravityModels[modelData].usedPct)
                                Layout.preferredWidth: 35
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // Reset countdown row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.antigravityResetTime !== "" && root.antigravityPromptCreditsMonthly > 0

                    Kirigami.Icon {
                        source: "appointment-soon"
                        width: 12
                        height: 12
                        isMask: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.4
                    }
                    PlasmaComponents.Label {
                        text: "Resets " + root.antigravityResetTime + (root.antigravityCountdown && root.antigravityCountdown !== "resetting..." ? "  (" + root.antigravityCountdown + ")" : "")
                        font.pixelSize: 10
                        opacity: 0.45
                        color: Kirigami.Theme.textColor
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // ── Footer ─────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    visible: root.errorMsg !== ""
                    width: 6
                    height: 6
                    radius: 3
                    color: root.dangerColor
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents.Label {
                    visible: root.errorMsg !== ""
                    text: root.errorMsg
                    color: root.dangerColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    visible: root.lastUpdate !== "" && root.errorMsg === ""
                    text: "updated " + root.lastUpdate + (root.stale ? " · stale" : "")
                    opacity: 0.45
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ── PanelSlot component ───────────────────────────────────────────────────
    component PanelSlot: RowLayout {
        id: slot
        property real pct: 0
        property color iconColor: "#cc785c"
        property bool stale: false
        property string tooltipText: ""

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
            text: Math.round(slot.pct) + "%"
            font.pixelSize: 12
            font.bold: true
            color: slot.pct >= 90 ? root.dangerColor : slot.pct >= 70 ? root.warningColor : Kirigami.Theme.textColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ── PopupRow component ────────────────────────────────────────────────────
    component PopupRow: ColumnLayout {
        id: row
        property string label: ""
        property string resetText: ""
        property string countdownText: ""
        property real value: 0
        property color barColor: Kirigami.Theme.positiveTextColor
        property string tooltipText: ""
        property string tokenText: ""   // e.g. "123K / 274K tokens"

        readonly property int segmentCount: 20

        Layout.fillWidth: true
        spacing: 5

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            QQC2.ToolTip.visible: containsMouse && row.tooltipText !== ""
            QQC2.ToolTip.text: row.tooltipText
            QQC2.ToolTip.delay: 500
        }

        // Label + reset + countdown + percentage
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            PlasmaComponents.Label {
                text: row.label
                font.bold: true
                font.pixelSize: 13
                color: Kirigami.Theme.textColor
            }
            PlasmaComponents.Label {
                visible: row.resetText !== ""
                text: "· " + row.resetText
                font.pixelSize: 11
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                visible: row.countdownText !== ""
                height: 20
                width: cdLabel.implicitWidth + 14
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Layout.alignment: Qt.AlignVCenter
                PlasmaComponents.Label {
                    id: cdLabel
                    anchors.centerIn: parent
                    text: row.countdownText
                    font.pixelSize: 11
                    color: Kirigami.Theme.textColor
                    opacity: 0.8
                }
            }
            Item {
                width: 2
            }
            PlasmaComponents.Label {
                text: Math.round(row.value) + "%"
                font.bold: true
                font.pixelSize: 14
                color: row.value >= 90 ? root.dangerColor : row.value >= 70 ? root.warningColor : row.barColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Segmented progress bar
        Item {
            Layout.fillWidth: true
            height: 8

            Row {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: row.segmentCount

                    Rectangle {
                        width: (row.width - (row.segmentCount - 1) * 3) / row.segmentCount
                        height: parent.height
                        radius: 2

                        readonly property real segThresh: (index + 1) * (100 / row.segmentCount)
                        readonly property real prevThresh: index * (100 / row.segmentCount)
                        readonly property real fillRatio: {
                            if (row.value >= segThresh)
                                return 1.0;
                            if (row.value <= prevThresh)
                                return 0.0;
                            return (row.value - prevThresh) / (100 / row.segmentCount);
                        }

                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                margins: 1
                            }
                            width: Math.max(0, (parent.width - 2) * parent.fillRatio)
                            radius: 1.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.lighter(row.barColor, 1.15)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: row.barColor
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }

        // Token count subtext
        PlasmaComponents.Label {
            visible: row.tokenText !== ""
            text: row.tokenText
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
            Layout.topMargin: -2
        }
    }
}
