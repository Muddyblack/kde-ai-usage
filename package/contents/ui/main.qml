import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid
import "../code/Format.js" as Format
import "../code/Shell.js" as Shell
import "../code/UsageHistory.js" as UsageHistory

PlasmoidItem {
    // GPT-4o family
    // o1 / o3 reasoning family
    // GPT-4 Turbo / legacy
    // GPT-3.5
    // Codex / embeddings (no output tokens)

    id: root

    // ── Script directory ──────────────────────────────────────────────────────
    readonly property string scriptDir: Qt.resolvedUrl("../tools/sh/").toString().replace("file://", "")
    // ── Settings: which tabs are enabled (persisted via Plasmoid.configuration) ─
    property bool claudeEnabled: Plasmoid.configuration.claudeEnabled
    property bool antigravityEnabled: Plasmoid.configuration.antigravityEnabled
    property bool openaiEnabled: Plasmoid.configuration.openaiEnabled
    property bool kiroEnabled: Plasmoid.configuration.kiroEnabled
    property bool mistralEnabled: Plasmoid.configuration.mistralEnabled
    property bool openrouterEnabled: Plasmoid.configuration.openrouterEnabled
    property bool grokEnabled: Plasmoid.configuration.grokEnabled
    property bool zaiEnabled: Plasmoid.configuration.zaiEnabled
    property bool copilotEnabled: Plasmoid.configuration.copilotEnabled
    property bool deepseekEnabled: Plasmoid.configuration.deepseekEnabled
    property bool kimiEnabled: Plasmoid.configuration.kimiEnabled
    // Computed list of enabled tab IDs in display order
    property var enabledTabs: {
        var t = [];
        if (root.claudeEnabled)
            t.push("claude");

        if (root.antigravityEnabled)
            t.push("antigravity");

        if (root.openaiEnabled)
            t.push("openai");

        if (root.kiroEnabled)
            t.push("kiro");

        if (root.mistralEnabled)
            t.push("mistral");

        if (root.openrouterEnabled)
            t.push("openrouter");

        if (root.grokEnabled)
            t.push("grok");

        if (root.zaiEnabled)
            t.push("zai");

        if (root.copilotEnabled)
            t.push("copilot");

        if (root.deepseekEnabled)
            t.push("deepseek");
        if (root.kimiEnabled)
            t.push("kimi");

        return t;
    }
    property int activeTab: 0
    // Primary tab for single-tab fallbacks. The compact panel can show every
    // pinned service; without pins it mirrors the in-popup active tab.
    readonly property string panelTab: {
        if (root.pinnedTabs.length > 0)
            return root.pinnedTabs[0];

        return root.enabledTabs[root.activeTab] || "";
    }
    property real chartTimeOffset: 0
    // ── Service status (status pages) ────────────────────────────────────────
    // Each object: { indicator, description, components, incidents, latestUpdate }
    property var claudeStatus: ({
            "indicator": "",
            "description": "",
            "components": [],
            "incidents": [],
            "latestUpdate": ""
        })
    property var mistralStatus: ({
            "indicator": "",
            "description": "",
            "components": [],
            "incidents": [],
            "latestUpdate": ""
        })
    property var openaiStatus: ({
            "indicator": "",
            "description": "",
            "components": [],
            "incidents": [],
            "latestUpdate": ""
        })
    property var openrouterStatus: ({
            "indicator": "",
            "description": "",
            "components": [],
            "incidents": [],
            "latestUpdate": ""
        })
    // ── Claude data ───────────────────────────────────────────────────────────
    property bool sessionAvailable: false
    property real sessionPct: 0
    property real sessionTokensUsed: 0
    property real sessionTokenLimit: 0
    property string sessionResetTime: ""
    property var sessionResetDate: null
    property string sessionCountdown: ""
    property bool weeklyAvailable: false
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
    property string claudeEffortLevel: "" // "low" | "medium" | "high" from settings.json
    property bool claudeAutoDream: false // extended thinking toggle from settings.json
    property bool claudeExtraUsageEnabled: false
    property real claudeExtraUsageLimit: 0
    property real claudeExtraUsageUsed: 0
    property real claudeExtraUsagePct: 0
    property string claudeExtraUsageCurrency: "USD"
    // Credential *presence* only — the backend never hands tokens to the UI.
    property bool claudeHasOAuth: false
    property bool claudeHasAdminKey: false
    property var claudeModels: ({})
    property real claudeTotalCostUSD: 0
    property real claudeTotalInputTokens: 0
    property real claudeTotalOutputTokens: 0

    // Claude Code local activity stats (mirrors ~/.claude/stats-cache.json).
    property bool claudeStatsAvailable: false
    property int claudeStatsVersion: 0
    property real claudeStatsTotalMessages: 0
    property real claudeStatsTotalSessions: 0
    property real claudeStatsTotalTokens: 0
    property string claudeStatsFavoriteModel: ""
    property string claudeStatsFirstDate: ""
    property string claudeStatsComputedDate: ""
    property real claudeStatsActiveDays: 0
    property real claudeStatsSpanDays: 0
    property real claudeStatsCurrentStreak: 0
    property real claudeStatsLongestStreak: 0
    property real claudeStatsLongestSessionMs: 0
    property real claudeStatsLongestSessionMessages: 0
    // Present in stats-cache.json since the CLI started recording per-model
    // spend and tool activity.
    property real claudeStatsTotalCostUSD: 0
    property real claudeStatsTotalToolCalls: 0
    property real claudeStatsTotalWebSearches: 0
    property real claudeStatsPeakHour: -1
    property var claudeStatsModels: ({})
    property var claudeStatsDailyTokens: []
    // ── Codex (OpenAI CLI) lifetime stats, from get-codex-stats ──────────────
    property bool codexStatsAvailable: false
    property real codexStatsTotalSessions: 0
    property real codexStatsTotalMessages: 0
    property real codexStatsTotalTokens: 0
    property real codexStatsTotalToolCalls: 0
    property string codexStatsFirstDate: ""
    property string codexStatsComputedDate: ""
    property real codexStatsActiveDays: 0
    property real codexStatsSpanDays: 0
    property real codexStatsCurrentStreak: 0
    property real codexStatsLongestStreak: 0
    property real codexStatsLongestSessionMs: 0
    property real codexStatsLongestSessionMessages: 0
    property real codexStatsPeakHour: -1
    property string codexStatsFavoriteModel: ""
    property var codexStatsModels: ({})
    property var codexStatsDailyTokens: []
    // Live model / reasoning effort, from the newest rollout's turn_context
    // (falls back to ~/.codex/config.toml).
    property string codexModel: ""
    property string codexEffortLevel: ""
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
    property var antigravityModels: ({})
    property var antigravityGroups: []
    // ── OpenAI data ───────────────────────────────────────────────────────────
    property bool openaiHasApiKey: false
    property string openaiEmail: ""
    property string openaiPlanType: ""
    property string openaiOrgId: ""
    property string openaiAccountId: ""
    property string openaiAuthMode: "" // "chatgpt" | "api_key" | ""
    property bool openaiCodexLoggedIn: false
    property var openaiModels: ({})
    property real openaiTotalCostUSD: 0
    property real openaiTotalInputTokens: 0
    property real openaiTotalOutputTokens: 0
    // ── Kiro data ─────────────────────────────────────────────────────────────
    property bool kiroUsageAvailable: false
    property string kiroPlanType: ""
    property string kiroDisplayName: "Credit"
    property string kiroDisplayNamePlural: "Credits"
    property real kiroCurrentUsage: 0
    property real kiroUsageLimit: 0
    property real kiroPct: 0
    property real kiroRemaining: 0
    property real kiroCurrentOverages: 0
    property real kiroOverageCap: 0
    property real kiroOverageCharges: 0
    property real kiroOverageRate: 0
    property string kiroCurrencyCode: "USD"
    property string kiroCurrencySymbol: "$"
    property string kiroResetTime: ""
    property var kiroResetDate: null
    property string kiroCountdown: ""
    // ── Codex / ChatGPT-plan usage ────────────────────────────────────────────
    // Windows are classified by their actual duration, never by response order.
    property bool codexUsageAvailable: false
    property bool codexSessionAvailable: false
    property real codexSessionPct: 0
    property var codexSessionResetDate: null
    property string codexSessionCountdown: ""
    property bool codexWeeklyAvailable: false
    property real codexWeeklyPct: 0
    property var codexWeeklyResetDate: null
    property string codexWeeklyCountdown: ""
    // Deprecated compatibility aliases. Keep these until five-hour windows return.
    readonly property real codexPrimaryPct: root.codexSessionPct
    readonly property var codexPrimaryResetDate: root.codexSessionResetDate
    readonly property string codexPrimaryCountdown: root.codexSessionCountdown
    readonly property real codexSecondaryPct: root.codexWeeklyPct
    readonly property var codexSecondaryResetDate: root.codexWeeklyResetDate
    readonly property string codexSecondaryCountdown: root.codexWeeklyCountdown
    property bool codexLimitReached: false
    // Per-model additional rate limits (additional_rate_limits[] from the endpoint)
    // Each entry: { name, primary_pct, primary_reset, primary_countdown, secondary_pct, secondary_reset, secondary_countdown }
    property var codexAdditionalLimits: []
    // ── Mistral data ──────────────────────────────────────────────────────────
    property bool mistralHasKey: false
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
    property bool openrouterHasKey: false
    property bool openrouterKeyValid: false
    property string openrouterLabel: ""
    property real openrouterUsageUSD: 0
    property var openrouterLimitUSD: null // null = unlimited
    property var openrouterLimitRemainingUSD: null
    property bool openrouterIsFreeTier: false
    property var openrouterRateLimit: ({})
    property string openrouterError: ""
    // ── Grok CLI / xAI data ──────────────────────────────────────────────────
    property bool grokHasKey: false
    property bool grokLoggedIn: false
    property real grokPct: 0
    property real grokUsed: 0
    property real grokMonthlyLimit: 0
    property string grokEmail: ""
    property string grokTeamName: ""
    property string grokTierId: ""
    property string grokBillingPeriodEnd: ""
    property int grokSessionCount: 0
    property real grokTotalTokens: 0
    property int grokTotalToolCalls: 0
    property string grokError: ""
    property bool grokHasBilling: false
    property string grokQuotaKind: ""
    property string grokQuotaWindow: ""
    property bool grokQuotaExhausted: false
    // ── Z.AI data ─────────────────────────────────────────────────────────────
    property bool zaiHasKey: false
    property bool zaiKeyValid: false
    property string zaiLevel: ""
    property real zaiTokenPct: 0
    property var zaiTokenUsed: null
    property var zaiTokenLimit: null
    property var zaiTokenResetDate: null
    property string zaiTokenCountdown: ""
    property real zaiToolsPct: 0
    property var zaiToolsRemaining: null
    property var zaiToolsResetDate: null
    property string zaiToolsCountdown: ""
    property var zaiModels: []
    property string zaiError: ""
    // ── GitHub Copilot data ───────────────────────────────────────────────────
    property bool copilotHasKey: false
    property bool copilotKeyValid: false
    property string copilotUsername: ""
    property real copilotUsed: 0
    property real copilotQuota: Plasmoid.configuration.copilotQuota || 300
    property real copilotPct: 0
    property var copilotResetDate: null
    property string copilotCountdown: ""
    property string copilotError: ""
    // ── DeepSeek data ────────────────────────────────────────────────────────
    property bool deepseekHasKey: false
    property bool deepseekKeyValid: false
    property bool deepseekIsAvailable: false
    property var deepseekBalances: []
    property string deepseekPrimaryCurrency: ""
    property real deepseekPrimaryTotal: 0
    property real deepseekPrimaryGranted: 0
    property real deepseekPrimaryToppedUp: 0
    property string deepseekError: ""
    // ── Kimi / Moonshot data ─────────────────────────────────────────────────
    property bool kimiHasKey: false
    property bool kimiKeyValid: false
    property real kimiAvailableBalance: 0
    property real kimiVoucherBalance: 0
    property real kimiCashBalance: 0
    property string kimiError: ""
    // ── Common ────────────────────────────────────────────────────────────────
    property string errorMsg: ""
    property bool stale: false
    property string lastUpdate: ""
    property int backoffMs: 0
    property bool showSettings: false
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
    property string chartGranularity: Plasmoid.configuration.chartGranularity || "7d"
    // Chart ranges per provider, straight from the backend: which history series
    // exist, what each one is called and how wide it is. Keyed by provider id.
    property var providerChartWindows: ({})
    // {t, v} view of the currently-selected chart window
    readonly property var weeklyUsageHistory: {
        var win = root.currentChartWindow();
        if (!win)
            return [];

        var key = win.key;
        var out = [];
        var now_ms = new Date().getTime();
        var winSize = win.size;
        var maxT = now_ms - root.chartTimeOffset;
        var minT = maxT - winSize;
        for (var i = 0; i < root.usageHistory.length; i++) {
            var p = root.usageHistory[i];
            var v = p[key];
            if (v === undefined || v === null)
                continue;

            if (p.t >= minT && p.t <= maxT)
                out.push({
                    "t": p.t,
                    "v": v
                });
        }
        // Redraw quota resets where they actually happened, not where the next
        // poll noticed them (see UsageHistory.withResets).
        if (win.resets)
            out = UsageHistory.withResets(out, win.resetAt * 1000, win.periodMs, minT, maxT);

        // Raw money series store absolute amounts; auto-scale to their own max so the
        // spend curve fills the chart (the canvas expects a 0-100 value).
        if (win.raw && out.length > 0) {
            var maxV = 0;
            for (var j = 0; j < out.length; j++)
                if (out[j].v > maxV) {
                    maxV = out[j].v;
                }
            if (maxV > 0)
                for (var k = 0; k < out.length; k++)
                    out[k] = {
                        "t": out[k].t,
                        "v": (out[k].v / maxV) * 100,
                        "raw": out[k].v
                    };
        }
        return out;
    }
    // ── Tab snapshot export ─────────────────────────────────────────────────
    property string _exportFormat: ""
    property int _exportW: 0
    property int _exportH: 0
    property bool _exportHideHeader: false
    property string historyIOMsg: ""
    // ── Colors ────────────────────────────────────────────────────────────────
    readonly property color claudeOrange: "#cc785c"
    readonly property color googleBlue: "#4285f4"
    readonly property color googleGreen: "#34a853"
    readonly property color openaiGreen: "#10a37f"
    readonly property color kiroPurple: "#8b5cf6"
    readonly property color mistralOrange: "#ff7000"
    readonly property color openrouterPurple: "#9333ea"
    readonly property color grokWhite: "#e6e6e6"
    readonly property color zaiBlue: "#126ef4"
    readonly property color copilotPurple: "#8b5cf6"
    readonly property color deepseekBlue: "#4f8cff"
    readonly property color kimiBlue: "#1e3a8a"
    readonly property color sessionColor: "#e05252"
    readonly property color weeklyColor: "#f5a623"
    readonly property color warningColor: "#ffa64d"
    readonly property color dangerColor: "#ff4d4d"
    // ── Accent (theme-aware) ────────────────────────────────────────────────────
    property bool useThemeAccent: Plasmoid.configuration.useThemeAccent
    // Accent for the currently active tab
    readonly property color activeAccent: root.accentFor(root.enabledTabs[root.activeTab] || "claude")
    // ── Appearance Customization ────────────────────────────────────────────────
    property int backgroundHints: Plasmoid.configuration.backgroundHints !== undefined ? Plasmoid.configuration.backgroundHints : 1
    property color cardBgColor: Plasmoid.configuration.cardBgColor || "#100a1a"
    property real cardBgOpacity: Plasmoid.configuration.cardBgOpacity !== undefined ? Plasmoid.configuration.cardBgOpacity : 0.9
    property color popupBgColor: Plasmoid.configuration.popupBgColor || "#000000"
    property real popupBgOpacity: Plasmoid.configuration.popupBgOpacity !== undefined ? Plasmoid.configuration.popupBgOpacity : 0
    readonly property color resolvedCardBg: {
        var c = Qt.color(root.cardBgColor);
        return Qt.rgba(c.r, c.g, c.b, root.cardBgOpacity);
    }
    readonly property color resolvedPopupBg: {
        var c = Qt.color(root.popupBgColor);
        return Qt.rgba(c.r, c.g, c.b, root.popupBgOpacity);
    }
    property string colorTarget: "popup"
    // ── Pin (active tab stays the default) ─────────────────────────────────────
    property string pinnedTab: Plasmoid.configuration.pinnedTab || ""
    readonly property var pinnedTabs: {
        var pins = [];
        var raw = root.pinnedTab || "";
        var parts = raw.split(",");
        for (var i = 0; i < parts.length; i++) {
            var tab = parts[i].trim();
            if (tab !== "" && root.enabledTabs.indexOf(tab) >= 0 && pins.indexOf(tab) < 0)
                pins.push(tab);
        }
        return pins;
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
    // ── Timers ────────────────────────────────────────────────────────────────
    // Poll interval is user-configurable (seconds); default 300s. Clamp to a sane floor.
    property int pollIntervalSec: Plasmoid.configuration.pollIntervalSec || 300

    function shellQuote(s) {
        return Shell.quote(s);
    }

    function scriptPath(name) {
        return root.shellQuote([root.scriptDir, name].join(""));
    }

    // Chart ranges the backend reported for a provider, newest snapshot wins.
    function chartWindowsFor(tab) {
        return root.providerChartWindows[tab] || [];
    }

    // The range currently selected on the active tab, or null when the provider
    // has no chartable series (or has not been fetched yet).
    function currentChartWindow() {
        var windows = root.chartWindowsFor(root.enabledTabs[root.activeTab] || "");
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].id === root.chartWindow)
                return windows[i];
        }
        return windows.length > 0 ? windows[windows.length - 1] : null;
    }

    // Window ID for a tab at the remembered granularity, so the selected time
    // range carries across services. Providers with a single fixed range return
    // that one; an unknown tab keeps the current selection.
    function _windowForTab(tab, gran) {
        var windows = root.chartWindowsFor(tab);
        if (windows.length === 0)
            return root.chartWindow;

        for (var i = 0; i < windows.length; i++) {
            if (windows[i].granularity === gran)
                return windows[i].id;
        }
        return windows[windows.length - 1].id;
    }

    // Called after a provider refresh: if the selected range vanished (a plan
    // window the provider stopped reporting), fall back to a range it still has.
    function ensureAvailableChartWindow(provider) {
        if (root.enabledTabs[root.activeTab] !== provider)
            return;

        var windows = root.chartWindowsFor(provider);
        if (windows.length === 0)
            return;

        for (var i = 0; i < windows.length; i++) {
            if (windows[i].id === root.chartWindow)
                return;
        }

        var fallback = windows[windows.length - 1];
        root.chartWindow = fallback.id;
        Plasmoid.configuration.chartWindow = root.chartWindow;
        if (fallback.granularity !== "") {
            root.chartGranularity = fallback.granularity;
            Plasmoid.configuration.chartGranularity = root.chartGranularity;
        }
    }

    function _historyKey() {
        var win = root.currentChartWindow();
        return win ? win.key : "";
    }

    function getChartWindowSize() {
        var win = root.currentChartWindow();
        return win ? win.size : 7 * 24 * 3.6e+06;
    }

    function getChartRangeText() {
        var now_ms = new Date().getTime();
        var offset = root.chartTimeOffset;
        var winSize = root.getChartWindowSize();
        var maxT = now_ms - offset;
        var minT = maxT - winSize;
        var minDate = new Date(minT);
        var maxDate = new Date(maxT);
        var isHourly = winSize <= 24 * 3.6e+06;
        if (isHourly) {
            if (minDate.toDateString() === maxDate.toDateString())
                return Qt.formatDateTime(minDate, "hh:mm") + " - " + Qt.formatDateTime(maxDate, "hh:mm") + " (" + Qt.formatDateTime(maxDate, "MMM d") + ")";
            else
                return Qt.formatDateTime(minDate, "MMM d, hh:mm") + " - " + Qt.formatDateTime(maxDate, "MMM d, hh:mm");
        } else {
            return Qt.formatDateTime(minDate, "MMM d") + " - " + Qt.formatDateTime(maxDate, "MMM d");
        }
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
                var migrated = UsageHistory.normalize(JSON.parse(legacy), root.historyLimit);
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

    // Merge one provider's history values into the shared series. The backend
    // decides which keys a provider contributes (see historyValues in the
    // contract), so the frontend never has to know a provider's chart series.
    function recordHistoryValues(values) {
        var history = UsageHistory.merge(root.usageHistory, values, new Date().getTime(), root.historyLimit);
        if (history === root.usageHistory)
            return;

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        // Mirror to a file so history survives a full uninstall/reinstall.
        root.autosaveHistory(json);
    }

    // Silently mirror history JSON to ~/.local/share/ai-usage-widget/usage-history-latest.json
    function autosaveHistory(json) {
        var cmd = root.pythonEnv() + "WIDGET_HISTORY_JSON=\"$(printf %s '" + root.base64(json) + "' | base64 -d)\" " + root.scriptPath("history-io") + " autosave";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    // Restore from the mirror file when plasmoid config has no history (e.g. fresh install).
    function autoloadHistory() {
        var cmd = root.pythonEnv() + root.scriptPath("history-io") + " autoload";
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
                "t": pts[i].t,
                "v": v
            });
        }
        if (n && out.length > n)
            out = out.slice(out.length - n);

        return out;
    }

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
                var cmd = "mkdir -p \"$HOME/Downloads\" && " + root.pythonEnv() + root.scriptPath("export-snapshot") + " " + root.shellQuote(format) + " " + root.shellQuote(tmpPng) + " \"" + destPath + "\"";
                if (format === "svg")
                    cmd += " " + root._exportW + " " + root._exportH;

                cmd += " && notify-send 'AI Usage Widget' 'Saved to ~/Downloads/" + baseName + "." + format + "'";
                exportSaveSource.disconnectSource(cmd);
                exportSaveSource.connectSource(cmd);
            });
        });
    }

    function exportHistory() {
        var json = JSON.stringify(root.usageHistory);
        // Pass the payload base64-encoded and decode it inside the shell, so the JSON
        // (quotes, brackets) never has to survive command-line quoting.
        var cmd = root.pythonEnv() + "WIDGET_HISTORY_JSON=\"$(printf %s '" + root.base64(json) + "' | base64 -d)\" " + root.scriptPath("history-io") + " export";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    function importHistory() {
        var cmd = root.pythonEnv() + root.scriptPath("history-io") + " import";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    function tabColor(tabId) {
        if (tabId === "claude")
            return root.claudeOrange;

        if (tabId === "antigravity")
            return root.googleBlue;

        if (tabId === "openai")
            return root.openaiGreen;

        if (tabId === "kiro")
            return root.kiroPurple;

        if (tabId === "mistral")
            return root.mistralOrange;

        if (tabId === "openrouter")
            return root.openrouterPurple;

        if (tabId === "grok")
            return root.grokWhite;

        if (tabId === "zai")
            return root.zaiBlue;

        if (tabId === "copilot")
            return root.copilotPurple;

        if (tabId === "deepseek")
            return root.deepseekBlue;
        if (tabId === "kimi")
            return root.kimiBlue;

        return Kirigami.Theme.textColor;
    }

    function tabName(tabId) {
        if (tabId === "claude")
            return "Claude";

        if (tabId === "antigravity")
            return "Antigravity";

        if (tabId === "openai")
            return "OpenAI";

        if (tabId === "kiro")
            return "Kiro";

        if (tabId === "mistral")
            return "Mistral";

        if (tabId === "openrouter")
            return "OpenRouter";

        if (tabId === "grok")
            return "Grok";

        if (tabId === "zai")
            return "Z.AI";

        if (tabId === "copilot")
            return "Copilot";

        if (tabId === "deepseek")
            return "DeepSeek";
        if (tabId === "kimi")
            return "Kimi";

        return tabId;
    }

    function formatMoney(value, currency) {
        var cur = currency || "";
        var amount = Number(value || 0).toFixed(2);
        if (cur === "USD")
            return "$" + amount;

        if (cur === "CNY")
            return "¥" + amount;

        return amount + (cur ? " " + cur : "");
    }

    // Resolve a service's accent: the Plasma highlight color when theme accent is on,
    // otherwise the service's own brand color.
    // Brand logo for a tab, or "" when the provider has no artwork yet (callers
    // fall back to the plain colour dot).
    function tabIcon(tabId) {
        if (tabId === "claude")
            return Qt.resolvedUrl("../icons/claude-color.svg");

        if (tabId === "antigravity")
            return Qt.resolvedUrl("../icons/antigravity-color.svg");

        if (tabId === "openai")
            return Qt.resolvedUrl("../icons/openai.svg");

        if (tabId === "kiro")
            return Qt.resolvedUrl("../icons/kiro.svg");

        if (tabId === "mistral")
            return Qt.resolvedUrl("../icons/mistral-color.svg");

        if (tabId === "openrouter")
            return Qt.resolvedUrl("../icons/openrouter.svg");

        if (tabId === "grok")
            return Qt.resolvedUrl("../icons/grok.svg");

        if (tabId === "zai")
            return Qt.resolvedUrl("../icons/zai.svg");

        if (tabId === "copilot")
            return Qt.resolvedUrl("../icons/copilot-color.svg");

        if (tabId === "deepseek")
            return Qt.resolvedUrl("../icons/deepseek-color.svg");
        if (tabId === "kimi")
            return Qt.resolvedUrl("../icons/kimi.svg");

        return "";
    }

    function accentFor(tabId) {
        if (root.useThemeAccent)
            return Kirigami.Theme.highlightColor;

        return root.tabColor(tabId);
    }

    function openColorDialog(target, selectedColor) {
        root.colorTarget = target;
        colorDialog.selectedColor = selectedColor;
        colorDialog.open();
    }

    function isPinned(tabId) {
        return root.pinnedTabs.indexOf(tabId) >= 0;
    }

    function panelShows(tabId) {
        return root.pinnedTabs.length > 0 ? root.isPinned(tabId) : root.panelTab === tabId;
    }

    function togglePin(tabId) {
        var pins = root.pinnedTabs.slice();
        var pos = pins.indexOf(tabId);
        if (pos >= 0)
            pins.splice(pos, 1);
        else
            pins.push(tabId);
        root.pinnedTab = pins.join(",");
        Plasmoid.configuration.pinnedTab = root.pinnedTab;
        // When adding a pin, jump the active view to that tab.
        if (pos < 0) {
            var idx = root.enabledTabs.indexOf(tabId);
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
        return slopePerMs * 3.6e+06;
    }

    // ETA text to reach 100% for a series given its current value. Returns "" when
    // not climbing (or climbing too slowly to matter / already full).
    function etaToFull(seriesKey, currentPct) {
        // need a meaningful climb
        // >10 days out: not actionable

        if (currentPct >= 100)
            return "";

        var slope = root.usageSlopePerHour(seriesKey, 6 * 3.6e+06); // last 6h trend
        if (slope === null || slope < 0.5)
            return "";

        var hoursLeft = (100 - currentPct) / slope;
        if (hoursLeft > 240)
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

    // ── Helpers ───────────────────────────────────────────────────────────────
    function formatTokens(n) {
        if (n >= 1e+06)
            return (n / 1e+06).toFixed(2) + "M";

        if (n >= 1000)
            return (n / 1000).toFixed(1) + "K";

        return Math.round(n).toString();
    }

    function formatDuration(ms) {
        if (!ms || ms <= 0)
            return "—";

        var totalMins = Math.floor(ms / 60000);
        var d = Math.floor(totalMins / 1440);
        var h = Math.floor((totalMins % 1440) / 60);
        var m = totalMins % 60;
        var parts = [];
        if (d > 0)
            parts.push(d + "d");

        if (h > 0)
            parts.push(h + "h");

        if (d === 0 && m > 0)
            parts.push(m + "m");

        return parts.length ? parts.join(" ") : "<1m";
    }

    function formatCountdown(targetDate) {
        return Format.countdown(targetDate ? targetDate.getTime() : 0, new Date().getTime());
    }

    function updateCountdowns() {
        root.sessionCountdown = root.formatCountdown(root.sessionResetDate);
        root.weeklyCountdown = root.formatCountdown(root.weeklyResetDate);
        root.antigravityCountdown = root.formatCountdown(root.antigravityResetDate);
        root.codexSessionCountdown = root.formatCountdown(root.codexSessionResetDate);
        root.codexWeeklyCountdown = root.formatCountdown(root.codexWeeklyResetDate);
        root.kiroCountdown = root.formatCountdown(root.kiroResetDate);
        root.zaiTokenCountdown = root.formatCountdown(root.zaiTokenResetDate);
        root.zaiToolsCountdown = root.formatCountdown(root.zaiToolsResetDate);
        root.copilotCountdown = root.formatCountdown(root.copilotResetDate);
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

    // ── Shared provider backend ───────────────────────────────────────────────
    // Everything below only maps the backend's frontend-neutral JSON onto the
    // properties the tabs bind to. No provider API call, response parsing or
    // quota arithmetic lives in this widget any more — see
    // tools/sh/get-ai-usage and docs/provider-contract.md.

    function dateFromEpoch(seconds) {
        if (seconds === null || seconds === undefined || seconds <= 0)
            return null;

        var date = new Date(seconds * 1000);
        return isNaN(date.getTime()) ? null : date;
    }

    function emptyStatus() {
        return {
            "indicator": "",
            "description": "",
            "components": [],
            "incidents": [],
            "latestUpdate": ""
        };
    }

    // Encoding lives in code/Shell.js so it can be unit-tested outside a QML
    // engine (tests/shared-code.test.js) — the widget-config keys used to reach
    // the backend mangled, and nothing here could catch it.
    function base64(text) {
        return Shell.base64(text);
    }

    // base64-encode secrets so shell metacharacters in them can't break out of
    // the command string (decoded back in the env assignment).
    function envAssign(name, value) {
        return Shell.envAssign(name, value);
    }

    // All three shell tools resolve their interpreter through
    // tools/sh/python-interp.sh, which $PYTHON3 overrides. Empty setting means
    // "search PATH", so every command below is unchanged for users who never
    // touch it. Reuses envAssign's base64 round-trip because a path may contain
    // spaces or shell metacharacters.
    function pythonEnv() {
        return root.envAssign("PYTHON3", String(Plasmoid.configuration.pythonPath || "").trim());
    }

    function backendCommand(ids) {
        var env = root.pythonEnv();
        env += root.envAssign("WIDGET_CLAUDE_ADMIN_KEY", Plasmoid.configuration.claudeAdminApiKey);
        env += root.envAssign("WIDGET_OPENAI_API_KEY", Plasmoid.configuration.openaiApiKey);
        env += root.envAssign("WIDGET_MISTRAL_API_KEY", Plasmoid.configuration.mistralApiKey);
        env += root.envAssign("WIDGET_OPENROUTER_API_KEY", Plasmoid.configuration.openrouterApiKey);
        env += root.envAssign("WIDGET_GROK_API_KEY", Plasmoid.configuration.grokApiKey);
        env += root.envAssign("WIDGET_ZAI_TOKEN", Plasmoid.configuration.zaiToken);
        env += root.envAssign("WIDGET_GITHUB_TOKEN", Plasmoid.configuration.githubToken);
        env += root.envAssign("WIDGET_DEEPSEEK_API_KEY", Plasmoid.configuration.deepseekApiKey);
        env += root.envAssign("WIDGET_MOONSHOT_API_KEY", Plasmoid.configuration.moonshotApiKey);
        var quota = parseInt(Plasmoid.configuration.copilotQuota || 300);
        if (isNaN(quota) || quota <= 0)
            quota = 300;

        env += "WIDGET_COPILOT_QUOTA=" + root.shellQuote(quota) + " ";
        return env + root.scriptPath("get-ai-usage") + " --provider " + root.shellQuote(ids.join(","));
    }

    function applySnapshot(text) {
        var snapshot;
        try {
            snapshot = JSON.parse(text);
        } catch (_) {
            root.errorMsg = "usage backend unavailable";
            root.stale = root.lastUpdate !== "";
            return;
        }
        var providers = snapshot.providers || [];
        var active = root.enabledTabs[root.activeTab] || "";
        var activeSeen = false;
        var activeError = "";
        // Assign the map once: QML `property var` only emits a change signal on
        // assignment, never when a key is set in place.
        var windows = {};
        for (var key in root.providerChartWindows)
            windows[key] = root.providerChartWindows[key];

        for (var i = 0; i < providers.length; i++) {
            var provider = providers[i] || {};
            windows[provider.id] = provider.chartWindows || [];
            if (provider.id === active) {
                activeSeen = true;
                activeError = provider.error || "";
            }
        }
        root.providerChartWindows = windows;
        for (var j = 0; j < providers.length; j++)
            root.applyProvider(providers[j] || {});
        root.recordHistoryValues(UsageHistory.collect(providers));
        root.updateCountdowns();
        if (!activeSeen)
            return;

        root.errorMsg = activeError;
        if (activeError === "") {
            root.stale = false;
            root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
            offlineRetryTimer.stop();
            return;
        }
        root.stale = root.lastUpdate !== "";
        if (activeError === "offline") {
            offlineRetryTimer.restart();
        } else if (activeError === "rate limited") {
            root.backoffMs = 300000;
            backoffTimer.interval = root.backoffMs;
            backoffTimer.restart();
        }
    }

    function applyProvider(provider) {
        var details = provider.details || {};
        if (provider.id === "claude")
            root.applyClaude(details);
        else if (provider.id === "openai")
            root.applyOpenAi(details);
        else if (provider.id === "antigravity")
            root.applyAntigravity(details);
        else if (provider.id === "kiro")
            root.applyKiro(details);
        else if (provider.id === "mistral")
            root.applyMistral(details, provider.error || "");
        else if (provider.id === "openrouter")
            root.applyOpenRouter(details, provider.error || "");
        else if (provider.id === "grok")
            root.applyGrok(details, provider.error || "");
        else if (provider.id === "zai")
            root.applyZai(details, provider.error || "");
        else if (provider.id === "copilot")
            root.applyCopilot(details, provider.error || "");
        else if (provider.id === "deepseek")
            root.applyDeepSeek(details, provider.error || "");
        else if (provider.id === "kimi")
            root.applyKimi(details, provider.error || "");
    }

    function applyClaude(d) {
        root.claudeHasOAuth = d.hasOAuth === true;
        root.claudeHasAdminKey = d.hasAdminKey === true;
        root.claudeSubscriptionType = d.subscriptionType || "";
        root.claudeRateLimitTier = d.rateLimitTier || "";
        root.claudeOrganizationUuid = d.organizationUuid || "";
        root.claudeEffortLevel = d.effortLevel || "";
        root.claudeAutoDream = d.autoDream === true;
        var session = d.session || {};
        var weekly = d.weekly || {};
        root.sessionAvailable = session.available === true;
        root.sessionPct = session.pct || 0;
        root.sessionTokensUsed = session.tokensUsed || 0;
        root.sessionTokenLimit = session.tokenLimit || 0;
        root.sessionResetDate = root.dateFromEpoch(session.resetAt);
        root.sessionResetTime = root.sessionResetDate ? Qt.formatTime(root.sessionResetDate, "hh:mm") : "";
        root.weeklyAvailable = weekly.available === true;
        root.weeklyPct = weekly.pct || 0;
        root.weeklyTokensUsed = weekly.tokensUsed || 0;
        root.weeklyTokenLimit = weekly.tokenLimit || 0;
        root.weeklyResetDate = root.dateFromEpoch(weekly.resetAt);
        root.weeklyResetTime = root.weeklyResetDate ? Qt.formatDateTime(root.weeklyResetDate, "MMM d, hh:mm") : "";
        root.claudeExtraTokens = d.extraTokens || 0;
        var extra = d.extraUsage || {};
        root.claudeExtraUsageEnabled = extra.enabled === true;
        root.claudeExtraUsageLimit = extra.limit || 0;
        root.claudeExtraUsageUsed = extra.used || 0;
        root.claudeExtraUsagePct = extra.pct || 0;
        root.claudeExtraUsageCurrency = extra.currency || "USD";
        var org = d.organizationUsage || {};
        root.claudeModels = org.models || ({});
        root.claudeTotalInputTokens = org.totalInputTokens || 0;
        root.claudeTotalOutputTokens = org.totalOutputTokens || 0;
        root.claudeTotalCostUSD = org.totalCostUSD || 0;
        root.claudeStatus = d.status || root.emptyStatus();
        var stats = d.stats || {};
        root.claudeStatsAvailable = stats.available === true;
        root.claudeStatsVersion = stats.version || 0;
        root.claudeStatsTotalMessages = stats.totalMessages || 0;
        root.claudeStatsTotalSessions = stats.totalSessions || 0;
        root.claudeStatsTotalTokens = stats.totalTokens || 0;
        root.claudeStatsTotalCostUSD = stats.totalCostUSD || 0;
        root.claudeStatsTotalToolCalls = stats.totalToolCalls || 0;
        root.claudeStatsTotalWebSearches = stats.totalWebSearches || 0;
        root.claudeStatsFavoriteModel = stats.favoriteModel || "";
        root.claudeStatsFirstDate = stats.firstDate || "";
        root.claudeStatsComputedDate = stats.computedDate || "";
        root.claudeStatsActiveDays = stats.activeDays || 0;
        root.claudeStatsSpanDays = stats.spanDays || 0;
        root.claudeStatsCurrentStreak = stats.currentStreak || 0;
        root.claudeStatsLongestStreak = stats.longestStreak || 0;
        root.claudeStatsLongestSessionMs = stats.longestSessionMs || 0;
        root.claudeStatsLongestSessionMessages = stats.longestSessionMessages || 0;
        root.claudeStatsPeakHour = stats.peakHour === undefined ? -1 : stats.peakHour;
        root.claudeStatsModels = stats.models || ({});
        root.claudeStatsDailyTokens = stats.dailyTokens || [];
        root.ensureAvailableChartWindow("claude");
    }

    function applyOpenAi(d) {
        root.openaiHasApiKey = d.hasApiKey === true;
        root.openaiCodexLoggedIn = d.codexLoggedIn === true;
        root.openaiEmail = d.email || "";
        root.openaiPlanType = d.planType || "";
        root.openaiOrgId = d.orgId || "";
        root.openaiAccountId = d.accountId || "";
        root.openaiAuthMode = d.authMode || "";
        var codex = d.codex || {};
        var session = codex.session || {};
        var weekly = codex.weekly || {};
        root.codexSessionAvailable = session.available === true;
        root.codexSessionPct = session.pct || 0;
        root.codexSessionResetDate = root.dateFromEpoch(session.resetAt);
        root.codexWeeklyAvailable = weekly.available === true;
        root.codexWeeklyPct = weekly.pct || 0;
        root.codexWeeklyResetDate = root.dateFromEpoch(weekly.resetAt);
        root.codexUsageAvailable = codex.available === true;
        root.codexLimitReached = codex.limitReached === true;
        var additional = codex.additional || [];
        var limits = [];
        for (var i = 0; i < additional.length; i++) {
            var entry = additional[i] || {};
            var entrySession = entry.session || {};
            var entryWeekly = entry.weekly || {};
            limits.push({
                "name": entry.name || "",
                "session": {
                    "available": entrySession.available === true,
                    "pct": entrySession.pct || 0,
                    "reset": root.dateFromEpoch(entrySession.resetAt)
                },
                "weekly": {
                    "available": entryWeekly.available === true,
                    "pct": entryWeekly.pct || 0,
                    "reset": root.dateFromEpoch(entryWeekly.resetAt)
                },
                "limit_reached": entry.limitReached === true
            });
        }
        root.codexAdditionalLimits = limits;
        var org = d.organizationUsage || {};
        root.openaiModels = org.models || ({});
        root.openaiTotalInputTokens = org.totalInputTokens || 0;
        root.openaiTotalOutputTokens = org.totalOutputTokens || 0;
        root.openaiTotalCostUSD = org.totalCostUSD || 0;
        root.openaiStatus = d.status || root.emptyStatus();
        var stats = d.stats || {};
        root.codexStatsAvailable = stats.available === true;
        root.codexStatsTotalSessions = stats.totalSessions || 0;
        root.codexStatsTotalMessages = stats.totalMessages || 0;
        root.codexStatsTotalTokens = stats.totalTokens || 0;
        root.codexStatsTotalToolCalls = stats.totalToolCalls || 0;
        root.codexStatsFirstDate = stats.firstDate || "";
        root.codexStatsComputedDate = stats.computedDate || "";
        root.codexStatsActiveDays = stats.activeDays || 0;
        root.codexStatsSpanDays = stats.spanDays || 0;
        root.codexStatsCurrentStreak = stats.currentStreak || 0;
        root.codexStatsLongestStreak = stats.longestStreak || 0;
        root.codexStatsLongestSessionMs = stats.longestSessionMs || 0;
        root.codexStatsLongestSessionMessages = stats.longestSessionMessages || 0;
        root.codexStatsPeakHour = stats.peakHour === undefined ? -1 : stats.peakHour;
        root.codexStatsFavoriteModel = stats.favoriteModel || "";
        root.codexStatsModels = stats.models || ({});
        root.codexStatsDailyTokens = stats.dailyTokens || [];
        root.codexModel = stats.model || "";
        root.codexEffortLevel = stats.effortLevel || "";
        root.ensureAvailableChartWindow("openai");
    }

    function applyAntigravity(d) {
        root.antigravityEmail = d.email || "";
        root.antigravityPlanType = d.planType || "";
        root.antigravityPromptCreditsMonthly = d.promptCreditsMonthly || 0;
        root.antigravityPromptCreditsAvailable = d.promptCreditsAvailable || 0;
        root.antigravityPct = d.pct || 0;
        root.antigravityGooglePct = d.googlePct || 0;
        root.antigravityExternalPct = d.externalPct || 0;
        root.antigravityModels = d.models || ({});
        root.antigravityResetDate = root.dateFromEpoch(d.resetAt);
        root.antigravityResetTime = root.antigravityResetDate ? Qt.formatDateTime(root.antigravityResetDate, "MMM d, hh:mm") : "";
        // Build locally and assign once: QML `property var` only emits a change
        // signal on assignment, never on in-place push().
        var groups = d.groups || [];
        var out = [];
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i] || {};
            var resetDate = root.dateFromEpoch(group.resetAt);
            out.push({
                "key": group.key || "",
                "label": group.label || "",
                "usedPct": group.usedPct || 0,
                "resetDate": resetDate,
                "resetTime": resetDate ? Qt.formatDateTime(resetDate, "MMM d, hh:mm") : "",
                "isExhausted": group.isExhausted === true,
                "models": group.models || []
            });
        }
        root.antigravityGroups = out;
    }

    function applyKiro(d) {
        root.kiroUsageAvailable = d.available === true;
        root.kiroPlanType = d.planType || "";
        root.kiroDisplayName = d.displayName || "Credit";
        root.kiroDisplayNamePlural = d.displayNamePlural || "Credits";
        root.kiroCurrentUsage = d.currentUsage || 0;
        root.kiroUsageLimit = d.usageLimit || 0;
        root.kiroPct = d.pct || 0;
        root.kiroRemaining = d.remaining || 0;
        root.kiroCurrentOverages = d.currentOverages || 0;
        root.kiroOverageCap = d.overageCap || 0;
        root.kiroOverageCharges = d.overageCharges || 0;
        root.kiroOverageRate = d.overageRate || 0;
        root.kiroCurrencyCode = d.currencyCode || "USD";
        root.kiroCurrencySymbol = d.currencySymbol || "$";
        root.kiroResetDate = root.dateFromEpoch(d.resetAt);
        root.kiroResetTime = root.kiroResetDate ? Qt.formatDateTime(root.kiroResetDate, "MMM d, hh:mm") : "";
    }

    function applyMistral(d, error) {
        root.mistralHasKey = d.hasKey === true;
        root.mistralKeyValid = d.keyValid === true;
        root.mistralAvailableModels = d.availableModels || [];
        root.mistralError = error;
        root.mistralStatus = d.status || root.emptyStatus();
        var vibe = d.vibe || {};
        root.mistralVibeSessionCount = vibe.sessionCount || 0;
        root.mistralVibeTotalCost = vibe.totalCost || 0;
        root.mistralVibeTotalTokens = vibe.totalTokens || 0;
        root.mistralVibePromptTokens = vibe.promptTokens || 0;
        root.mistralVibeCompletionTokens = vibe.completionTokens || 0;
        root.mistralVibeTotalSteps = vibe.totalSteps || 0;
        root.mistralVibeToolOk = vibe.toolOk || 0;
        root.mistralVibeToolFail = vibe.toolFail || 0;
        root.mistralVibeActiveModel = vibe.activeModel || "";
        root.mistralVibeRecent = vibe.recent || [];
    }

    function applyOpenRouter(d, error) {
        root.openrouterHasKey = d.hasKey === true;
        root.openrouterKeyValid = d.keyValid === true;
        root.openrouterLabel = d.label || "";
        root.openrouterUsageUSD = d.usageUSD || 0;
        root.openrouterLimitUSD = d.limitUSD === undefined ? null : d.limitUSD;
        root.openrouterLimitRemainingUSD = d.limitRemainingUSD === undefined ? null : d.limitRemainingUSD;
        root.openrouterIsFreeTier = d.isFreeTier === true;
        root.openrouterRateLimit = d.rateLimit || ({});
        root.openrouterError = error;
        root.openrouterStatus = d.status || root.emptyStatus();
    }

    function applyGrok(d, error) {
        root.grokHasKey = d.hasKey === true;
        root.grokLoggedIn = d.loggedIn === true;
        root.grokPct = d.pct || 0;
        root.grokUsed = d.used || 0;
        root.grokMonthlyLimit = d.monthlyLimit || 0;
        root.grokEmail = d.email || "";
        root.grokTeamName = d.teamName || "";
        root.grokTierId = d.tierId || "";
        root.grokBillingPeriodEnd = d.billingPeriodEnd || "";
        root.grokSessionCount = d.sessionCount || 0;
        root.grokTotalTokens = d.totalTokens || 0;
        root.grokTotalToolCalls = d.totalToolCalls || 0;
        root.grokHasBilling = d.hasBilling === true;
        root.grokQuotaKind = d.quotaKind || "";
        root.grokQuotaWindow = d.quotaWindow || "";
        root.grokQuotaExhausted = d.quotaExhausted === true;
        root.grokError = d.billingError || error;
    }

    function applyZai(d, error) {
        root.zaiHasKey = d.hasKey === true;
        root.zaiKeyValid = d.keyValid === true;
        root.zaiLevel = d.level || "";
        var token = d.token || {};
        var tools = d.tools || {};
        root.zaiTokenPct = token.pct || 0;
        root.zaiTokenUsed = token.used === undefined ? null : token.used;
        root.zaiTokenLimit = token.limit === undefined ? null : token.limit;
        root.zaiTokenResetDate = root.dateFromEpoch(token.resetAt);
        root.zaiToolsPct = tools.pct || 0;
        root.zaiToolsRemaining = tools.remaining === undefined ? null : tools.remaining;
        root.zaiToolsResetDate = root.dateFromEpoch(tools.resetAt);
        root.zaiModels = d.models || [];
        root.zaiError = error;
    }

    function applyCopilot(d, error) {
        root.copilotHasKey = d.hasKey === true;
        root.copilotKeyValid = d.keyValid === true;
        root.copilotUsername = d.username || "";
        root.copilotUsed = d.used || 0;
        root.copilotQuota = d.quota === undefined ? (Plasmoid.configuration.copilotQuota || 300) : d.quota;
        root.copilotPct = d.pct || 0;
        root.copilotResetDate = root.dateFromEpoch(d.resetAt);
        root.copilotError = error;
    }

    function applyDeepSeek(d, error) {
        root.deepseekHasKey = d.hasKey === true;
        root.deepseekKeyValid = d.keyValid === true;
        root.deepseekIsAvailable = d.isAvailable === true;
        root.deepseekBalances = d.balances || [];
        root.deepseekPrimaryCurrency = d.primaryCurrency || "";
        root.deepseekPrimaryTotal = d.primaryTotal || 0;
        root.deepseekPrimaryGranted = d.primaryGranted || 0;
        root.deepseekPrimaryToppedUp = d.primaryToppedUp || 0;
        root.deepseekError = error;
    }

    function applyKimi(d, error) {
        root.kimiHasKey = d.hasKey === true;
        root.kimiKeyValid = d.keyValid === true;
        root.kimiAvailableBalance = d.availableBalance || 0;
        root.kimiVoucherBalance = d.voucherBalance || 0;
        root.kimiCashBalance = d.cashBalance || 0;
        root.kimiError = error;
    }

    function refresh() {
        if (root.enabledTabs.length === 0)
            return;

        if (root.backoffMs > 0)
            return;

        if (root.activeTab >= root.enabledTabs.length)
            root.activeTab = 0;

        // The active tab plus every pinned service: those are the only providers
        // whose data is on screen, so those are the only ones worth fetching.
        var ids = [];
        var active = root.enabledTabs[root.activeTab] || "";
        if (active !== "")
            ids.push(active);

        var pins = root.pinnedTabs;
        for (var i = 0; i < pins.length; i++) {
            if (ids.indexOf(pins[i]) < 0)
                ids.push(pins[i]);
        }
        if (ids.length === 0)
            return;

        var cmd = root.backendCommand(ids);
        usageSource.disconnectSource(cmd);
        usageSource.connectSource(cmd);
    }

    Plasmoid.backgroundHints: root.backgroundHints
    toolTipMainText: "AI API Usage"
    toolTipSubText: {
        var lines = [];
        var tab = root.enabledTabs[root.activeTab];
        if (tab === "claude") {
            var fCountdown = root.sessionCountdown === "resetting..." ? " · resetting..." : (root.sessionCountdown ? " (" + root.sessionCountdown + ")" : "");
            var sCountdown = root.weeklyCountdown === "resetting..." ? " · resetting..." : (root.weeklyCountdown ? " (" + root.weeklyCountdown + ")" : "");
            if (root.sessionAvailable) {
                lines.push("Claude 5H: " + Math.round(root.sessionPct) + "%" + fCountdown);
                if (root.sessionTokenLimit > 0)
                    lines.push("  " + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens");
            }

            if (root.weeklyAvailable)
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
            if (root.openaiHasApiKey)
                lines.push("API usage: configured");

            if (root.openaiTotalCostUSD > 0)
                lines.push("API cost (30d): $" + root.openaiTotalCostUSD.toFixed(2));

            if (root.openaiCodexLoggedIn)
                lines.push("Codex: signed in" + (root.openaiEmail ? " as " + root.openaiEmail : ""));

            if (root.codexSessionAvailable)
                lines.push("Codex 5H left: " + Math.round(100 - root.codexSessionPct) + "%" + (root.codexSessionCountdown ? " (resets in " + root.codexSessionCountdown + ")" : ""));

            if (root.codexWeeklyAvailable)
                lines.push("Codex weekly left: " + Math.round(100 - root.codexWeeklyPct) + "%" + (root.codexWeeklyCountdown ? " (resets in " + root.codexWeeklyCountdown + ")" : ""));
            if (root.openaiPlanType)
                lines.push("Plan: " + root.openaiPlanType);

            if (root.openaiCodexLoggedIn && !root.openaiHasApiKey)
                lines.push("API usage needs an OpenAI API key");
        } else if (tab === "kiro") {
            if (root.kiroPlanType)
                lines.push("Plan: " + root.kiroPlanType.toUpperCase());

            if (root.kiroUsageLimit > 0)
                lines.push("Credits: " + root.kiroCurrentUsage.toFixed(2) + " / " + root.kiroUsageLimit.toFixed(0));

            if (root.kiroResetTime)
                lines.push("Resets: " + root.kiroResetTime + (root.kiroCountdown ? " (" + root.kiroCountdown + ")" : ""));

            if (root.kiroCurrentOverages > 0 || root.kiroOverageCharges > 0)
                lines.push("Overage: " + root.kiroCurrencySymbol + root.kiroOverageCharges.toFixed(2));
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
        } else if (tab === "grok") {
            lines.push(root.grokHasBilling ? ("Grok credits: " + Math.round(root.grokPct) + "% used") : "Grok CLI connected; billing quota unavailable");
            if (root.grokTeamName || root.grokEmail)
                lines.push(root.grokTeamName || root.grokEmail);

            if (root.grokBillingPeriodEnd)
                lines.push("Resets: " + root.grokBillingPeriodEnd);

            lines.push(root.grokSessionCount + " local CLI sessions");
            if (root.grokError)
                lines.push("⚠ " + root.grokError);
        } else if (tab === "zai") {
            lines.push("Z.AI tokens: " + Math.round(root.zaiTokenPct) + "%" + (root.zaiTokenCountdown ? " (" + root.zaiTokenCountdown + ")" : ""));
            if (root.zaiTokenUsed !== null && root.zaiTokenLimit !== null && root.zaiTokenLimit > 0)
                lines.push(root.formatTokens(root.zaiTokenUsed) + " / " + root.formatTokens(root.zaiTokenLimit) + " tokens");

            lines.push("Tools: " + Math.round(root.zaiToolsPct) + "%" + (root.zaiToolsCountdown ? " (" + root.zaiToolsCountdown + ")" : ""));
            if (root.zaiToolsRemaining > 0)
                lines.push("Tools left: " + root.zaiToolsRemaining);

            if (root.zaiLevel)
                lines.push("Level: " + root.zaiLevel);

            if (root.zaiModels.length > 0)
                lines.push(root.zaiModels.length + " models available");

            if (root.zaiError)
                lines.push("⚠ " + root.zaiError);
        } else if (tab === "copilot") {
            lines.push("Copilot: " + Math.round(root.copilotPct) + "%" + (root.copilotCountdown ? " (" + root.copilotCountdown + ")" : ""));
            if (root.copilotQuota > 0)
                lines.push(root.copilotUsed + " / " + root.copilotQuota + " requests");

            if (root.copilotUsername)
                lines.push(root.copilotUsername);

            if (root.copilotError)
                lines.push("⚠ " + root.copilotError);
        } else if (tab === "deepseek") {
            if (root.deepseekKeyValid) {
                lines.push("Balance: " + root.formatMoney(root.deepseekPrimaryTotal, root.deepseekPrimaryCurrency));
                lines.push(root.deepseekIsAvailable ? "Available for API calls" : "Balance unavailable");
            }
            if (root.deepseekError)
                lines.push("⚠ " + root.deepseekError);
        }
        if (root.errorMsg !== "")
            lines.push("⚠ " + root.errorMsg);
        else if (root.lastUpdate !== "")
            lines.push("Updated " + root.lastUpdate + (root.stale ? " (stale)" : ""));
        return lines.join("\n");
    }
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
        // A rate limit belongs to the provider that hit it; don't let it keep
        // the tab you just switched to empty.
        root.backoffMs = 0;
        backoffTimer.stop();
    }
    // With one pin, open the popup on that service. With multiple pins, leave the
    // current popup tab alone so the pin list only controls the panel contents.
    onExpandedChanged: {
        if (root.expanded && root.pinnedTabs.length === 1) {
            var idx = root.enabledTabs.indexOf(root.pinnedTabs[0]);
            if (idx >= 0 && idx !== root.activeTab) {
                root.activeTab = idx;
                root.errorMsg = "";
                root.refresh();
            }
        }
    }
    Component.onCompleted: {
        root.loadUsageHistory();
        // Honor the first pinned service on startup by selecting its tab.
        if (root.pinnedTabs.length > 0) {
            var idx = root.enabledTabs.indexOf(root.pinnedTabs[0]);
            if (idx >= 0)
                root.activeTab = idx;
        }
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
                    return;
                // silent mirror, nothing to do
                if (res.path) {
                    root.historyIOMsg = "Exported to " + res.path;
                    return;
                }
                if (res.data) {
                    // array of {t,s,w} (or legacy {t,v}); normalize + persist
                    var norm = UsageHistory.normalize(res.data, root.historyLimit);
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

    ColorDialog {
        id: colorDialog

        title: colorTarget === "popup" ? "Choose Popup Background Color" : "Choose Card Background Color"
        onAccepted: {
            var hex = selectedColor.toString().substring(0, 7);
            if (hex.charAt(0) !== '#')
                hex = '#' + hex;
            // standard hex validation
            if (colorTarget === "popup") {
                Plasmoid.configuration.popupBgColor = hex;
                root.popupBgColor = hex;
            } else {
                Plasmoid.configuration.cardBgColor = hex;
                root.cardBgColor = hex;
            }
        }
    }

    // ── Provider data ────────────────────────────────────────────────────────
    // One source for every provider: the shared backend already returns the
    // active tab's and every pinned service's data in a single document.
    Plasma5Support.DataSource {
        id: usageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            root.applySnapshot((data["stdout"] || "").trim());
        }
    }

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
                        to: 1
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            PanelSlot {
                pct: root.sessionPct
                iconColor: root.sessionColor
                iconSource: Qt.resolvedUrl("../icons/claude-color.svg")
                iconText: "C"
                stale: root.stale && root.panelShows("claude")
                visible: root.panelShows("claude") && root.sessionAvailable
                tooltipText: "Claude 5-hour: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) : "")
            }

            Rectangle {
                visible: root.panelShows("claude") && root.sessionAvailable && root.weeklyAvailable
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }

            PanelSlot {
                pct: root.weeklyPct
                iconColor: root.weeklyColor
                iconSource: Qt.resolvedUrl("../icons/claude-color.svg")
                iconTint: root.weeklyColor
                iconText: "7D"
                stale: root.stale && root.panelShows("claude")
                visible: root.panelShows("claude") && root.weeklyAvailable
                tooltipText: "Claude 7-day: " + Math.round(root.weeklyPct) + "%" + (root.weeklyTokenLimit > 0 ? "\n" + root.formatTokens(root.weeklyTokensUsed) + " / " + root.formatTokens(root.weeklyTokenLimit) : "")
            }

            PanelSlot {
                pct: root.antigravityGooglePct
                iconColor: root.googleBlue
                iconSource: Qt.resolvedUrl("../icons/antigravity-color.svg")
                iconText: "G"
                stale: root.stale && root.panelShows("antigravity")
                visible: root.panelShows("antigravity")
                tooltipText: "Gemini (Google) quota: " + Math.round(root.antigravityGooglePct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }

            Rectangle {
                visible: root.panelShows("antigravity")
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }

            PanelSlot {
                pct: root.antigravityExternalPct
                iconColor: root.googleGreen
                iconSource: Qt.resolvedUrl("../icons/antigravity-color.svg")
                iconTint: root.googleGreen
                iconText: "X"
                stale: root.stale && root.panelShows("antigravity")
                visible: root.panelShows("antigravity")
                tooltipText: "External models quota: " + Math.round(root.antigravityExternalPct) + "%" + (root.antigravityPlanType ? "\nPlan: " + root.antigravityPlanType : "") + (root.antigravityEmail ? "\n" + root.antigravityEmail : "")
            }

            PanelSlot {
                // Preserve the existing API-cost fallback when no plan limit is available.
                pct: root.codexSessionAvailable ? root.codexSessionPct : (root.openaiTotalCostUSD > 0 ? Math.min(100, (root.openaiTotalCostUSD / 10) * 100) : 0)
                iconColor: root.openaiGreen
                iconSource: Qt.resolvedUrl("../icons/openai.svg")
                iconText: "C"
                stale: root.stale && root.panelShows("openai")
                visible: root.panelShows("openai") && (root.codexSessionAvailable || !root.codexUsageAvailable)
                showCost: !root.codexUsageAvailable
                costText: root.openaiTotalCostUSD > 0 ? "$" + root.openaiTotalCostUSD.toFixed(2) : (root.openaiHasApiKey ? "API" : (root.openaiCodexLoggedIn ? "Codex" : "—"))
                tooltipText: "OpenAI" + (root.codexSessionAvailable ? "\nCodex 5h: " + Math.round(100 - root.codexSessionPct) + "% left" : "") + (root.codexWeeklyAvailable ? "\nCodex weekly: " + Math.round(100 - root.codexWeeklyPct) + "% left" : "") + (root.openaiHasApiKey ? "\nAPI usage configured\nCost (30d): $" + root.openaiTotalCostUSD.toFixed(2) + "\nIn: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens) : "\nAPI usage needs an OpenAI API key") + (root.openaiCodexLoggedIn ? "\nCodex signed in" + (root.openaiEmail ? ": " + root.openaiEmail : "") : "")
            }

            Rectangle {
                visible: root.panelShows("openai") && root.codexSessionAvailable && root.codexWeeklyAvailable
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }

            PanelSlot {
                pct: root.codexWeeklyPct
                iconColor: root.openaiGreen
                iconSource: Qt.resolvedUrl("../icons/openai.svg")
                iconTint: root.weeklyColor
                iconText: "7D"
                stale: root.stale && root.panelShows("openai")
                visible: root.panelShows("openai") && root.codexWeeklyAvailable
                showCost: false
                tooltipText: "OpenAI Codex weekly: " + Math.round(100 - root.codexWeeklyPct) + "% left"
            }

            PanelSlot {
                pct: root.kiroPct
                iconColor: root.kiroPurple
                iconSource: Qt.resolvedUrl("../icons/kiro.svg")
                iconText: "K"
                stale: root.stale && root.panelShows("kiro")
                visible: root.panelShows("kiro")
                showCost: !root.kiroUsageAvailable
                costText: root.kiroUsageAvailable ? "" : "—"
                tooltipText: "Kiro" + (root.kiroPlanType ? "\nPlan: " + root.kiroPlanType.toUpperCase() : "") + (root.kiroUsageLimit > 0 ? "\nCredits: " + root.kiroCurrentUsage.toFixed(2) + " / " + root.kiroUsageLimit.toFixed(0) : "") + (root.kiroResetTime ? "\nResets: " + root.kiroResetTime : "")
            }

            PanelSlot {
                pct: 0
                iconColor: root.mistralOrange
                iconSource: Qt.resolvedUrl("../icons/mistral-color.svg")
                iconText: "M"
                stale: root.stale && root.panelShows("mistral")
                visible: root.panelShows("mistral")
                showCost: true
                costText: root.mistralVibeTotalCost > 0 ? "$" + root.mistralVibeTotalCost.toFixed(2) : (root.mistralKeyValid ? "✓ key" : "—")
                tooltipText: "Mistral AI" + (root.mistralKeyValid ? "\nAPI key configured" : "\nNo key set") + (root.mistralVibeTotalCost > 0 ? "\nSpend (vibe): $" + root.mistralVibeTotalCost.toFixed(4) : "") + (root.mistralAvailableModels.length > 0 ? "\n" + root.mistralAvailableModels.length + " models" : "")
            }

            PanelSlot {
                pct: root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0 ? Math.min(100, (root.openrouterUsageUSD / root.openrouterLimitUSD) * 100) : 0
                iconColor: root.openrouterPurple
                iconSource: Qt.resolvedUrl("../icons/openrouter.svg")
                iconText: "OR"
                stale: root.stale && root.panelShows("openrouter")
                visible: root.panelShows("openrouter") && !root.showSettings
                showCost: true
                costText: root.openrouterKeyValid ? (root.openrouterUsageUSD > 0 ? "$" + root.openrouterUsageUSD.toFixed(3) : "✓ key") : "—"
                tooltipText: "OpenRouter" + (root.openrouterLabel ? "\n" + root.openrouterLabel : "") + (root.openrouterUsageUSD > 0 ? "\nUsed: $" + root.openrouterUsageUSD.toFixed(4) : "") + (root.openrouterLimitUSD !== null ? "\nLimit: $" + root.openrouterLimitUSD.toFixed(2) : "")
            }

            PanelSlot {
                pct: root.grokPct
                iconColor: root.grokWhite
                iconSource: Qt.resolvedUrl("../icons/grok.svg")
                iconText: "G"
                stale: root.stale && root.panelShows("grok")
                visible: root.panelShows("grok") && !root.showSettings
                showCost: !root.grokHasBilling
                costText: root.grokHasBilling ? "" : "CLI"
                tooltipText: root.grokHasBilling ? ("Grok credits: " + Math.round(root.grokPct) + "% used" + (root.grokBillingPeriodEnd ? "\nResets: " + root.grokBillingPeriodEnd : "")) : "Grok CLI connected; billing quota is not exposed"
            }

            PanelSlot {
                pct: root.zaiTokenPct
                iconColor: root.zaiBlue
                iconSource: Qt.resolvedUrl("../icons/zai.svg")
                iconText: "Z"
                stale: root.stale && root.panelShows("zai")
                visible: root.panelShows("zai")
                tooltipText: "Z.AI tokens: " + Math.round(root.zaiTokenPct) + "%" + (root.zaiTokenUsed !== null && root.zaiTokenLimit !== null && root.zaiTokenLimit > 0 ? "\n" + root.formatTokens(root.zaiTokenUsed) + " / " + root.formatTokens(root.zaiTokenLimit) + " tokens" : "") + (root.zaiTokenCountdown ? "\nToken reset: " + root.zaiTokenCountdown : "") + "\nTools: " + Math.round(root.zaiToolsPct) + "%" + (root.zaiToolsRemaining > 0 ? "\nTools left: " + root.zaiToolsRemaining : "")
            }

            PanelSlot {
                pct: root.copilotPct
                iconColor: root.copilotPurple
                iconSource: Qt.resolvedUrl("../icons/copilot-color.svg")
                iconText: "CP"
                stale: root.stale && root.panelShows("copilot")
                visible: root.panelShows("copilot")
                tooltipText: "Copilot: " + Math.round(root.copilotPct) + "%" + (root.copilotQuota > 0 ? "\n" + root.copilotUsed + " / " + root.copilotQuota + " requests" : "") + (root.copilotCountdown ? "\nResets: " + root.copilotCountdown : "") + (root.copilotUsername ? "\n" + root.copilotUsername : "")
            }

            PanelSlot {
                pct: 0
                iconColor: root.deepseekBlue
                iconSource: Qt.resolvedUrl("../icons/deepseek-color.svg")
                iconText: "DS"
                stale: root.stale && root.panelShows("deepseek")
                visible: root.panelShows("deepseek")
                showCost: true
                costText: root.deepseekKeyValid ? root.formatMoney(root.deepseekPrimaryTotal, root.deepseekPrimaryCurrency) : "—"
                tooltipText: "DeepSeek" + (root.deepseekKeyValid ? "\nBalance: " + root.formatMoney(root.deepseekPrimaryTotal, root.deepseekPrimaryCurrency) + "\nGranted: " + root.formatMoney(root.deepseekPrimaryGranted, root.deepseekPrimaryCurrency) + "\nTopped up: " + root.formatMoney(root.deepseekPrimaryToppedUp, root.deepseekPrimaryCurrency) : "\nNo API key set")
            }

            PanelSlot {
                pct: 0
                iconColor: root.kimiBlue
                iconSource: Qt.resolvedUrl("../icons/kimi.svg")
                iconText: "K"
                stale: root.stale && root.panelShows("kimi")
                visible: root.panelShows("kimi")
                showCost: true
                costText: root.kimiKeyValid ? root.formatMoney(root.kimiAvailableBalance, "USD") : "—"
                tooltipText: "Kimi / Moonshot" + (root.kimiKeyValid ? "\nBalance: " + root.formatMoney(root.kimiAvailableBalance, "USD") + "\nVoucher: " + root.formatMoney(root.kimiVoucherBalance, "USD") + "\nCash: " + root.formatMoney(root.kimiCashBalance, "USD") : "\nNo Moonshot API key set")
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
            function onActiveTabChanged() {
                relayoutTimer.restart();
            }

            function onShowSettingsChanged() {
                relayoutTimer.restart();
            }

            target: root
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
                        position: 0
                        color: root.tabColor(root.enabledTabs[root.activeTab] || "claude")
                    }

                    GradientStop {
                        position: 1
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

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                GradientStop {
                    position: 0.5
                    color: Qt.rgba(1, 1, 1, 0.04)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.06)
                }
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

                    // Brand logo of the active provider, falling back to the
                    // tinted widget logo for providers without artwork.
                    Image {
                        visible: !root.showSettings && root.tabIcon(root.enabledTabs[root.activeTab] || "claude") !== "" && status !== Image.Error
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        sourceSize.width: 36
                        sourceSize.height: 36
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: root.tabIcon(root.enabledTabs[root.activeTab] || "claude")
                    }

                    Kirigami.Icon {
                        visible: !root.showSettings && root.tabIcon(root.enabledTabs[root.activeTab] || "claude") === ""
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

                            if (tab === "kiro")
                                return "Kiro Usage";

                            if (tab === "mistral")
                                return "Mistral Usage";

                            if (tab === "openrouter")
                                return "OpenRouter Usage";

                            if (tab === "grok")
                                return "Grok Usage";

                            if (tab === "zai")
                                return "Z.AI Usage";

                            if (tab === "copilot")
                                return "Copilot Usage";

                            if (tab === "deepseek")
                                return "DeepSeek Balance";

                            if (tab === "kimi")
                                return "Kimi Balance";

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
                    opacity: hovered ? 1 : 0.6
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

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: root.showSettings ? "arrow-left" : "configure"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: root.showSettings = !root.showSettings
                    opacity: hovered ? 1 : (root.showSettings ? 1 : 0.6)

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
                    opacity: hovered ? 1 : 0.6

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
                        clip: true
                        color: root.activeTab === index ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        border.width: 1
                        border.color: root.activeTab === index ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                        MouseArea {
                            id: tabMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // Only needed when the pill collapsed to icon-only.
                            QQC2.ToolTip.visible: containsMouse && !tabContent.labelFits
                            QQC2.ToolTip.text: root.tabName(modelData)
                            QQC2.ToolTip.delay: 400
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
                            id: tabContent

                            // Centred as before, but width-capped so the content can
                            // never spill past the pill onto its neighbours.
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 14)
                            spacing: 5
                            // Below this the pill drops the label and goes icon-only,
                            // so many enabled providers still fit.
                            readonly property bool labelFits: parent.width > 62

                            Image {
                                Layout.preferredWidth: 13
                                Layout.preferredHeight: 13
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize.width: 26
                                sourceSize.height: 26
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: root.tabIcon(modelData)
                                visible: root.tabIcon(modelData) !== "" && status !== Image.Error
                                opacity: root.activeTab === index ? 1 : 0.5
                            }

                            // Fallback for providers that have no logo yet.
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.alignment: Qt.AlignVCenter
                                radius: 4
                                color: root.tabColor(modelData)
                                opacity: root.activeTab === index ? 1 : 0.5
                                visible: root.tabIcon(modelData) === ""
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                visible: tabContent.labelFits
                                text: root.tabName(modelData)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 12
                                font.bold: root.activeTab === index
                                color: Kirigami.Theme.textColor
                                opacity: root.activeTab === index ? 1 : 0.6
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
                            visible: root.isPinned(modelData) || tabMouse.containsMouse || pinMouse.containsMouse
                            color: root.isPinned(modelData) ? root.tabColor(modelData) : Kirigami.Theme.textColor
                            opacity: root.isPinned(modelData) ? 1 : 0.4

                            MouseArea {
                                id: pinMouse

                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePin(modelData)
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.text: root.isPinned(modelData) ? "Unpin from panel" : "Pin on panel"
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
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

            KiroTab {
                rootItem: root
            }

            MistralTab {
                rootItem: root
            }

            OpenRouterTab {
                rootItem: root
            }

            GrokTab {
                rootItem: root
            }

            ZaiTab {
                rootItem: root
            }

            CopilotTab {
                rootItem: root
            }

            DeepSeekTab {
                rootItem: root
            }

            KimiTab {
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
