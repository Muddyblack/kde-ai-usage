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
        var tab = root.enabledTabs[root.activeTab];
        if (tab === "claude") {
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
        } else if (tab === "antigravity") {
            lines.push("Gemini: " + Math.round(root.antigravityPct) + "%");
            if (root.antigravityPlanType)
                lines.push("Plan: " + root.antigravityPlanType);
            if (root.antigravityPromptCreditsMonthly > 0)
                lines.push("Credits: " + root.antigravityPromptCreditsAvailable + " / " + root.antigravityPromptCreditsMonthly);
            if (root.antigravityResetTime)
                lines.push("Resets: " + root.antigravityResetTime);
        } else if (tab === "openai") {
            if (root.openaiTotalCostUSD > 0)
                lines.push("OpenAI Cost (30d): $" + root.openaiTotalCostUSD.toFixed(2));
            lines.push("In: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens));
        }
        if (root.errorMsg !== "")
            lines.push("⚠ " + root.errorMsg);
        else if (root.lastUpdate !== "")
            lines.push("Updated " + root.lastUpdate + (root.stale ? " (stale)" : ""));
        return lines.join("\n");
    }

    // ── Settings: which tabs are enabled ─────────────────────────────────────
    property bool claudeEnabled: true
    property bool antigravityEnabled: true
    property bool openaiEnabled: true

    // Computed list of enabled tab IDs in display order
    property var enabledTabs: {
        var t = [];
        if (root.claudeEnabled)
            t.push("claude");
        if (root.antigravityEnabled)
            t.push("antigravity");
        if (root.openaiEnabled)
            t.push("openai");
        return t;
    }

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

    property real claudeExtraTokens: 0

    property string claudeSubscriptionType: ""
    property string claudeRateLimitTier: ""
    property bool claudeExtraUsageEnabled: false
    property real claudeExtraUsageLimit: 0
    property real claudeExtraUsageUsed: 0
    property real claudeExtraUsagePct: 0
    property string claudeExtraUsageCurrency: "USD"

    property string _claudeToken: ""
    property string _claudeAdminToken: ""

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

    property var antigravityModels: ({})

    // ── OpenAI data ───────────────────────────────────────────────────────────
    property string _openaiApiKey: ""
    property var openaiModels: ({})
    property real openaiTotalCostUSD: 0
    property real openaiTotalInputTokens: 0
    property real openaiTotalOutputTokens: 0

    // ── Common ────────────────────────────────────────────────────────────────
    property string errorMsg: ""
    property bool stale: false
    property string lastUpdate: ""
    property int backoffMs: 0

    // ── Colors ────────────────────────────────────────────────────────────────
    readonly property color claudeOrange: "#cc785c"
    readonly property color googleBlue: "#4285f4"
    readonly property color googleGreen: "#34a853"
    readonly property color openaiGreen: "#10a37f"
    readonly property color sessionColor: "#e05252"
    readonly property color weeklyColor: "#f5a623"
    readonly property color warningColor: "#ffa64d"
    readonly property color dangerColor: "#ff4d4d"

    function tabColor(tabId) {
        if (tabId === "claude")
            return root.claudeOrange;
        if (tabId === "antigravity")
            return root.googleBlue;
        if (tabId === "openai")
            return root.openaiGreen;
        return Kirigami.Theme.textColor;
    }

    function tabName(tabId) {
        if (tabId === "claude")
            return "Claude";
        if (tabId === "antigravity")
            return "Antigravity";
        if (tabId === "openai")
            return "OpenAI";
        return tabId;
    }

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

    readonly property var openaiPricing: ({
            // GPT-4o family
            "gpt-4o": {
                input: 2.5,
                output: 10.0
            },
            "gpt-4o-2024-11-20": {
                input: 2.5,
                output: 10.0
            },
            "gpt-4o-2024-08-06": {
                input: 2.5,
                output: 10.0
            },
            "gpt-4o-mini": {
                input: 0.15,
                output: 0.6
            },
            "gpt-4o-mini-2024-07-18": {
                input: 0.15,
                output: 0.6
            },
            // o1 / o3 reasoning family
            "o1": {
                input: 15.0,
                output: 60.0
            },
            "o1-2024-12-17": {
                input: 15.0,
                output: 60.0
            },
            "o1-mini": {
                input: 1.1,
                output: 4.4
            },
            "o1-mini-2024-09-12": {
                input: 1.1,
                output: 4.4
            },
            "o3": {
                input: 10.0,
                output: 40.0
            },
            "o3-mini": {
                input: 1.1,
                output: 4.4
            },
            "o4-mini": {
                input: 1.1,
                output: 4.4
            },
            // GPT-4 Turbo / legacy
            "gpt-4-turbo": {
                input: 10.0,
                output: 30.0
            },
            "gpt-4-turbo-2024-04-09": {
                input: 10.0,
                output: 30.0
            },
            "gpt-4": {
                input: 30.0,
                output: 60.0
            },
            "gpt-4-32k": {
                input: 60.0,
                output: 120.0
            },
            // GPT-3.5
            "gpt-3.5-turbo": {
                input: 0.5,
                output: 1.5
            },
            "gpt-3.5-turbo-0125": {
                input: 0.5,
                output: 1.5
            },
            // Codex / embeddings (no output tokens)
            "text-embedding-3-small": {
                input: 0.02,
                output: 0.0
            },
            "text-embedding-3-large": {
                input: 0.13,
                output: 0.0
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

    function shortenModelName(name) {
        return name.replace(/gpt-4o-mini/g, "4o-mini").replace(/gpt-4o/g, "4o").replace(/gpt-4-turbo/g, "4-turbo").replace(/gpt-4-32k/g, "4-32k").replace(/gpt-4/g, "4").replace(/gpt-3\.5-turbo/g, "3.5-turbo").replace(/o1-mini/g, "o1-mini").replace(/o3-mini/g, "o3-mini").replace(/o4-mini/g, "o4-mini").replace(/claude-3-5-/g, "3.5-").replace(/claude-3-/g, "3-").replace(/claude-/g, "").replace(/-\d{8}$/, "").replace(/-20\d{2}-\d{2}-\d{2}$/, "");
    }

    // ── Credentials ──────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: credSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "claude")
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
            if (root.enabledTabs[root.activeTab] !== "antigravity")
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
                    if (cleanErr.indexOf("Antigravity is not running") !== -1)
                        cleanErr = "Antigravity is not running in IDE";
                    root.errorMsg = cleanErr;
                    root.stale = true;
                    return;
                }
                root.antigravityEmail = res.email || "";
                var credits = res.promptCredits || {};
                root.antigravityPromptCreditsMonthly = credits.monthly || 0;
                root.antigravityPromptCreditsAvailable = credits.available || 0;
                root.antigravityPlanType = res.planType || (res.method === "local" ? "LOCAL" : "CLOUD");
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
                        if (!isNaN(rd.getTime()) && (earliestReset === null || rd < earliestReset))
                            earliestReset = rd;
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

    Plasma5Support.DataSource {
        id: openaiCredSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "openai")
                return;
            try {
                var creds = JSON.parse((data["stdout"] || "").trim());
                root._openaiApiKey = creds.openaiApiKey || "";
            } catch (_) {
                root._openaiApiKey = "";
            }
            if (root._openaiApiKey) {
                fetchOpenAIUsage();
            } else {
                root.errorMsg = "OpenAI API key not configured";
            }
        }
    }

    function loadCreds() {
        var tab = root.enabledTabs[root.activeTab];
        if (tab === "claude") {
            var s = Qt.resolvedUrl("get_claude_credentials.sh").toString().replace("file://", "");
            credSource.disconnectSource("bash " + s);
            credSource.connectSource("bash " + s);
        } else if (tab === "antigravity") {
            var s = Qt.resolvedUrl("get_antigravity_usage.sh").toString().replace("file://", "");
            antigravityUsageSource.disconnectSource("bash " + s);
            antigravityUsageSource.connectSource("bash " + s);
        } else if (tab === "openai") {
            var s = Qt.resolvedUrl("get_openai_usage.sh").toString().replace("file://", "");
            openaiCredSource.disconnectSource("bash " + s);
            openaiCredSource.connectSource("bash " + s);
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
                    var extra = d.extra || d.extra_budget || {};
                    root.claudeExtraTokens = extra.tokens_remaining !== undefined ? extra.tokens_remaining : (extra.token_limit || 0);
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
                var models = {};
                var totalIn = 0, totalOut = 0, totalCost = 0;
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

    // ── OpenAI usage ──────────────────────────────────────────────────────────
    function fetchOpenAIUsage() {
        if (!root._openaiApiKey)
            return;
        var reqTab = root.activeTab;
        var endDate = new Date();
        var startDate = new Date();
        startDate.setDate(startDate.getDate() - 30);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.openai.com/v1/organization/usage/completions?" + "start_time=" + Math.floor(startDate.getTime() / 1000) + "&end_time=" + Math.floor(endDate.getTime() / 1000) + "&group_by=model&limit=100");
        xhr.setRequestHeader("Authorization", "Bearer " + root._openaiApiKey);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (root.activeTab !== reqTab)
                return;
            if (xhr.status === 401) {
                root.errorMsg = "OpenAI key invalid";
                root.stale = root.lastUpdate !== "";
                return;
            }
            if (xhr.status !== 200) {
                root.errorMsg = "OpenAI err " + xhr.status;
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var d = JSON.parse(xhr.responseText);
                var models = {};
                var totalIn = 0, totalOut = 0, totalCost = 0;
                var buckets = d.data || [];
                for (var i = 0; i < buckets.length; i++) {
                    var bucket = buckets[i];
                    var results = bucket.results || [];
                    for (var j = 0; j < results.length; j++) {
                        var entry = results[j];
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
                        var pricing = root.openaiPricing[modelName];
                        if (pricing) {
                            models[modelName].cost_usd += (inTok / 1000000) * pricing.input + (outTok / 1000000) * pricing.output;
                            models[modelName].priced = true;
                        }
                        totalIn += inTok;
                        totalOut += outTok;
                    }
                }
                for (var m in models)
                    totalCost += models[m].cost_usd;
                root.openaiModels = models;
                root.openaiTotalInputTokens = totalIn;
                root.openaiTotalOutputTokens = totalOut;
                root.openaiTotalCostUSD = totalCost;
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
            } catch (e) {
                console.log("OpenAI usage parse error: " + e);
                root.errorMsg = "parse error";
                root.stale = root.lastUpdate !== "";
            }
        };
        xhr.send();
    }

    function refresh() {
        if (root.enabledTabs.length === 0)
            return;
        if (root.activeTab >= root.enabledTabs.length)
            root.activeTab = 0;
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

            PanelSlot {
                pct: root.sessionPct
                iconColor: root.sessionColor
                stale: root.stale && root.enabledTabs[root.activeTab] === "claude"
                visible: root.enabledTabs[root.activeTab] === "claude"
                tooltipText: "Claude 5-hour: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) : "")
            }
            Rectangle {
                visible: root.enabledTabs[root.activeTab] === "claude"
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }
            PanelSlot {
                pct: root.weeklyPct
                iconColor: root.weeklyColor
                stale: root.stale && root.enabledTabs[root.activeTab] === "claude"
                visible: root.enabledTabs[root.activeTab] === "claude"
                tooltipText: "Claude 7-day: " + Math.round(root.weeklyPct) + "%" + (root.weeklyTokenLimit > 0 ? "\n" + root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) : "")
            }

            PanelSlot {
                pct: root.antigravityPct
                iconColor: root.googleBlue
                stale: root.stale && root.enabledTabs[root.activeTab] === "antigravity"
                visible: root.enabledTabs[root.activeTab] === "antigravity"
                tooltipText: "Gemini quota: " + Math.round(root.antigravityPct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }

            PanelSlot {
                pct: root.openaiTotalCostUSD > 0 ? Math.min(100, (root.openaiTotalCostUSD / 10) * 100) : 0
                iconColor: root.openaiGreen
                stale: root.stale && root.enabledTabs[root.activeTab] === "openai"
                visible: root.enabledTabs[root.activeTab] === "openai"
                showCost: true
                costText: root.openaiTotalCostUSD > 0 ? "$" + root.openaiTotalCostUSD.toFixed(2) : "—"
                tooltipText: "OpenAI API (30d)\nCost: $" + root.openaiTotalCostUSD.toFixed(2) + "\nIn: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens)
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
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
                        opacity: 0.22
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        isMask: true
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
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
                        text: {
                            var tab = root.enabledTabs[root.activeTab];
                            if (tab === "claude")
                                return "Claude API tracking";
                            if (tab === "antigravity")
                                return "Gemini / Code Assist quota";
                            if (tab === "openai")
                                return "OpenAI API usage";
                            return "";
                        }
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    checkable: true
                    checked: settingsPanel.visible
                    onClicked: settingsPanel.visible = !settingsPanel.visible
                    opacity: hovered || checked ? 1.0 : 0.6
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
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

            // ── Settings panel ───────────────────────────────────────────────
            Rectangle {
                id: settingsPanel
                visible: false
                Layout.fillWidth: true
                height: settingsCol.implicitHeight + 16
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                ColumnLayout {
                    id: settingsCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }
                    spacing: 6

                    PlasmaComponents.Label {
                        text: "Enabled services"
                        font.pixelSize: 10
                        font.bold: true
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                    }

                    Repeater {
                        model: [
                            {
                                id: "claude",
                                label: "Claude",
                                color: root.claudeOrange,
                                get: function () {
                                    return root.claudeEnabled;
                                },
                                set: function (v) {
                                    root.claudeEnabled = v;
                                }
                            },
                            {
                                id: "antigravity",
                                label: "Antigravity",
                                color: root.googleBlue,
                                get: function () {
                                    return root.antigravityEnabled;
                                },
                                set: function (v) {
                                    root.antigravityEnabled = v;
                                }
                            },
                            {
                                id: "openai",
                                label: "OpenAI",
                                color: root.openaiGreen,
                                get: function () {
                                    return root.openaiEnabled;
                                },
                                set: function (v) {
                                    root.openaiEnabled = v;
                                }
                            }
                        ]

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: modelData.color
                                opacity: modelData.get() ? 1.0 : 0.3
                                Layout.alignment: Qt.AlignVCenter
                            }
                            PlasmaComponents.Label {
                                text: modelData.label
                                font.pixelSize: 12
                                color: Kirigami.Theme.textColor
                                opacity: modelData.get() ? 1.0 : 0.45
                                Layout.fillWidth: true
                            }
                            QQC2.Switch {
                                checked: modelData.get()
                                onToggled: {
                                    // Prevent disabling the last enabled tab
                                    var enabled = [root.claudeEnabled, root.antigravityEnabled, root.openaiEnabled];
                                    var count = enabled.filter(function (x) {
                                        return x;
                                    }).length;
                                    if (!checked && count <= 1) {
                                        checked = true;
                                        return;
                                    }
                                    modelData.set(checked);
                                    // Clamp activeTab if needed
                                    if (root.activeTab >= root.enabledTabs.length)
                                        root.activeTab = Math.max(0, root.enabledTabs.length - 1);
                                    root.errorMsg = "";
                                    root.refresh();
                                }
                            }
                        }
                    }
                }
            }

            // ── Tab bar ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.enabledTabs.length > 1

                Repeater {
                    model: root.enabledTabs

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
                                color: root.tabColor(modelData)
                                opacity: root.activeTab === index ? 1.0 : 0.5
                            }
                            PlasmaComponents.Label {
                                text: root.tabName(modelData)
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
                visible: root.enabledTabs[root.activeTab] === "claude"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

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

                PopupRow {
                    visible: root.claudeExtraUsageEnabled && root.claudeExtraUsageLimit > 0
                    label: "Extra Purchases"
                    value: root.claudeExtraUsagePct
                    barColor: root.claudeOrange
                    tokenText: root.claudeExtraUsageUsed.toFixed(2) + " / " + root.claudeExtraUsageLimit.toFixed(2) + " " + root.claudeExtraUsageCurrency + " used"
                    tooltipText: "Claude pay-as-you-go credit spend\nLimit: " + root.claudeExtraUsageLimit + " " + root.claudeExtraUsageCurrency
                }

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
                                    return modelData + "\nInput:  " + root.formatTokens(m.input_tokens) + " tokens\nOutput: " + root.formatTokens(m.output_tokens) + " tokens\nCost:   " + (m.priced ? "$" + m.cost_usd.toFixed(4) : "unpriced");
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: root.shortenModelName(modelData)
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
                visible: root.enabledTabs[root.activeTab] === "antigravity"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

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

                PopupRow {
                    visible: root.antigravityPromptCreditsMonthly === 0 && Object.keys(root.antigravityModels).length > 0
                    label: "Overall Quota"
                    resetText: root.antigravityResetTime ? "resets " + root.antigravityResetTime : ""
                    countdownText: root.antigravityCountdown === "resetting..." ? "resetting..." : (root.antigravityCountdown ? "in " + root.antigravityCountdown : "")
                    value: root.antigravityPct
                    barColor: root.googleBlue
                    tooltipText: "Average quota usage across Gemini models\n" + Math.round(root.antigravityPct) + "% used" + (root.antigravityResetTime ? "\nResets: " + root.antigravityResetTime : "")
                }

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

            // ── OpenAI tab ────────────────────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "openai"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Header cost row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.openaiTotalCostUSD > 0 || Object.keys(root.openaiModels).length > 0

                    Kirigami.Icon {
                        source: "user-identity"
                        width: 14
                        height: 14
                        color: root.openaiGreen
                        isMask: true
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "OpenAI API"
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        height: 18
                        width: openaiPlanLabel.implicitWidth + 12
                        radius: 4
                        color: Qt.rgba(0.063, 0.639, 0.498, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(0.063, 0.639, 0.498, 0.35)
                        PlasmaComponents.Label {
                            id: openaiPlanLabel
                            anchors.centerIn: parent
                            text: "API"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.openaiGreen
                        }
                    }
                }

                // No key configured
                ColumnLayout {
                    visible: root._openaiApiKey === "" && root.errorMsg !== ""
                    Layout.fillWidth: true
                    spacing: 6
                    PlasmaComponents.Label {
                        text: "Configure OpenAI API key:"
                        font.pixelSize: 11
                        opacity: 0.7
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: "• Set OPENAI_API_KEY env var\n• Or save key to ~/.config/openai-api-key\n• Or save key to ~/.openai/api-key"
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                    }
                }

                // Cost summary
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Object.keys(root.openaiModels).length > 0

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
                            text: "$" + root.openaiTotalCostUSD.toFixed(2)
                            font.bold: true
                            font.pixelSize: 13
                            color: root.openaiGreen
                        }
                    }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.openaiTotalInputTokens) + " in  ·  " + root.formatTokens(root.openaiTotalOutputTokens) + " out"
                        font.pixelSize: 9
                        opacity: 0.45
                        color: Kirigami.Theme.textColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Repeater {
                        model: {
                            var keys = Object.keys(root.openaiModels);
                            keys.sort(function (a, b) {
                                return root.openaiModels[b].cost_usd - root.openaiModels[a].cost_usd;
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
                                    var m = root.openaiModels[modelData];
                                    if (!m)
                                        return modelData;
                                    return modelData + "\nInput:  " + root.formatTokens(m.input_tokens) + " tokens\nOutput: " + root.formatTokens(m.output_tokens) + " tokens\nCost:   " + (m.priced ? "$" + m.cost_usd.toFixed(4) : "unpriced");
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: root.shortenModelName(modelData)
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
                                    text: root.formatTokens(root.openaiModels[modelData].input_tokens) + " in"
                                    font.pixelSize: 9
                                    opacity: 0.4
                                    color: Kirigami.Theme.textColor
                                }
                                PlasmaComponents.Label {
                                    text: root.formatTokens(root.openaiModels[modelData].output_tokens) + " out"
                                    font.pixelSize: 9
                                    opacity: 0.4
                                    color: Kirigami.Theme.textColor
                                }
                                PlasmaComponents.Label {
                                    text: root.openaiModels[modelData].priced ? "$" + root.openaiModels[modelData].cost_usd.toFixed(3) : "—"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Kirigami.Theme.textColor
                                    opacity: root.openaiModels[modelData].priced ? 1.0 : 0.4
                                    Layout.preferredWidth: 52
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
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
                                    color: root.openaiGreen
                                    opacity: 0.7
                                    width: root.openaiTotalCostUSD > 0 ? parent.width * (root.openaiModels[modelData].cost_usd / root.openaiTotalCostUSD) : 0
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
        property bool showCost: false
        property string costText: ""

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
            text: slot.showCost ? slot.costText : Math.round(slot.pct) + "%"
            font.pixelSize: 12
            font.bold: true
            color: slot.showCost ? slot.iconColor : (slot.pct >= 90 ? root.dangerColor : slot.pct >= 70 ? root.warningColor : Kirigami.Theme.textColor)
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
        property string tokenText: ""

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
