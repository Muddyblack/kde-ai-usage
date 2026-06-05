import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import QtQuick.Dialogs

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: root.backgroundHints

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
            if (root._openaiApiKey)
                lines.push("API usage: configured");
            if (root.openaiTotalCostUSD > 0)
                lines.push("API cost (30d): $" + root.openaiTotalCostUSD.toFixed(2));
            if (root.openaiCodexLoggedIn)
                lines.push("Codex: signed in" + (root.openaiEmail ? " as " + root.openaiEmail : ""));
            if (root.codexUsageAvailable) {
                lines.push("Codex 5H left: " + Math.round(100 - root.codexPrimaryPct) + "%" + (root.codexPrimaryCountdown ? " (resets in " + root.codexPrimaryCountdown + ")" : ""));
                lines.push("Codex weekly left: " + Math.round(100 - root.codexSecondaryPct) + "%");
            }
            if (root.openaiPlanType)
                lines.push("Plan: " + root.openaiPlanType);
            if (root.openaiCodexLoggedIn && !root._openaiApiKey)
                lines.push("API usage needs an OpenAI API key");
        } else if (tab === "mistral") {
            if (root.mistralKeyValid)
                lines.push("API key: configured");
            if (root.mistralAvailableModels.length > 0)
                lines.push(root.mistralAvailableModels.length + " models available");
            if (root.mistralError)
                lines.push("⚠ " + root.mistralError);
        } else if (tab === "openrouter") {
            if (root.openrouterLabel)
                lines.push(root.openrouterLabel);
            if (root.openrouterUsageUSD > 0)
                lines.push("Spent: $" + root.openrouterUsageUSD.toFixed(4));
            if (root.openrouterLimitUSD !== null)
                lines.push("Limit: $" + root.openrouterLimitUSD.toFixed(2));
            if (root.openrouterIsFreeTier)
                lines.push("Free tier");
        }
        if (root.errorMsg !== "")
            lines.push("⚠ " + root.errorMsg);
        else if (root.lastUpdate !== "")
            lines.push("Updated " + root.lastUpdate + (root.stale ? " (stale)" : ""));
        return lines.join("\n");
    }

    // ── Script directory ──────────────────────────────────────────────────────
    readonly property string scriptDir: Qt.resolvedUrl("../tools/sh/").toString().replace("file://", "")

    // ── Settings: which tabs are enabled (persisted via Plasmoid.configuration) ─
    property bool claudeEnabled: Plasmoid.configuration.claudeEnabled
    property bool antigravityEnabled: Plasmoid.configuration.antigravityEnabled
    property bool openaiEnabled: Plasmoid.configuration.openaiEnabled
    property bool mistralEnabled: Plasmoid.configuration.mistralEnabled
    property bool openrouterEnabled: Plasmoid.configuration.openrouterEnabled

    // Computed list of enabled tab IDs in display order
    property var enabledTabs: {
        var t = [];
        if (root.claudeEnabled)
            t.push("claude");
        if (root.antigravityEnabled)
            t.push("antigravity");
        if (root.openaiEnabled)
            t.push("openai");
        if (root.mistralEnabled)
            t.push("mistral");
        if (root.openrouterEnabled)
            t.push("openrouter");
        return t;
    }

    property int activeTab: 0
    // Tab shown in the panel (compact) representation. When a service is pinned
    // the panel always shows that service, regardless of where the popup was last
    // left. Without a pin it mirrors the in-popup active tab.
    readonly property string panelTab: {
        if (root.pinnedTab !== "" && root.enabledTabs.indexOf(root.pinnedTab) >= 0)
            return root.pinnedTab;
        return root.enabledTabs[root.activeTab] || "";
    }
    property real chartTimeOffset: 0
    onChartWindowChanged: {
        root.chartTimeOffset = 0;
    }
    onActiveTabChanged: {
        // Map the remembered granularity (5h/24h/7d) onto the new tab so the
        // selected time range carries across services. Single-window tabs just
        // show their one window without disturbing the remembered granularity.
        var tab = root.enabledTabs[root.activeTab] || "";
        var win = root._windowForTab(tab, root.chartGranularity);
        if (root.chartWindow !== win) {
            root.chartWindow = win;
            Plasmoid.configuration.chartWindow = win;
        }
        root.chartTimeOffset = 0;
    }

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
    property string claudeOrganizationUuid: ""
    property string claudeEffortLevel: ""      // "low" | "medium" | "high" from settings.json
    property bool claudeAutoDream: false        // extended thinking toggle from settings.json
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
    property real antigravityGooglePct: 0
    property real antigravityExternalPct: 0
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
    property string _openaiAccessToken: ""   // Codex OAuth token (no org key needed)
    property string openaiEmail: ""
    property string openaiPlanType: ""
    property string openaiOrgId: ""
    property string openaiAccountId: ""
    property string openaiAuthMode: ""       // "chatgpt" | "api_key" | ""
    property bool openaiCodexLoggedIn: false
    property var openaiModels: ({})
    property real openaiTotalCostUSD: 0
    property real openaiTotalInputTokens: 0
    property real openaiTotalOutputTokens: 0

    // ── Codex / ChatGPT-plan usage (from chatgpt.com/backend-api/codex/usage) ──
    // Two rolling windows like Claude: primary = 5-hour, secondary = weekly.
    property bool codexUsageAvailable: false
    property real codexPrimaryPct: 0          // 5-hour window used %
    property var codexPrimaryResetDate: null
    property string codexPrimaryCountdown: ""
    property real codexSecondaryPct: 0        // weekly window used %
    property var codexSecondaryResetDate: null
    property string codexSecondaryCountdown: ""
    property bool codexLimitReached: false
    // Per-model additional rate limits (additional_rate_limits[] from the endpoint)
    // Each entry: { name, primary_pct, primary_reset, primary_countdown, secondary_pct, secondary_reset, secondary_countdown }
    property var codexAdditionalLimits: []

    // ── Google AI / Gemini API data ───────────────────────────────────────────
    property string _googleApiKey: ""

    // ── Mistral data ──────────────────────────────────────────────────────────
    property string _mistralApiKey: ""
    property bool mistralKeyValid: false
    property var mistralAvailableModels: []
    property string mistralError: ""
    property int mistralVibeSessionCount: 0
    property real mistralVibeTotalCost: 0
    property int mistralVibeTotalTokens: 0
    property int mistralVibePromptTokens: 0
    property int mistralVibeCompletionTokens: 0
    property int mistralVibeTotalSteps: 0
    property int mistralVibeToolOk: 0
    property int mistralVibeToolFail: 0
    property string mistralVibeActiveModel: ""
    property var mistralVibeRecent: []

    // ── OpenRouter data ───────────────────────────────────────────────────────
    property string _openrouterApiKey: ""
    property bool openrouterKeyValid: false
    property string openrouterLabel: ""
    property real openrouterUsageUSD: 0
    property var openrouterLimitUSD: null     // null = unlimited
    property var openrouterLimitRemainingUSD: null
    property bool openrouterIsFreeTier: false
    property var openrouterRateLimit: ({})
    property string openrouterError: ""

    // ── Common ────────────────────────────────────────────────────────────────
    property string errorMsg: ""
    property bool stale: false
    property string lastUpdate: ""
    property int backoffMs: 0
    property bool showSettings: false
    property bool _offline: false

    property bool showUsageChart: Plasmoid.configuration.showUsageChart

    // Unified usage history: array of {t, s, w, cp, cw}.
    // s=Claude session%, w=Claude weekly%, cp=Codex 5h%, cw=Codex weekly%.
    // `weeklyUsageHistory` exposes {t,v} for whichever window chartWindow selects.
    property var usageHistory: []
    property string chartWindow: Plasmoid.configuration.chartWindow || "weekly"
    readonly property int historyLimit: 500

    // Granularity ("5h" | "24h" | "7d") is remembered across tabs so switching
    // services keeps the same time range. Tabs with a single fixed window
    // (antigravity/openrouter/mistral) ignore it but don't clobber it, so you
    // return to your previous range when you go back to a multi-window tab.
    property string chartGranularity: {
        // Prefer a saved granularity; otherwise derive it from the saved window
        // (so existing users keep whatever range their last chartWindow implied).
        var saved = Plasmoid.configuration.chartGranularity || "";
        if (saved !== "")
            return saved;
        var fromWin = root._windowGranularity(Plasmoid.configuration.chartWindow || "");
        return fromWin !== "" ? fromWin : "7d";
    }

    // Granularity of a given window ID ("" for single-window tabs).
    function _windowGranularity(win) {
        if (win === "session" || win === "codex_primary")
            return "5h";
        if (win === "day" || win === "codex_day")
            return "24h";
        if (win === "weekly" || win === "codex_weekly")
            return "7d";
        return "";
    }

    // Window ID for a tab at the current granularity. Single-window tabs return
    // their only ID; multi-window tabs fall back to 7d if the granularity is unset.
    function _windowForTab(tab, gran) {
        if (tab === "claude")
            return gran === "5h" ? "session" : gran === "24h" ? "day" : "weekly";
        if (tab === "openai")
            return gran === "5h" ? "codex_primary" : gran === "24h" ? "codex_day" : "codex_weekly";
        if (tab === "antigravity")
            return "antigravity";
        if (tab === "openrouter")
            return "openrouter";
        if (tab === "mistral")
            return "mistral";
        return "weekly";
    }

    function _historyKey() {
        if (root.chartWindow === "session" || root.chartWindow === "day")
            return "s";
        if (root.chartWindow === "weekly")
            return "w";
        if (root.chartWindow === "codex_primary" || root.chartWindow === "codex_day")
            return "cp";
        if (root.chartWindow === "codex_weekly")
            return "cw";
        if (root.chartWindow === "antigravity")
            return "ag";
        if (root.chartWindow === "openrouter")
            return "or";
        if (root.chartWindow === "mistral")
            return "mv";
        return "w";
    }

    function getChartWindowSize() {
        var win = root.chartWindow;
        if (win === "session" || win === "codex_primary") {
            return 5 * 3600000; // 5 hours in ms
        }
        if (win === "day" || win === "codex_day") {
            return 24 * 3600000; // 24 hours in ms
        }
        if (win === "weekly" || win === "codex_weekly") {
            return 7 * 24 * 3600000; // 7 days in ms
        }
        if (win === "antigravity" || win === "openrouter" || win === "mistral") {
            return 30 * 24 * 3600000; // 30 days in ms
        }
        return 7 * 24 * 3600000;
    }

    function getChartRangeText() {
        var now_ms = new Date().getTime();
        var offset = root.chartTimeOffset;
        var winSize = root.getChartWindowSize();
        var maxT = now_ms - offset;
        var minT = maxT - winSize;

        var minDate = new Date(minT);
        var maxDate = new Date(maxT);

        var isHourly = (root.chartWindow === "session" || root.chartWindow === "codex_primary" || root.chartWindow === "day" || root.chartWindow === "codex_day");
        if (isHourly) {
            if (minDate.toDateString() === maxDate.toDateString()) {
                return Qt.formatDateTime(minDate, "hh:mm") + " - " + Qt.formatDateTime(maxDate, "hh:mm") + " (" + Qt.formatDateTime(maxDate, "MMM d") + ")";
            } else {
                return Qt.formatDateTime(minDate, "MMM d, hh:mm") + " - " + Qt.formatDateTime(maxDate, "MMM d, hh:mm");
            }
        } else {
            return Qt.formatDateTime(minDate, "MMM d") + " - " + Qt.formatDateTime(maxDate, "MMM d");
        }
    }

    // {t, v} view of the currently-selected chart window
    readonly property var weeklyUsageHistory: {
        var key = root._historyKey();
        var out = [];
        var now_ms = new Date().getTime();
        var winSize = root.getChartWindowSize();
        var maxT = now_ms - root.chartTimeOffset;
        var minT = maxT - winSize;
        for (var i = 0; i < root.usageHistory.length; i++) {
            var p = root.usageHistory[i];
            var v = p[key];
            if (v === undefined || v === null)
                continue;
            if (p.t >= minT && p.t <= maxT) {
                out.push({
                    t: p.t,
                    v: v
                });
            }
        }
        // The mistral series stores raw USD; auto-scale to its own max so the
        // spend curve fills the chart (the canvas expects a 0-100 value).
        if (key === "mv" && out.length > 0) {
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

    function loadUsageHistory() {
        var raw = Plasmoid.configuration.usageHistory || "";
        if (raw) {
            try {
                root.usageHistory = JSON.parse(raw);
                return;
            } catch (_) {
                root.usageHistory = [];
            }
        }
        // Migrate legacy weekly-only history ({t, v}) into the dual-series format.
        var legacy = Plasmoid.configuration.weeklyUsageHistory || "";
        if (legacy) {
            try {
                var old = JSON.parse(legacy);
                var migrated = [];
                for (var i = 0; i < old.length; i++)
                    migrated.push({
                        t: old[i].t,
                        w: old[i].v
                    });
                root.usageHistory = migrated;
                Plasmoid.configuration.usageHistory = JSON.stringify(migrated);
                return;
            } catch (_) {
                root.usageHistory = [];
            }
        }
        // No history in plasmoid config (e.g. fresh install after a reinstall) —
        // try restoring from the mirror file on disk.
        root.autoloadHistory();
    }

    function recordUsage(sessionPct, weeklyPct) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0) {
            var last = history[history.length - 1];
            if (now - last.t < 60000)
                return;
        }
        history.push({
            t: now,
            s: sessionPct,
            w: weeklyPct
        });
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        // Mirror to a file so history survives a full uninstall/reinstall.
        root.autosaveHistory(json);
    }

    function recordAntigravityUsage(pct) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.ag = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                t: now,
                ag: pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordOpenRouterUsage(pct) {
        if (pct <= 0)
            return;
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.or = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                t: now,
                or: pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    // Record vibe CLI cumulative cost as a history point. We store the raw USD
    // value in `mv`; the chart view auto-scales it to the window's own max so the
    // spend-growth curve is always visible (no meaningful fixed quota to scale to).
    function recordMistralVibeUsage(costUSD) {
        if (costUSD <= 0)
            return;
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.mv = costUSD;
            history[history.length - 1] = last;
        } else {
            history.push({
                t: now,
                mv: costUSD
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    // Merge Codex windows into the most recent history point (or create one).
    // Called after fetchCodexUsage() succeeds, separate from recordUsage() since
    // Claude and Codex refresh on different tabs at different times.
    function recordCodexUsage(primaryPct, weeklyPct) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        // If the last point is recent (<2 min), just patch it in-place.
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.cp = primaryPct;
            last.cw = weeklyPct;
            history[history.length - 1] = last;
        } else {
            history.push({
                t: now,
                cp: primaryPct,
                cw: weeklyPct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    // Silently mirror history JSON to ~/.local/share/ai-usage-widget/usage-history-latest.json
    function autosaveHistory(json) {
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" " + root.scriptDir + "history-io autosave";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    // Restore from the mirror file when plasmoid config has no history (e.g. fresh install).
    function autoloadHistory() {
        var cmd = root.scriptDir + "history-io autoload";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    // {t,v} view of a series ("s" or "w"), last `n` points, for spark-lines.
    function sparkSeries(seriesKey, n) {
        var out = [];
        var pts = root.usageHistory;
        for (var i = 0; i < pts.length; i++) {
            var v = pts[i][seriesKey];
            if (v === undefined || v === null)
                continue;
            out.push({
                t: pts[i].t,
                v: v
            });
        }
        if (n && out.length > n)
            out = out.slice(out.length - n);
        return out;
    }

    // ── Tab snapshot export ─────────────────────────────────────────────────
    property string _exportFormat: ""
    property int _exportW: 0
    property int _exportH: 0
    property bool _exportHideHeader: false

    // Grab while the popup is still open and visible, save straight to Downloads.
    function doExportSnapshot(grabItem, format) {
        var tab = root.enabledTabs[root.activeTab] || "tab";
        var ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        var baseName = "ai-usage-" + tab + "-" + ts;
        var tmpPng = "/tmp/" + baseName + ".png";

        root._exportFormat = format;
        root._exportW = Math.round(grabItem.width);
        root._exportH = Math.round(grabItem.implicitHeight > 0 ? grabItem.implicitHeight : grabItem.height);

        root._exportHideHeader = true;
        Qt.callLater(function () {
            grabItem.grabToImage(function (result) {
                root._exportHideHeader = false;
                if (!result.saveToFile(tmpPng)) {
                    exportSaveSource.disconnectSource("notify-send 'AI Usage Widget' 'Export failed: could not capture image'");
                    exportSaveSource.connectSource("notify-send 'AI Usage Widget' 'Export failed: could not capture image'");
                    return;
                }
                // Use $HOME in the shell so it always resolves correctly regardless of QML context
                var destPath = "$HOME/Downloads/" + baseName + "." + format;
                var cmd = "mkdir -p \"$HOME/Downloads\" && " + root.scriptDir + "export-snapshot " + format + " \"" + tmpPng + "\" \"" + destPath + "\"";
                if (format === "svg")
                    cmd += " " + root._exportW + " " + root._exportH;
                cmd += " && notify-send 'AI Usage Widget' 'Saved to ~/Downloads/" + baseName + "." + format + "'";
                exportSaveSource.disconnectSource(cmd);
                exportSaveSource.connectSource(cmd);
            });
        });
    }

    Plasma5Support.DataSource {
        id: exportSaveSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
        }
    }
    // ── History export / import ─────────────────────────────────────────────────
    property string historyIOMsg: ""

    function exportHistory() {
        var json = JSON.stringify(root.usageHistory);
        // Pass the payload base64-encoded and decode it inside the shell, so the JSON
        // (quotes, brackets) never has to survive command-line quoting.
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" " + root.scriptDir + "history-io export";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    function importHistory() {
        var cmd = root.scriptDir + "history-io import";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    Plasma5Support.DataSource {
        id: historyIOSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            // The operation is encoded as the last word of the command.
            var op = src.indexOf(" autosave") >= 0 ? "autosave" : src.indexOf(" autoload") >= 0 ? "autoload" : src.indexOf(" export") >= 0 ? "export" : "import";
            var out = (data["stdout"] || "").trim();
            try {
                var res = JSON.parse(out);
                if (res.error) {
                    // autosave/autoload are background ops — stay silent on their errors
                    if (op === "import" || op === "export")
                        root.historyIOMsg = "⚠ " + res.error;
                    return;
                }
                if (op === "autosave")
                    return; // silent mirror, nothing to do
                if (res.path) {
                    root.historyIOMsg = "Exported to " + res.path;
                    return;
                }
                if (res.data) {
                    // array of {t,s,w} (or legacy {t,v}); normalize + persist
                    var arr = res.data;
                    var norm = [];
                    for (var i = 0; i < arr.length; i++) {
                        var p = arr[i];
                        if (p.t === undefined)
                            continue;
                        if (p.w === undefined && p.v !== undefined)
                            norm.push({
                                t: p.t,
                                w: p.v
                            });
                        else
                            norm.push(p);
                    }
                    if (norm.length > root.historyLimit)
                        norm = norm.slice(norm.length - root.historyLimit);
                    // Merge autoload data with any points already recorded since startup
                    // (poll timer fires immediately and may beat the async shell).
                    if (op === "autoload" && root.usageHistory.length > 0) {
                        var existing = root.usageHistory;
                        var merged = norm.slice();
                        var lastNormT = norm.length > 0 ? norm[norm.length - 1].t : 0;
                        for (var j = 0; j < existing.length; j++) {
                            if (existing[j].t > lastNormT)
                                merged.push(existing[j]);
                        }
                        if (merged.length > root.historyLimit)
                            merged = merged.slice(merged.length - root.historyLimit);
                        root.usageHistory = merged;
                        Plasmoid.configuration.usageHistory = JSON.stringify(merged);
                        root.autosaveHistory(JSON.stringify(merged));
                        return;
                    }
                    root.usageHistory = norm;
                    Plasmoid.configuration.usageHistory = JSON.stringify(norm);
                    // Only the manual Import button announces a count; autoload is silent.
                    if (op === "import")
                        root.historyIOMsg = "Imported " + norm.length + " points";
                }
            } catch (e) {
                if (op === "import" || op === "export")
                    root.historyIOMsg = "⚠ history I/O failed";
            }
        }
    }

    // ── Colors ────────────────────────────────────────────────────────────────
    readonly property color claudeOrange: "#cc785c"
    readonly property color googleBlue: "#4285f4"
    readonly property color googleGreen: "#34a853"
    readonly property color openaiGreen: "#10a37f"
    readonly property color mistralOrange: "#ff7000"
    readonly property color openrouterPurple: "#9333ea"
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
        if (tabId === "mistral")
            return root.mistralOrange;
        if (tabId === "openrouter")
            return root.openrouterPurple;
        return Kirigami.Theme.textColor;
    }

    function tabName(tabId) {
        if (tabId === "claude")
            return "Claude";
        if (tabId === "antigravity")
            return "Antigravity";
        if (tabId === "openai")
            return "OpenAI";
        if (tabId === "mistral")
            return "Mistral";
        if (tabId === "openrouter")
            return "OpenRouter";
        return tabId;
    }

    // ── Accent (theme-aware) ────────────────────────────────────────────────────
    property bool useThemeAccent: Plasmoid.configuration.useThemeAccent
    // Resolve a service's accent: the Plasma highlight color when theme accent is on,
    // otherwise the service's own brand color.
    function accentFor(tabId) {
        if (root.useThemeAccent)
            return Kirigami.Theme.highlightColor;
        return root.tabColor(tabId);
    }
    // Accent for the currently active tab
    readonly property color activeAccent: root.accentFor(root.enabledTabs[root.activeTab] || "claude")

    // ── Appearance Customization ────────────────────────────────────────────────
    property int backgroundHints: Plasmoid.configuration.backgroundHints !== undefined ? Plasmoid.configuration.backgroundHints : 1
    property color cardBgColor: Plasmoid.configuration.cardBgColor || "#100a1a"
    property real cardBgOpacity: Plasmoid.configuration.cardBgOpacity !== undefined ? Plasmoid.configuration.cardBgOpacity : 0.90
    property color popupBgColor: Plasmoid.configuration.popupBgColor || "#000000"
    property real popupBgOpacity: Plasmoid.configuration.popupBgOpacity !== undefined ? Plasmoid.configuration.popupBgOpacity : 0.00

    readonly property color resolvedCardBg: {
        var c = Qt.color(root.cardBgColor);
        return Qt.rgba(c.r, c.g, c.b, root.cardBgOpacity);
    }
    readonly property color resolvedPopupBg: {
        var c = Qt.color(root.popupBgColor);
        return Qt.rgba(c.r, c.g, c.b, root.popupBgOpacity);
    }

    property string colorTarget: "popup"
    ColorDialog {
        id: colorDialog
        title: colorTarget === "popup" ? "Choose Popup Background Color" : "Choose Card Background Color"
        onAccepted: {
            var hex = selectedColor.toString().substring(0, 7);
            if (hex.charAt(0) !== '#')
                hex = '#' + hex; // standard hex validation
            if (colorTarget === "popup") {
                Plasmoid.configuration.popupBgColor = hex;
                root.popupBgColor = hex;
            } else {
                Plasmoid.configuration.cardBgColor = hex;
                root.cardBgColor = hex;
            }
        }
    }

    // ── Pin (auto-rotate stays the default) ─────────────────────────────────────
    property string pinnedTab: Plasmoid.configuration.pinnedTab || ""
    function togglePin(tabId) {
        var next = (root.pinnedTab === tabId) ? "" : tabId;
        root.pinnedTab = next;
        Plasmoid.configuration.pinnedTab = next;
        // When pinning, jump the active view to that tab.
        if (next !== "") {
            var idx = root.enabledTabs.indexOf(next);
            if (idx >= 0 && idx !== root.activeTab) {
                root.activeTab = idx;
                root.errorMsg = "";
                root.refresh();
            }
        }
    }

    // When the popup opens, snap back to the pinned service so the user always
    // lands on it — not wherever they happened to leave the popup last time.
    onExpandedChanged: {
        if (root.expanded && root.pinnedTab !== "") {
            var idx = root.enabledTabs.indexOf(root.pinnedTab);
            if (idx >= 0 && idx !== root.activeTab) {
                root.activeTab = idx;
                root.errorMsg = "";
                root.refresh();
            }
        }
    }

    // ── Burn-rate / ETA ─────────────────────────────────────────────────────────
    // Linear slope (%/hour) over up to the last `windowMs` of the given series key
    // ("s" session or "w" weekly). Returns null when not enough recent data.
    function usageSlopePerHour(seriesKey, windowMs) {
        var pts = root.usageHistory;
        if (!pts || pts.length < 2)
            return null;
        var now = pts[pts.length - 1].t;
        var cutoff = now - windowMs;
        var xs = [], ys = [];
        for (var i = 0; i < pts.length; i++) {
            var v = pts[i][seriesKey];
            if (v === undefined || v === null)
                continue;
            if (pts[i].t < cutoff)
                continue;
            xs.push(pts[i].t);
            ys.push(v);
        }
        if (xs.length < 2)
            return null;
        // least-squares slope in % per ms, then scale to per hour
        var n = xs.length, sx = 0, sy = 0, sxx = 0, sxy = 0;
        for (var j = 0; j < n; j++) {
            sx += xs[j];
            sy += ys[j];
            sxx += xs[j] * xs[j];
            sxy += xs[j] * ys[j];
        }
        var denom = n * sxx - sx * sx;
        if (denom === 0)
            return null;
        var slopePerMs = (n * sxy - sx * sy) / denom;
        return slopePerMs * 3600000;
    }

    // ETA text to reach 100% for a series given its current value. Returns "" when
    // not climbing (or climbing too slowly to matter / already full).
    function etaToFull(seriesKey, currentPct) {
        if (currentPct >= 100)
            return "";
        var slope = root.usageSlopePerHour(seriesKey, 6 * 3600000); // last 6h trend
        if (slope === null || slope < 0.5)   // need a meaningful climb
            return "";
        var hoursLeft = (100 - currentPct) / slope;
        if (hoursLeft > 240)                 // >10 days out: not actionable
            return "";
        if (hoursLeft < 1)
            return "~" + Math.max(1, Math.round(hoursLeft * 60)) + "m to 100%";
        if (hoursLeft < 24)
            return "~" + hoursLeft.toFixed(1).replace(/\.0$/, "") + "h to 100%";
        return "~" + Math.round(hoursLeft / 24) + "d to 100%";
    }

    // Period-over-period comparison: current value vs the sample closest to `periodMs` ago.
    // Returns "" if there's no comparable older sample; otherwise e.g. "+12% vs last week".
    function periodDelta(seriesKey, currentPct, periodMs, periodLabel) {
        var pts = root.usageHistory;
        if (!pts || pts.length < 2)
            return "";
        var now = pts[pts.length - 1].t;
        var target = now - periodMs;
        // need history reaching back at least ~80% of the period to be meaningful
        if (pts[0].t > target + periodMs * 0.2)
            return "";
        // find sample nearest the target time that has this series
        var best = null, bestDist = Infinity;
        for (var i = 0; i < pts.length; i++) {
            var v = pts[i][seriesKey];
            if (v === undefined || v === null)
                continue;
            var d = Math.abs(pts[i].t - target);
            if (d < bestDist) {
                bestDist = d;
                best = v;
            }
        }
        if (best === null)
            return "";
        var diff = Math.round(currentPct - best);
        if (diff === 0)
            return "≈ same as " + periodLabel;
        return (diff > 0 ? "+" : "") + diff + "% vs " + periodLabel;
    }

    // ── Cost aggregation ─────────────────────────────────────────────────────────
    // Combined spend across paid API surfaces. Claude/OpenAI are 30-day org usage;
    // OpenRouter reports all-time credit spend, so the total is a rough combined figure.
    readonly property real totalSpendUSD: {
        var sum = 0;
        if (root.claudeTotalCostUSD > 0)
            sum += root.claudeTotalCostUSD;
        if (root.openaiTotalCostUSD > 0)
            sum += root.openaiTotalCostUSD;
        if (root.openrouterUsageUSD > 0)
            sum += root.openrouterUsageUSD;
        return sum;
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
        root.codexPrimaryCountdown = root.formatCountdown(root.codexPrimaryResetDate);
        root.codexSecondaryCountdown = root.formatCountdown(root.codexSecondaryResetDate);
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
                root.claudeOrganizationUuid = creds.organizationUuid || "";
            } catch (_) {
                root._claudeToken = "";
                root._claudeAdminToken = "";
                root.claudeSubscriptionType = "";
                root.claudeRateLimitTier = "";
                root.claudeOrganizationUuid = "";
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
        id: claudeSettingsSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            try {
                var s = JSON.parse((data["stdout"] || "").trim());
                root.claudeEffortLevel = s.effortLevel || "";
                root.claudeAutoDream = s.autoDreamEnabled === true;
            } catch (_) {
                root.claudeEffortLevel = "";
                root.claudeAutoDream = false;
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
                root.stale = root.lastUpdate !== "";
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
                var googleUsed = 0;
                var googleCount = 0;
                var externalUsed = 0;
                var externalCount = 0;
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
                        var name = (m.label || m.modelId).toLowerCase();
                        if (name.indexOf("gemini") !== -1 || name.indexOf("google") !== -1) {
                            googleUsed += usedPct;
                            googleCount++;
                        } else {
                            externalUsed += usedPct;
                            externalCount++;
                        }
                    }
                    if (m.resetTime) {
                        var rd = new Date(m.resetTime);
                        if (!isNaN(rd.getTime()) && (earliestReset === null || rd < earliestReset))
                            earliestReset = rd;
                    }
                }
                root.antigravityModels = newModels;
                root.antigravityPct = modelCount > 0 ? totalUsed / modelCount : 0;
                root.antigravityGooglePct = googleCount > 0 ? googleUsed / googleCount : 0;
                root.antigravityExternalPct = externalCount > 0 ? externalUsed / externalCount : 0;
                root.recordAntigravityUsage(root.antigravityPct);
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
                root._offline = false;
                offlineRetryTimer.stop();
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
                root._openaiAccessToken = creds.codexAccessToken || "";
                root.openaiEmail = creds.email || "";
                root.openaiPlanType = creds.planType || "";
                root.openaiOrgId = creds.orgId || "";
                root.openaiAccountId = creds.accountId || "";
                root.openaiAuthMode = creds.authMode || "";
                root.openaiCodexLoggedIn = creds.codexLoggedIn === true || root._openaiAccessToken !== "";
            } catch (_) {
                root._openaiApiKey = "";
                root._openaiAccessToken = "";
                root.openaiEmail = "";
                root.openaiPlanType = "";
                root.openaiOrgId = "";
                root.openaiAccountId = "";
                root.openaiAuthMode = "";
                root.openaiCodexLoggedIn = false;
            }
            // Codex plan usage is independent of the org API key — fetch it whenever signed in.
            if (root.openaiCodexLoggedIn)
                fetchCodexUsage();
            if (root._openaiApiKey) {
                fetchOpenAIUsage();
            } else if (root.openaiCodexLoggedIn) {
                root.openaiModels = ({});
                root.openaiTotalCostUSD = 0;
                root.openaiTotalInputTokens = 0;
                root.openaiTotalOutputTokens = 0;
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
            } else {
                root.openaiModels = ({});
                root.openaiTotalCostUSD = 0;
                root.openaiTotalInputTokens = 0;
                root.openaiTotalOutputTokens = 0;
                root.errorMsg = "OpenAI: no API key or Codex login";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    Plasma5Support.DataSource {
        id: mistralCredSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "mistral")
                return;
            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root.errorMsg = "Mistral: no API key configured";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                // always harvest vibe stats regardless of key validity
                root.mistralVibeSessionCount = res.vibeSessionCount || 0;
                root.mistralVibeTotalCost = res.vibeTotalCost || 0;
                root.mistralVibeTotalTokens = res.vibeTotalTokens || 0;
                root.mistralVibePromptTokens = res.vibePromptTokens || 0;
                root.mistralVibeCompletionTokens = res.vibeCompletionTokens || 0;
                root.mistralVibeTotalSteps = res.vibeTotalSteps || 0;
                root.mistralVibeToolOk = res.vibeToolOk || 0;
                root.mistralVibeToolFail = res.vibeToolFail || 0;
                root.mistralVibeActiveModel = res.vibeActiveModel || "";
                root.mistralVibeRecent = res.vibeRecent || [];
                if (res.error) {
                    root.mistralError = res.error;
                    root.errorMsg = res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root._mistralApiKey = res.mistralApiKey || "";
                root.mistralKeyValid = res.keyValid === true;
                root.mistralAvailableModels = res.availableModels || [];
                root.mistralError = "";
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                root.recordMistralVibeUsage(root.mistralVibeTotalCost);
            } catch (e) {
                root.errorMsg = "Mistral: parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    Plasma5Support.DataSource {
        id: openrouterCredSource
        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "openrouter")
                return;
            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root.errorMsg = "OpenRouter: no API key configured";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error && !res.openrouterApiKey) {
                    root.openrouterError = res.error;
                    root.errorMsg = res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root._openrouterApiKey = res.openrouterApiKey || "";
                root.openrouterKeyValid = res.keyValid === true;
                root.openrouterLabel = res.label || "";
                root.openrouterUsageUSD = res.usageUSD || 0;
                root.openrouterLimitUSD = (res.limitUSD !== undefined && res.limitUSD !== null) ? res.limitUSD : null;
                root.openrouterLimitRemainingUSD = (res.limitRemainingUSD !== undefined && res.limitRemainingUSD !== null) ? res.limitRemainingUSD : null;
                root.openrouterIsFreeTier = res.isFreeTier === true;
                root.openrouterRateLimit = res.rateLimit || {};
                root.openrouterError = "";
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                if (root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0)
                    root.recordOpenRouterUsage(Math.min(100, (root.openrouterUsageUSD / root.openrouterLimitUSD) * 100));
            } catch (e) {
                root.errorMsg = "OpenRouter: parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    function loadCreds() {
        var tab = root.enabledTabs[root.activeTab];
        if (tab === "claude") {
            var cfgKey = Plasmoid.configuration.claudeAdminApiKey || "";
            // base64-encode the key so shell metacharacters in it can't break out
            // of the command string (decoded back in the env assignment).
            var envPrefix = cfgKey ? "WIDGET_CLAUDE_ADMIN_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptDir + "get-claude-credentials";
            credSource.disconnectSource(cmd);
            credSource.connectSource(cmd);
            // Read effort level + dream mode from ~/.claude/settings.json
            var settingsCmd = "cat \"$HOME/.claude/settings.json\" 2>/dev/null || echo '{}'";
            claudeSettingsSource.disconnectSource(settingsCmd);
            claudeSettingsSource.connectSource(settingsCmd);
        } else if (tab === "antigravity") {
            var cmd = root.scriptDir + "get-antigravity-usage";
            antigravityUsageSource.disconnectSource(cmd);
            antigravityUsageSource.connectSource(cmd);
        } else if (tab === "openai") {
            var cfgKey = Plasmoid.configuration.openaiApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENAI_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptDir + "get-openai-usage";
            openaiCredSource.disconnectSource(cmd);
            openaiCredSource.connectSource(cmd);
        } else if (tab === "mistral") {
            var cfgKey = Plasmoid.configuration.mistralApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_MISTRAL_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptDir + "get-mistral-usage";
            mistralCredSource.disconnectSource(cmd);
            mistralCredSource.connectSource(cmd);
        } else if (tab === "openrouter") {
            var cfgKey = Plasmoid.configuration.openrouterApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENROUTER_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptDir + "get-openrouter-usage";
            openrouterCredSource.disconnectSource(cmd);
            openrouterCredSource.connectSource(cmd);
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
                    root._offline = false;
                    offlineRetryTimer.stop();
                    root.recordUsage(root.sessionPct, root.weeklyPct);
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
            } else if (xhr.status === 0) {
                root.errorMsg = "offline";
                root.stale = root.lastUpdate !== "";
                root._offline = true;
                offlineRetryTimer.restart();
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
            if (xhr.status === 0) {
                root.errorMsg = "offline";
                root.stale = root.lastUpdate !== "";
                root._offline = true;
                offlineRetryTimer.restart();
                return;
            }
            if (xhr.status === 401) {
                root.errorMsg = "OpenAI API key invalid";
                root.stale = root.lastUpdate !== "";
                return;
            }
            if (xhr.status === 403) {
                root.errorMsg = "OpenAI usage access denied";
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
                root._offline = false;
                offlineRetryTimer.stop();
            } catch (e) {
                console.log("OpenAI usage parse error: " + e);
                root.errorMsg = "parse error";
                root.stale = root.lastUpdate !== "";
            }
        };
        xhr.send();
    }

    // ── Codex / ChatGPT-plan usage ────────────────────────────────────────────
    // Uses the Codex OAuth access token to read the plan's rolling rate-limit
    // windows (5-hour + weekly). This is what "messages remaining" maps to for a
    // ChatGPT-plan login; it's separate from OpenAI API org billing.
    function fetchCodexUsage() {
        if (!root._openaiAccessToken)
            return;
        var reqTab = root.activeTab;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://chatgpt.com/backend-api/codex/usage");
        xhr.setRequestHeader("Authorization", "Bearer " + root._openaiAccessToken);
        if (root.openaiAccountId)
            xhr.setRequestHeader("chatgpt-account-id", root.openaiAccountId);
        xhr.setRequestHeader("User-Agent", "codex-cli");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (root.activeTab !== reqTab)
                return;
            if (xhr.status !== 200) {
                // Don't surface as a hard error — account status still shows.
                root.codexUsageAvailable = false;
                return;
            }
            try {
                var d = JSON.parse(xhr.responseText);
                if (d.plan_type)
                    root.openaiPlanType = d.plan_type;
                var rl = d.rate_limit || {};
                var pw = rl.primary_window || {};
                var sw = rl.secondary_window || {};
                root.codexPrimaryPct = pw.used_percent || 0;
                root.codexSecondaryPct = sw.used_percent || 0;
                root.codexLimitReached = rl.limit_reached === true;
                root.codexPrimaryResetDate = pw.reset_at ? new Date(pw.reset_at * 1000) : null;
                root.codexSecondaryResetDate = sw.reset_at ? new Date(sw.reset_at * 1000) : null;
                root.codexUsageAvailable = (rl.primary_window !== undefined || rl.secondary_window !== undefined);
                // Parse per-model additional rate limits
                var addl = d.additional_rate_limits || [];
                var parsedAddl = [];
                for (var i = 0; i < addl.length; i++) {
                    var entry = addl[i];
                    var erl = entry.rate_limit || {};
                    var epw = erl.primary_window || {};
                    var esw = erl.secondary_window || {};
                    parsedAddl.push({
                        name: entry.limit_name || ("Model " + (i + 1)),
                        primary_pct: epw.used_percent || 0,
                        primary_reset: epw.reset_at ? new Date(epw.reset_at * 1000) : null,
                        secondary_pct: esw.used_percent || 0,
                        secondary_reset: esw.reset_at ? new Date(esw.reset_at * 1000) : null,
                        limit_reached: erl.limit_reached === true
                    });
                }
                root.codexAdditionalLimits = parsedAddl;
                root.updateCountdowns();
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                if (root.codexUsageAvailable)
                    root.recordCodexUsage(root.codexPrimaryPct, root.codexSecondaryPct);
            } catch (e) {
                root.codexUsageAvailable = false;
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
    // Poll interval is user-configurable (seconds); default 300s. Clamp to a sane floor.
    property int pollIntervalSec: Plasmoid.configuration.pollIntervalSec || 300
    Timer {
        interval: Math.max(30, root.pollIntervalSec) * 1000
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
    Timer {
        id: offlineRetryTimer
        interval: 60000
        running: false
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.loadUsageHistory();
        // Honor a pinned service on startup by selecting its tab.
        if (root.pinnedTab !== "") {
            var idx = root.enabledTabs.indexOf(root.pinnedTab);
            if (idx >= 0)
                root.activeTab = idx;
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
                stale: root.stale && root.panelTab === "claude"
                visible: root.panelTab === "claude"
                tooltipText: "Claude 5-hour: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) : "")
            }
            Rectangle {
                visible: root.panelTab === "claude"
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }
            PanelSlot {
                pct: root.weeklyPct
                iconColor: root.weeklyColor
                stale: root.stale && root.panelTab === "claude"
                visible: root.panelTab === "claude"
                tooltipText: "Claude 7-day: " + Math.round(root.weeklyPct) + "%" + (root.weeklyTokenLimit > 0 ? "\n" + root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) : "")
            }

            PanelSlot {
                pct: root.antigravityGooglePct
                iconColor: root.googleBlue
                stale: root.stale && root.panelTab === "antigravity"
                visible: root.panelTab === "antigravity"
                tooltipText: "Gemini (Google) quota: " + Math.round(root.antigravityGooglePct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }
            Rectangle {
                visible: root.panelTab === "antigravity"
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }
            PanelSlot {
                pct: root.antigravityExternalPct
                iconColor: root.googleGreen
                stale: root.stale && root.panelTab === "antigravity"
                visible: root.panelTab === "antigravity"
                tooltipText: "External models quota: " + Math.round(root.antigravityExternalPct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }

            PanelSlot {
                // When Codex plan usage is available (and no API cost to show), surface the
                // 5-hour window % so the panel reflects "messages left" at a glance.
                pct: root.codexUsageAvailable ? root.codexPrimaryPct : (root.openaiTotalCostUSD > 0 ? Math.min(100, (root.openaiTotalCostUSD / 10) * 100) : 0)
                iconColor: root.openaiGreen
                stale: root.stale && root.panelTab === "openai"
                visible: root.panelTab === "openai"
                showCost: !root.codexUsageAvailable
                costText: root.openaiTotalCostUSD > 0 ? "$" + root.openaiTotalCostUSD.toFixed(2) : (root._openaiApiKey ? "API" : (root.openaiCodexLoggedIn ? "Codex" : "—"))
                tooltipText: "OpenAI" + (root.codexUsageAvailable ? "\nCodex 5h: " + Math.round(100 - root.codexPrimaryPct) + "% left  ·  weekly: " + Math.round(100 - root.codexSecondaryPct) + "% left" : "") + (root._openaiApiKey ? "\nAPI usage configured\nCost (30d): $" + root.openaiTotalCostUSD.toFixed(2) + "\nIn: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens) : "\nAPI usage needs an OpenAI API key") + (root.openaiCodexLoggedIn ? "\nCodex signed in" + (root.openaiEmail ? ": " + root.openaiEmail : "") : "")
            }
            Rectangle {
                visible: root.panelTab === "openai" && root.codexUsageAvailable
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }
            PanelSlot {
                pct: root.codexSecondaryPct
                iconColor: root.openaiGreen
                stale: root.stale && root.panelTab === "openai"
                visible: root.panelTab === "openai" && root.codexUsageAvailable
                showCost: false
                tooltipText: "OpenAI Codex weekly: " + Math.round(100 - root.codexSecondaryPct) + "% left"
            }

            PanelSlot {
                pct: 0
                iconColor: root.mistralOrange
                stale: root.stale && root.panelTab === "mistral"
                visible: root.panelTab === "mistral"
                showCost: true
                costText: root.mistralVibeTotalCost > 0 ? "$" + root.mistralVibeTotalCost.toFixed(2) : (root.mistralKeyValid ? "✓ key" : "—")
                tooltipText: "Mistral AI" + (root.mistralKeyValid ? "\nAPI key configured" : "\nNo key set") + (root.mistralVibeTotalCost > 0 ? "\nSpend (vibe): $" + root.mistralVibeTotalCost.toFixed(4) : "") + (root.mistralAvailableModels.length > 0 ? "\n" + root.mistralAvailableModels.length + " models" : "")
            }

            PanelSlot {
                pct: root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0 ? Math.min(100, (root.openrouterUsageUSD / root.openrouterLimitUSD) * 100) : 0
                iconColor: root.openrouterPurple
                stale: root.stale && root.panelTab === "openrouter"
                visible: root.panelTab === "openrouter" && !root.showSettings
                showCost: true
                costText: root.openrouterKeyValid ? (root.openrouterUsageUSD > 0 ? "$" + root.openrouterUsageUSD.toFixed(3) : "✓ key") : "—"
                tooltipText: "OpenRouter" + (root.openrouterLabel ? "\n" + root.openrouterLabel : "") + (root.openrouterUsageUSD > 0 ? "\nUsed: $" + root.openrouterUsageUSD.toFixed(4) : "") + (root.openrouterLimitUSD !== null ? "\nLimit: $" + root.openrouterLimitUSD.toFixed(2) : "")
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: popupRoot
        readonly property int popupMargin: Kirigami.Units.largeSpacing + 4
        readonly property int targetHeight: Math.ceil(mainColumn.implicitHeight + popupMargin * 2)

        implicitWidth: Kirigami.Units.gridUnit * 26
        implicitHeight: targetHeight
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        // PlasmaCore.Dialog latches the popup to the largest size it has seen and
        // won't shrink back when a tab swap reduces mainColumn.implicitHeight — it
        // samples the size mid-transition (old, taller content still tearing down).
        // Nudge the binding one frame later so the dialog re-samples the smaller value.
        Connections {
            target: root
            function onActiveTabChanged() {
                relayoutTimer.restart();
            }
            function onShowSettingsChanged() {
                relayoutTimer.restart();
            }
        }
        Timer {
            id: relayoutTimer
            interval: 0
            onTriggered: {
                popupRoot.implicitHeight = 0;
                popupRoot.implicitHeight = Qt.binding(function () {
                    return popupRoot.targetHeight;
                });
            }
        }

        // ── Glassmorphism backdrop ──────────────────────────────────────────
        // A translucent tinted layer that lets Plasma's native popup blur show
        // through, plus a faint accent glow and inner highlight for the "glass" look.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -popupRoot.popupMargin
            radius: 12
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, 0.10)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(1, 1, 1, 0.04)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.06)
                }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            // soft accent glow in the top-left, tinted by the active service accent
            Rectangle {
                width: parent.width * 0.7
                height: parent.height * 0.7
                anchors.top: parent.top
                anchors.left: parent.left
                radius: width / 2
                opacity: 0.12
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }
            // crisp inner top highlight line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                color: Qt.rgba(1, 1, 1, 0.18)
            }
        }

        // Custom background tint overlay (defaults to 0 opacity, i.e. invisible/glassy)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -popupRoot.popupMargin
            radius: 12
            color: root.resolvedPopupBg
            visible: root.popupBgOpacity > 0
        }

        ColumnLayout {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: popupRoot.popupMargin
            anchors.rightMargin: popupRoot.popupMargin
            anchors.topMargin: popupRoot.popupMargin
            height: implicitHeight
            spacing: Kirigami.Units.largeSpacing

            // ── Header ──────────────────────────────────────────────────────
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: 8
                visible: !root._exportHideHeader

                Item {
                    width: 22
                    height: 22
                    // Masked Kirigami Icons (shown when NOT in Settings)
                    Kirigami.Icon {
                        visible: !root.showSettings
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        isMask: true
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
                        opacity: 0.22
                    }
                    Kirigami.Icon {
                        visible: !root.showSettings
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        isMask: true
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
                    }

                    // Raw Images with Rainbow Gradient (shown when in Settings)
                    Image {
                        visible: root.showSettings
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        sourceSize.width: 22
                        sourceSize.height: 22
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                        opacity: 0.15
                    }
                    Image {
                        visible: root.showSettings
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        sourceSize.width: 18
                        sourceSize.height: 18
                        source: Qt.resolvedUrl("../icons/org.muddyblack.aiUsageWidget.svg")
                    }
                }

                ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label {
                        text: {
                            if (root.showSettings)
                                return "Settings";
                            var tab = root.enabledTabs[root.activeTab];
                            if (tab === "claude")
                                return "Claude Usage";
                            if (tab === "antigravity")
                                return "Antigravity Usage";
                            if (tab === "openai")
                                return "OpenAI Usage";
                            if (tab === "mistral")
                                return "Mistral Usage";
                            if (tab === "openrouter")
                                return "OpenRouter Usage";
                            return "AI Usage Monitor";
                        }
                        font.bold: true
                        font.pixelSize: 15
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        visible: root.showSettings
                        text: "Configure API keys and providers"
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // ── Export button ─────────────────────────────────────────
                PlasmaComponents.ToolButton {
                    id: exportBtn
                    icon.name: "document-save"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    visible: !root.showSettings
                    opacity: hovered ? 1.0 : 0.6
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    QQC2.ToolTip.visible: hovered && !exportMenu.visible
                    QQC2.ToolTip.delay: 400
                    QQC2.ToolTip.text: "Export current tab as PNG or SVG"
                    onClicked: exportMenu.popup()

                    QQC2.Menu {
                        id: exportMenu

                        QQC2.MenuItem {
                            text: "Export as PNG"
                            icon.name: "image-x-generic"
                            onTriggered: root.doExportSnapshot(mainColumn, "png")
                        }

                        QQC2.MenuItem {
                            text: "Export as SVG"
                            icon.name: "image-svg+xml"
                            onTriggered: root.doExportSnapshot(mainColumn, "svg")
                        }
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: root.showSettings ? "arrow-left" : "configure"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: root.showSettings = !root.showSettings
                    opacity: hovered ? 1.0 : (root.showSettings ? 1.0 : 0.6)
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

            // ── Tab bar ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.enabledTabs.length > 1 && !root.showSettings

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
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    root.togglePin(modelData);
                                    return;
                                }
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

                        // Pin toggle — visible when pinned or on hover. Click to pin/unpin.
                        Kirigami.Icon {
                            id: pinIcon
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 3
                            anchors.rightMargin: 3
                            width: 11
                            height: 11
                            source: "pin"
                            isMask: true
                            visible: root.pinnedTab === modelData || tabMouse.containsMouse || pinMouse.containsMouse
                            color: root.pinnedTab === modelData ? root.activeAccent : Kirigami.Theme.textColor
                            opacity: root.pinnedTab === modelData ? 1.0 : 0.4
                            MouseArea {
                                id: pinMouse
                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePin(modelData)
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.text: root.pinnedTab === modelData ? "Unpin (resume auto)" : "Pin this service"
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

            SettingsPanel {
                rootItem: root
            }

            ClaudeTab {
                rootItem: root
            }

            AntigravityTab {
                rootItem: root
            }

            OpenAiTab {
                rootItem: root
            }

            MistralTab {
                rootItem: root
            }

            OpenRouterTab {
                rootItem: root
            }

            UsageChart {
                rootItem: root
            }

            // ── Footer ─────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: !root.showSettings

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
                // Combined 30-day spend across paid API surfaces
                Rectangle {
                    visible: root.totalSpendUSD > 0
                    implicitHeight: 16
                    implicitWidth: spendLabel.implicitWidth + 14
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 6
                    PlasmaComponents.Label {
                        id: spendLabel
                        anchors.centerIn: parent
                        text: "Σ $" + root.totalSpendUSD.toFixed(2)
                        font.pixelSize: 9
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.8
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.delay: 300
                        QQC2.ToolTip.text: {
                            var l = ["Combined API spend"];
                            if (root.claudeTotalCostUSD > 0)
                                l.push("Claude (30d): $" + root.claudeTotalCostUSD.toFixed(2));
                            if (root.openaiTotalCostUSD > 0)
                                l.push("OpenAI (30d): $" + root.openaiTotalCostUSD.toFixed(2));
                            if (root.openrouterUsageUSD > 0)
                                l.push("OpenRouter (all-time): $" + root.openrouterUsageUSD.toFixed(2));
                            return l.join("\n");
                        }
                    }
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
}
