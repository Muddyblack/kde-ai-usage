import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid
import "../code/UsageWindows.js" as UsageWindows

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
    // Legacy aliases kept so ClaudeTab still compiles during the transition
    readonly property string claudeApiStatusIndicator: claudeStatus.indicator
    readonly property string claudeApiStatusDescription: claudeStatus.description
    readonly property var claudeApiStatusComponents: claudeStatus.components
    readonly property var claudeApiStatusIncidents: claudeStatus.incidents
    readonly property string claudeApiStatusLatestUpdate: claudeStatus.latestUpdate
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
    property string _claudeToken: ""
    property string _claudeAdminToken: ""
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
    property string _antigravityToken: ""
    property string _antigravityProjectId: ""
    property var antigravityModels: ({})
    property var antigravityGroups: []
    // ── OpenAI data ───────────────────────────────────────────────────────────
    property string _openaiApiKey: ""
    property string _openaiAccessToken: "" // Codex OAuth token (no org key needed)
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
    property var openrouterLimitUSD: null // null = unlimited
    property var openrouterLimitRemainingUSD: null
    property bool openrouterIsFreeTier: false
    property var openrouterRateLimit: ({})
    property string openrouterError: ""
    // ── Grok CLI / xAI data ──────────────────────────────────────────────────
    property string _grokApiKey: ""
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
    property string _zaiToken: ""
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
    property string _githubToken: ""
    property bool copilotKeyValid: false
    property string copilotUsername: ""
    property real copilotUsed: 0
    property real copilotQuota: Plasmoid.configuration.copilotQuota || 300
    property real copilotPct: 0
    property var copilotResetDate: null
    property string copilotCountdown: ""
    property string copilotError: ""
    // ── DeepSeek data ────────────────────────────────────────────────────────
    property string _deepseekApiKey: ""
    property bool deepseekKeyValid: false
    property bool deepseekIsAvailable: false
    property var deepseekBalances: []
    property string deepseekPrimaryCurrency: ""
    property real deepseekPrimaryTotal: 0
    property real deepseekPrimaryGranted: 0
    property real deepseekPrimaryToppedUp: 0
    property string deepseekError: ""
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

            if (p.t >= minT && p.t <= maxT)
                out.push({
                    "t": p.t,
                    "v": v
                });
        }
        // Raw money series store absolute amounts; auto-scale to their own max so the
        // spend curve fills the chart (the canvas expects a 0-100 value).
        if ((key === "mv" || key === "ds") && out.length > 0) {
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
    // ── Pricing (USD per million tokens) ─────────────────────────────────────
    readonly property var claudePricing: ({
            "claude-opus-4": {
                "input": 15,
                "output": 75
            },
            "claude-sonnet-4": {
                "input": 3,
                "output": 15
            },
            "claude-sonnet-3-5": {
                "input": 3,
                "output": 15
            },
            "claude-haiku-4": {
                "input": 0.8,
                "output": 4
            },
            "claude-haiku-3-5": {
                "input": 0.8,
                "output": 4
            },
            "claude-3-5-sonnet-20241022": {
                "input": 3,
                "output": 15
            },
            "claude-3-5-sonnet-20240620": {
                "input": 3,
                "output": 15
            },
            "claude-3-5-haiku-20241022": {
                "input": 0.8,
                "output": 4
            },
            "claude-3-opus-20240229": {
                "input": 15,
                "output": 75
            }
        })
    readonly property var openaiPricing: ({
            "gpt-4o": {
                "input": 2.5,
                "output": 10
            },
            "gpt-4o-2024-11-20": {
                "input": 2.5,
                "output": 10
            },
            "gpt-4o-2024-08-06": {
                "input": 2.5,
                "output": 10
            },
            "gpt-4o-mini": {
                "input": 0.15,
                "output": 0.6
            },
            "gpt-4o-mini-2024-07-18": {
                "input": 0.15,
                "output": 0.6
            },
            "o1": {
                "input": 15,
                "output": 60
            },
            "o1-2024-12-17": {
                "input": 15,
                "output": 60
            },
            "o1-mini": {
                "input": 1.1,
                "output": 4.4
            },
            "o1-mini-2024-09-12": {
                "input": 1.1,
                "output": 4.4
            },
            "o3": {
                "input": 10,
                "output": 40
            },
            "o3-mini": {
                "input": 1.1,
                "output": 4.4
            },
            "o4-mini": {
                "input": 1.1,
                "output": 4.4
            },
            "gpt-4-turbo": {
                "input": 10,
                "output": 30
            },
            "gpt-4-turbo-2024-04-09": {
                "input": 10,
                "output": 30
            },
            "gpt-4": {
                "input": 30,
                "output": 60
            },
            "gpt-4-32k": {
                "input": 60,
                "output": 120
            },
            "gpt-3.5-turbo": {
                "input": 0.5,
                "output": 1.5
            },
            "gpt-3.5-turbo-0125": {
                "input": 0.5,
                "output": 1.5
            },
            "text-embedding-3-small": {
                "input": 0.02,
                "output": 0
            },
            "text-embedding-3-large": {
                "input": 0.13,
                "output": 0
            }
        })
    // ── Timers ────────────────────────────────────────────────────────────────
    // Poll interval is user-configurable (seconds); default 300s. Clamp to a sane floor.
    property int pollIntervalSec: Plasmoid.configuration.pollIntervalSec || 300

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function scriptPath(name) {
        return root.shellQuote([root.scriptDir, name].join(""));
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

        if (tab === "kiro")
            return "kiro";

        if (tab === "antigravity")
            return "antigravity";

        if (tab === "openrouter")
            return "openrouter";

        if (tab === "mistral")
            return "mistral";

        if (tab === "grok")
            return "grok";

        if (tab === "zai")
            return "zai";

        if (tab === "copilot")
            return "copilot";

        if (tab === "deepseek")
            return "deepseek";

        return "weekly";
    }

    function ensureAvailableChartWindow(provider, sessionIsAvailable, weeklyIsAvailable) {
        if (root.enabledTabs[root.activeTab] !== provider)
            return;

        var choices = UsageWindows.chartChoices(provider, sessionIsAvailable, weeklyIsAvailable);
        if (choices.length === 0)
            return;

        for (var i = 0; i < choices.length; i++) {
            if (choices[i].id === root.chartWindow)
                return;
        }

        var fallback = weeklyIsAvailable ? choices[choices.length - 1] : choices[0];
        root.chartWindow = fallback.id;
        root.chartGranularity = root._windowGranularity(fallback.id);
        Plasmoid.configuration.chartWindow = root.chartWindow;
        Plasmoid.configuration.chartGranularity = root.chartGranularity;
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

        if (root.chartWindow === "kiro")
            return "kr";

        if (root.chartWindow === "antigravity")
            return "ag";

        if (root.chartWindow === "openrouter")
            return "or";

        if (root.chartWindow === "mistral")
            return "mv";

        if (root.chartWindow === "grok")
            return "gr";

        if (root.chartWindow === "zai")
            return "za";

        if (root.chartWindow === "copilot")
            return "gh";

        if (root.chartWindow === "deepseek")
            return "ds";

        return "w";
    }

    function getChartWindowSize() {
        var win = root.chartWindow;
        if (win === "session" || win === "codex_primary")
            return 5 * 3.6e+06; // 5 hours in ms

        if (win === "day" || win === "codex_day")
            return 24 * 3.6e+06; // 24 hours in ms

        if (win === "weekly" || win === "codex_weekly")
            return 7 * 24 * 3.6e+06; // 7 days in ms

        if (win === "kiro" || win === "antigravity" || win === "openrouter" || win === "mistral" || win === "grok" || win === "zai" || win === "copilot" || win === "deepseek")
            return 30 * 24 * 3.6e+06; // 30 days in ms

        return 7 * 24 * 3.6e+06;
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
                var old = JSON.parse(legacy);
                var migrated = [];
                for (var i = 0; i < old.length; i++)
                    migrated.push({
                        "t": old[i].t,
                        "w": old[i].v
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

    function recordUsage(sessionPct, weeklyPct, sessionIsAvailable, weeklyIsAvailable) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 60000) {
            var last = history[history.length - 1];
            if (sessionIsAvailable)
                last.s = sessionPct;

            if (weeklyIsAvailable)
                last.w = weeklyPct;

            history[history.length - 1] = last;
        } else {
            var point = {
                "t": now
            };
            if (sessionIsAvailable)
                point.s = sessionPct;

            if (weeklyIsAvailable)
                point.w = weeklyPct;

            history.push(point);
        }
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
                "t": now,
                "ag": pct
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
                "t": now,
                "or": pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordKiroUsage(pct) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.kr = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                "t": now,
                "kr": pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordGrokUsage(pct) {
        pct = Math.max(0, Math.min(100, pct || 0));
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.gr = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                "t": now,
                "gr": pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordZaiUsage(pct) {
        pct = Math.max(0, Math.min(100, pct || 0));
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.za = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                "t": now,
                "za": pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordCopilotUsage(pct) {
        pct = Math.max(0, Math.min(100, pct || 0));
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.gh = pct;
            history[history.length - 1] = last;
        } else {
            history.push({
                "t": now,
                "gh": pct
            });
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);

        root.usageHistory = history;
        var json = JSON.stringify(history);
        Plasmoid.configuration.usageHistory = json;
        root.autosaveHistory(json);
    }

    function recordDeepSeekBalance(amount) {
        amount = Math.max(0, amount || 0);
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            last.ds = amount;
            history[history.length - 1] = last;
        } else {
            history.push({
                "t": now,
                "ds": amount
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
                "t": now,
                "mv": costUSD
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
    function recordCodexUsage(sessionPct, weeklyPct, sessionIsAvailable, weeklyIsAvailable) {
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        // If the last point is recent (<2 min), just patch it in-place.
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            if (sessionIsAvailable)
                last.cp = sessionPct;

            if (weeklyIsAvailable)
                last.cw = weeklyPct;

            history[history.length - 1] = last;
        } else {
            var point = {
                "t": now
            };
            if (sessionIsAvailable)
                point.cp = sessionPct;

            if (weeklyIsAvailable)
                point.cw = weeklyPct;

            history.push(point);
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
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" " + root.scriptPath("history-io") + " autosave";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    // Restore from the mirror file when plasmoid config has no history (e.g. fresh install).
    function autoloadHistory() {
        var cmd = root.scriptPath("history-io") + " autoload";
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
                var cmd = "mkdir -p \"$HOME/Downloads\" && " + root.scriptPath("export-snapshot") + " " + root.shellQuote(format) + " " + root.shellQuote(tmpPng) + " \"" + destPath + "\"";
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
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" " + root.scriptPath("history-io") + " export";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    function importHistory() {
        var cmd = root.scriptPath("history-io") + " import";
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

    function msFromNowToDate(ms) {
        if (ms === null || ms === undefined || ms <= 0)
            return null;

        return new Date(Date.now() + ms);
    }

    function nextMonthResetDate() {
        var now = new Date();
        return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1, 0, 0, 0, 0));
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

    // ── Shared stats helpers (Claude + Codex use the same derivations) ───────
    // `dates` must be sorted ascending YYYY-MM-DD strings.
    function _activityStreaks(dates) {
        var longest = 0, run = 0, previous = null;
        for (var d = 0; d < dates.length; d++) {
            var current = new Date(dates[d] + "T00:00:00");
            run = previous !== null && Math.round((current.getTime() - previous.getTime()) / 86400000) === 1 ? run + 1 : 1;
            longest = Math.max(longest, run);
            previous = current;
        }
        var currentStreak = 0;
        if (dates.length) {
            var last = new Date(dates[dates.length - 1] + "T00:00:00"), today = new Date();
            today.setHours(0, 0, 0, 0);
            if (Math.round((today.getTime() - last.getTime()) / 86400000) <= 1)
                currentStreak = run;
        }
        return {
            longest: longest,
            current: currentStreak
        };
    }

    function _spanDaysSince(firstDate) {
        if (!firstDate)
            return 0;

        var first = new Date(firstDate);
        return isNaN(first.getTime()) ? 0 : Math.max(1, Math.round((Date.now() - first.getTime()) / 86400000) + 1);
    }

    function _peakHour(hourCounts) {
        var peak = -1, peakCount = -1;
        for (var hour in hourCounts) {
            if (hourCounts[hour] > peakCount) {
                peakCount = hourCounts[hour];
                peak = parseInt(hour, 10);
            }
        }
        return peak;
    }

    // Lifetime Codex usage aggregated from ~/.codex/sessions by get-codex-stats.
    function parseCodexStats(raw) {
        root.codexStatsAvailable = false;
        if (!raw)
            return;

        try {
            var s = JSON.parse(raw);
            if (!s || !s.totalSessions)
                return;

            root.codexStatsTotalSessions = s.totalSessions || 0;
            root.codexStatsTotalMessages = s.totalMessages || 0;
            root.codexStatsTotalTokens = s.totalTokens || 0;
            root.codexStatsTotalToolCalls = s.totalToolCalls || 0;
            root.codexStatsFirstDate = s.firstSessionDate || "";
            root.codexStatsComputedDate = s.lastComputedDate || "";
            root.codexStatsLongestSessionMs = (s.longestSession && s.longestSession.duration) || 0;
            root.codexStatsLongestSessionMessages = (s.longestSession && s.longestSession.messageCount) || 0;
            root.codexModel = s.model || "";
            root.codexEffortLevel = s.effortLevel || "";
            var models = {}, favorite = "", favoriteTotal = -1;
            var usage = s.modelUsage || {};
            for (var id in usage) {
                var m = usage[id] || {};
                models[id] = {
                    input: m.inputTokens || 0,
                    output: m.outputTokens || 0,
                    cacheRead: m.cachedInput || 0,
                    reasoning: m.reasoningTokens || 0,
                    total: m.totalTokens || 0,
                    sessions: m.sessions || 0,
                    contextWindow: m.contextWindow || 0
                };
                if (models[id].total > favoriteTotal) {
                    favoriteTotal = models[id].total;
                    favorite = id;
                }
            }
            root.codexStatsModels = models;
            root.codexStatsFavoriteModel = favorite;
            var daily = [], dates = [], dailySource = s.dailyModelTokens || [], activity = s.dailyActivity || [];
            for (var i = 0; i < dailySource.length; i++)
                daily.push({
                    date: (dailySource[i] || {}).date || "",
                    total: (dailySource[i] || {}).total || 0
                });

            daily.sort(function (a, b) {
                return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0);
            });
            root.codexStatsDailyTokens = daily;
            for (var j = 0; j < activity.length; j++)
                if (activity[j] && activity[j].date)
                    dates.push(activity[j].date);

            dates.sort();
            root.codexStatsActiveDays = dates.length;
            root.codexStatsSpanDays = root._spanDaysSince(root.codexStatsFirstDate);
            var streaks = root._activityStreaks(dates);
            root.codexStatsLongestStreak = streaks.longest;
            root.codexStatsCurrentStreak = streaks.current;
            root.codexStatsPeakHour = root._peakHour(s.hourCounts || {});
            root.codexStatsAvailable = true;
        } catch (e) {
            console.log("Codex stats parse error: " + e);
        }
    }

    function parseClaudeStats(raw) {
        root.claudeStatsAvailable = false;
        if (!raw)
            return;
        try {
            var s = JSON.parse(raw);
            root.claudeStatsVersion = s.version || 0;
            root.claudeStatsTotalMessages = s.totalMessages || 0;
            root.claudeStatsTotalSessions = s.totalSessions || 0;
            root.claudeStatsFirstDate = s.firstSessionDate || "";
            root.claudeStatsComputedDate = s.lastComputedDate || "";
            root.claudeStatsLongestSessionMs = (s.longestSession && s.longestSession.duration) || 0;
            root.claudeStatsLongestSessionMessages = (s.longestSession && s.longestSession.messageCount) || 0;
            var models = {}, total = 0, favorite = "", favoriteTotal = -1, cost = 0, searches = 0;
            var usage = s.modelUsage || {};
            for (var id in usage) {
                var m = usage[id] || {}, input = m.inputTokens || 0, output = m.outputTokens || 0;
                var modelTotal = input + output;
                var modelCost = m.costUSD || 0, modelSearches = m.webSearchRequests || 0;
                models[id] = {
                    input: input,
                    output: output,
                    cacheRead: m.cacheReadInputTokens || 0,
                    cacheCreation: m.cacheCreationInputTokens || 0,
                    total: modelTotal,
                    cost: modelCost,
                    webSearches: modelSearches,
                    contextWindow: m.contextWindow || 0
                };
                total += modelTotal;
                cost += modelCost;
                searches += modelSearches;
                if (modelTotal > favoriteTotal) {
                    favoriteTotal = modelTotal;
                    favorite = id;
                }
            }
            root.claudeStatsModels = models;
            root.claudeStatsTotalTokens = total;
            root.claudeStatsTotalCostUSD = cost;
            root.claudeStatsTotalWebSearches = searches;
            root.claudeStatsFavoriteModel = favorite;
            var daily = [], dailySource = s.dailyModelTokens || [];
            for (var i = 0; i < dailySource.length; i++) {
                var day = dailySource[i] || {}, byModel = day.tokensByModel || {}, dayTotal = 0;
                for (var key in byModel)
                    dayTotal += byModel[key] || 0;
                daily.push({
                    date: day.date || "",
                    total: dayTotal
                });
            }
            daily.sort(function (a, b) {
                return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0);
            });
            root.claudeStatsDailyTokens = daily;
            var dates = [], activity = s.dailyActivity || [], toolCalls = 0;
            for (var j = 0; j < activity.length; j++) {
                if (!activity[j])
                    continue;
                if (activity[j].date)
                    dates.push(activity[j].date);
                toolCalls += activity[j].toolCallCount || 0;
            }
            root.claudeStatsTotalToolCalls = toolCalls;
            dates.sort();
            root.claudeStatsActiveDays = dates.length;
            root.claudeStatsSpanDays = root._spanDaysSince(root.claudeStatsFirstDate);
            var streaks = root._activityStreaks(dates);
            root.claudeStatsLongestStreak = streaks.longest;
            root.claudeStatsCurrentStreak = streaks.current;
            root.claudeStatsPeakHour = root._peakHour(s.hourCounts || {});
            root.claudeStatsAvailable = true;
        } catch (e) {
            console.log("Claude stats parse error: " + e);
        }
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

    function loadCreds(tabOverride) {
        var tab = tabOverride || root.enabledTabs[root.activeTab];
        if (tab === "claude") {
            var cfgKey = Plasmoid.configuration.claudeAdminApiKey || "";
            // base64-encode the key so shell metacharacters in it can't break out
            // of the command string (decoded back in the env assignment).
            var envPrefix = cfgKey ? "WIDGET_CLAUDE_ADMIN_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-claude-credentials");
            credSource.disconnectSource(cmd);
            credSource.connectSource(cmd);
            // Read effort level + dream mode from ~/.claude/settings.json
            var settingsCmd = "cat \"$HOME/.claude/settings.json\" 2>/dev/null || echo '{}'";
            claudeSettingsSource.disconnectSource(settingsCmd);
            claudeSettingsSource.connectSource(settingsCmd);
            var statsCmd = "cat \"$HOME/.claude/stats-cache.json\" 2>/dev/null || echo ''";
            claudeStatsSource.disconnectSource(statsCmd);
            claudeStatsSource.connectSource(statsCmd);
        } else if (tab === "antigravity") {
            var cmd = root.scriptPath("get-antigravity-usage");
            antigravityUsageSource.disconnectSource(cmd);
            antigravityUsageSource.connectSource(cmd);
        } else if (tab === "openai") {
            var cfgKey = Plasmoid.configuration.openaiApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENAI_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-openai-usage");
            openaiCredSource.disconnectSource(cmd);
            openaiCredSource.connectSource(cmd);
            var codexStatsCmd = root.scriptPath("get-codex-stats");
            codexStatsSource.disconnectSource(codexStatsCmd);
            codexStatsSource.connectSource(codexStatsCmd);
        } else if (tab === "kiro") {
            var cmd = root.scriptPath("get-kiro-usage");
            kiroUsageSource.disconnectSource(cmd);
            kiroUsageSource.connectSource(cmd);
        } else if (tab === "mistral") {
            var cfgKey = Plasmoid.configuration.mistralApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_MISTRAL_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-mistral-usage");
            mistralCredSource.disconnectSource(cmd);
            mistralCredSource.connectSource(cmd);
        } else if (tab === "openrouter") {
            var cfgKey = Plasmoid.configuration.openrouterApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENROUTER_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-openrouter-usage");
            openrouterCredSource.disconnectSource(cmd);
            openrouterCredSource.connectSource(cmd);
        } else if (tab === "grok") {
            var cfgKey = Plasmoid.configuration.grokApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_GROK_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-grok-usage");
            grokUsageSource.disconnectSource(cmd);
            grokUsageSource.connectSource(cmd);
        } else if (tab === "zai") {
            var cfgKey = Plasmoid.configuration.zaiToken || "";
            var envPrefix = cfgKey ? "WIDGET_ZAI_TOKEN=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-zai-usage");
            zaiUsageSource.disconnectSource(cmd);
            zaiUsageSource.connectSource(cmd);
        } else if (tab === "copilot") {
            var cfgKey = Plasmoid.configuration.githubToken || "";
            var quota = parseInt(Plasmoid.configuration.copilotQuota || 300);
            if (isNaN(quota) || quota <= 0)
                quota = 300;

            var envPrefix = cfgKey ? "WIDGET_GITHUB_TOKEN=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + "WIDGET_COPILOT_QUOTA=\"" + quota + "\" " + root.scriptPath("get-copilot-usage");
            copilotUsageSource.disconnectSource(cmd);
            copilotUsageSource.connectSource(cmd);
        } else if (tab === "deepseek") {
            var cfgKey = Plasmoid.configuration.deepseekApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_DEEPSEEK_API_KEY=\"$(printf %s '" + Qt.btoa(cfgKey) + "' | base64 -d)\" " : "";
            var cmd = envPrefix + root.scriptPath("get-deepseek-balance");
            deepseekBalanceSource.disconnectSource(cmd);
            deepseekBalanceSource.connectSource(cmd);
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
                    var normalized = UsageWindows.normalizeClaude(d);
                    var f = d.five_hour || {};
                    var s = d.seven_day || {};
                    root.sessionAvailable = normalized.session.available;
                    root.sessionPct = normalized.session.pct;
                    root.sessionTokensUsed = f.tokens_used || 0;
                    root.sessionTokenLimit = f.token_limit || 0;
                    root.weeklyAvailable = normalized.weekly.available;
                    root.weeklyPct = normalized.weekly.pct;
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
                    root.sessionResetDate = root.normalizedResetDate(normalized.session.resetAt);
                    root.sessionResetTime = root.sessionResetDate ? Qt.formatTime(root.sessionResetDate, "hh:mm") : "";
                    root.weeklyResetDate = root.normalizedResetDate(normalized.weekly.resetAt);
                    root.weeklyResetTime = root.weeklyResetDate ? Qt.formatDateTime(root.weeklyResetDate, "MMM d, hh:mm") : "";
                    root.ensureAvailableChartWindow("claude", root.sessionAvailable, root.weeklyAvailable);
                    root.updateCountdowns();
                    root.errorMsg = "";
                    root.stale = false;
                    root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                    root._offline = false;
                    offlineRetryTimer.stop();
                    if (root.sessionAvailable || root.weeklyAvailable)
                        root.recordUsage(root.sessionPct, root.weeklyPct, root.sessionAvailable, root.weeklyAvailable);
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
                            "input_tokens": 0,
                            "output_tokens": 0,
                            "cost_usd": 0,
                            "priced": false
                        };

                    models[modelName].input_tokens += inTok;
                    models[modelName].output_tokens += outTok;
                    var pricing = root.claudePricing[modelName];
                    if (pricing) {
                        models[modelName].cost_usd += (inTok / 1e+06) * pricing.input + (outTok / 1e+06) * pricing.output;
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
                                "input_tokens": 0,
                                "output_tokens": 0,
                                "cost_usd": 0,
                                "priced": false
                            };

                        models[modelName].input_tokens += inTok;
                        models[modelName].output_tokens += outTok;
                        var pricing = root.openaiPricing[modelName];
                        if (pricing) {
                            models[modelName].cost_usd += (inTok / 1e+06) * pricing.input + (outTok / 1e+06) * pricing.output;
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
    // Uses the local Codex app-server first, with the authenticated web endpoint
    // retained as a fallback. This is separate from OpenAI API org billing.
    function normalizedResetDate(resetAt) {
        if (resetAt === null || resetAt === undefined || resetAt === "")
            return null;

        var date = new Date(resetAt);
        return isNaN(date.getTime()) ? null : date;
    }

    function applyCodexUsage(payload) {
        var normalized = UsageWindows.normalizeCodex(payload);
        root.codexSessionAvailable = normalized.session.available;
        root.codexSessionPct = normalized.session.pct;
        root.codexSessionResetDate = root.normalizedResetDate(normalized.session.resetAt);
        root.codexWeeklyAvailable = normalized.weekly.available;
        root.codexWeeklyPct = normalized.weekly.pct;
        root.codexWeeklyResetDate = root.normalizedResetDate(normalized.weekly.resetAt);
        root.codexUsageAvailable = root.codexSessionAvailable || root.codexWeeklyAvailable;
        root.ensureAvailableChartWindow("openai", root.codexSessionAvailable, root.codexWeeklyAvailable);

        var main = payload.rateLimits || payload.rate_limit || {};
        if (main.planType)
            root.openaiPlanType = main.planType;
        else if (payload.plan_type)
            root.openaiPlanType = payload.plan_type;

        root.codexLimitReached = main.limit_reached === true || (main.rateLimitReachedType !== null && main.rateLimitReachedType !== undefined);
        var parsedAdditional = [];
        for (var i = 0; i < normalized.additional.length; i++) {
            var entry = normalized.additional[i];
            parsedAdditional.push({
                "name": entry.name,
                "session": {
                    "available": entry.session.available,
                    "pct": entry.session.pct,
                    "reset": root.normalizedResetDate(entry.session.resetAt)
                },
                "weekly": {
                    "available": entry.weekly.available,
                    "pct": entry.weekly.pct,
                    "reset": root.normalizedResetDate(entry.weekly.resetAt)
                },
                "limit_reached": entry.limitReached
            });
        }
        root.codexAdditionalLimits = parsedAdditional;
        root.updateCountdowns();

        if (root.codexUsageAvailable) {
            root.recordCodexUsage(root.codexSessionPct, root.codexWeeklyPct, root.codexSessionAvailable, root.codexWeeklyAvailable);
            root.errorMsg = "";
            root.stale = false;
            root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
        }

        return root.codexUsageAvailable;
    }

    function fetchCodexUsage() {
        if (!root.openaiCodexLoggedIn)
            return;

        var cmd = root.scriptPath("get-codex-rate-limits");
        codexUsageSource.disconnectSource(cmd);
        codexUsageSource.connectSource(cmd);
    }

    function fetchCodexUsageFromWeb() {
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
                root.codexSessionAvailable = false;
                root.codexWeeklyAvailable = false;
                return;
            }
            try {
                var d = JSON.parse(xhr.responseText);
                root.applyCodexUsage(d);
            } catch (e) {
                root.codexUsageAvailable = false;
                root.codexSessionAvailable = false;
                root.codexWeeklyAvailable = false;
            }
        };
        xhr.send();
    }

    // ── Service status (Statuspage JSON API) ─────────────────────────────────
    // Parses a Statuspage /api/v2/summary.json response and calls setter(obj).
    function _fetchStatusPage(url, setter) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200)
                return;

            try {
                var d = JSON.parse(xhr.responseText);
                var indicator = (d.status || {}).indicator || "none";
                var description = (d.status || {}).description || "";
                // Non-operational components (skip group parent rows)
                var comps = d.components || [];
                var affectedComps = [];
                for (var c = 0; c < comps.length; c++) {
                    var comp = comps[c];
                    if (comp.status && comp.status !== "operational" && !comp.group)
                        affectedComps.push((comp.name || "") + " (" + comp.status.replace(/_/g, " ") + ")");
                }
                // Active incidents + most recent update body
                var inc = d.incidents || [];
                var activeNames = [];
                var latestBody = "";
                for (var i = 0; i < inc.length; i++) {
                    var incident = inc[i];
                    if (incident.status === "resolved")
                        continue;

                    activeNames.push(incident.name || "");
                    if (!latestBody) {
                        var updates = incident.incident_updates || [];
                        if (updates.length > 0) {
                            var body = (updates[0].body || "").trim();
                            latestBody = body.length > 200 ? body.substring(0, 197) + "…" : body;
                        }
                    }
                }
                setter({
                    "indicator": indicator,
                    "description": description,
                    "components": affectedComps,
                    "incidents": activeNames,
                    "latestUpdate": latestBody
                });
            } catch (_) {}
        };
        xhr.send();
    }

    function fetchClaudeStatus() {
        root._fetchStatusPage("https://status.claude.com/api/v2/summary.json", function (s) {
            root.claudeStatus = s;
        });
    }

    function fetchMistralStatus() {
        root._fetchStatusPage("https://status.mistral.ai/api/v2/summary.json", function (s) {
            root.mistralStatus = s;
        });
    }

    function fetchOpenAIStatus() {
        root._fetchStatusPage("https://status.openai.com/api/v2/summary.json", function (s) {
            root.openaiStatus = s;
        });
    }

    function fetchOpenRouterStatus() {
        root._fetchStatusPage("https://status.openrouter.ai/api/v2/summary.json", function (s) {
            root.openrouterStatus = s;
        });
    }

    function fetchAllStatuses() {
        root.fetchClaudeStatus();
        root.fetchMistralStatus();
        root.fetchOpenAIStatus();
        root.fetchOpenRouterStatus();
    }

    function refresh() {
        if (root.enabledTabs.length === 0)
            return;

        if (root.activeTab >= root.enabledTabs.length)
            root.activeTab = 0;

        loadCreds();
        var active = root.enabledTabs[root.activeTab] || "";
        var pins = root.pinnedTabs;
        for (var i = 0; i < pins.length; i++) {
            if (pins[i] !== active)
                loadCreds(pins[i]);
        }
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
            if (root._openaiApiKey)
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

            if (root.openaiCodexLoggedIn && !root._openaiApiKey)
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
                    var arr = res.data;
                    var norm = [];
                    for (var i = 0; i < arr.length; i++) {
                        var p = arr[i];
                        if (p.t === undefined)
                            continue;

                        if (p.w === undefined && p.v !== undefined)
                            norm.push({
                                "t": p.t,
                                "w": p.v
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

    // ── Credentials ──────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: credSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "claude" && !root.panelShows("claude"))
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
                root.sessionAvailable = false;
                root.weeklyAvailable = false;
                root.sessionPct = 0;
                root.weeklyPct = 0;
                root.sessionTokenLimit = 0;
                root.weeklyTokenLimit = 0;
                fetchClaudeApiUsage();
                root.errorMsg = "OAuth missing — API stats only";
            } else {
                root.sessionAvailable = false;
                root.weeklyAvailable = false;
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
        id: claudeStatsSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            root.parseClaudeStats((data["stdout"] || "").trim());
        }
    }

    Plasma5Support.DataSource {
        id: codexStatsSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            root.parseCodexStats((data["stdout"] || "").trim());
        }
    }

    Plasma5Support.DataSource {
        id: antigravityUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "antigravity" && !root.panelShows("antigravity"))
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
                var groupAcc = {
                    gemini: {
                        key: "gemini",
                        label: "Gemini Models",
                        used: 0,
                        count: 0,
                        resetDate: null,
                        isExhausted: false,
                        models: []
                    },
                    external: {
                        key: "external",
                        label: "Claude & GPT Models",
                        used: 0,
                        count: 0,
                        resetDate: null,
                        isExhausted: false,
                        models: []
                    }
                };
                for (var i = 0; i < modelsList.length; i++) {
                    var m = modelsList[i];
                    var remaining = m.remainingPercentage !== undefined ? m.remainingPercentage : -1;
                    var usedPct = remaining !== -1 ? Math.max(0, Math.min(100, (1 - remaining) * 100)) : 0;
                    newModels[m.modelId] = {
                        "displayName": m.label || m.modelId,
                        "usedPct": usedPct,
                        "resetTime": m.resetTime || "",
                        "isExhausted": !!m.isExhausted,
                        "hasQuota": remaining !== -1
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
                        var family = (name.indexOf("gemini") !== -1 || name.indexOf("google") !== -1) ? "gemini" : "external";
                        groupAcc[family].used += usedPct;
                        groupAcc[family].count++;
                    } else {
                        var family = ((m.label || m.modelId).toLowerCase().indexOf("gemini") !== -1 || (m.label || m.modelId).toLowerCase().indexOf("google") !== -1) ? "gemini" : "external";
                    }
                    groupAcc[family].models.push(m.modelId);
                    if (m.isExhausted)
                        groupAcc[family].isExhausted = true;
                    if (m.resetTime) {
                        var rd = new Date(m.resetTime);
                        if (!isNaN(rd.getTime())) {
                            if (earliestReset === null || rd < earliestReset)
                                earliestReset = rd;
                            if (groupAcc[family].resetDate === null || rd < groupAcc[family].resetDate)
                                groupAcc[family].resetDate = rd;
                        }
                    }
                }
                root.antigravityModels = newModels;
                root.antigravityPct = modelCount > 0 ? totalUsed / modelCount : 0;
                root.antigravityGooglePct = googleCount > 0 ? googleUsed / googleCount : 0;
                root.antigravityExternalPct = externalCount > 0 ? externalUsed / externalCount : 0;
                // Build locally and assign once: QML `property var` only emits a
                // change signal on assignment, never on in-place push().
                var groupsOut = [];
                ["gemini", "external"].forEach(function (key) {
                    var group = groupAcc[key];
                    if (group.models.length > 0)
                        groupsOut.push({
                            key: key,
                            label: group.label,
                            usedPct: group.count > 0 ? group.used / group.count : 0,
                            resetDate: group.resetDate,
                            resetTime: group.resetDate ? Qt.formatDateTime(group.resetDate, "MMM d, hh:mm") : "",
                            isExhausted: group.isExhausted,
                            models: group.models.sort()
                        });
                });
                root.antigravityGroups = groupsOut;
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
            if (root.enabledTabs[root.activeTab] !== "openai" && !root.panelShows("openai"))
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
        id: codexUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "openai" && !root.panelShows("openai"))
                return;

            try {
                var payload = JSON.parse((data["stdout"] || "").trim() || "{}");
                if (!root.applyCodexUsage(payload))
                    root.fetchCodexUsageFromWeb();
            } catch (_) {
                root.fetchCodexUsageFromWeb();
            }
        }
    }

    Plasma5Support.DataSource {
        id: kiroUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "kiro" && !root.panelShows("kiro"))
                return;

            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root.kiroUsageAvailable = false;
                root.errorMsg = "Kiro: no local usage data found";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error) {
                    root.kiroUsageAvailable = false;
                    root.errorMsg = "Kiro: " + res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root.kiroPlanType = res.planType || "";
                root.kiroDisplayName = res.displayName || "Credit";
                root.kiroDisplayNamePlural = res.displayNamePlural || "Credits";
                root.kiroCurrentUsage = res.currentUsage || 0;
                root.kiroUsageLimit = res.usageLimit || 0;
                root.kiroPct = Math.max(0, Math.min(100, res.percentageUsed || 0));
                root.kiroRemaining = res.remaining || 0;
                root.kiroCurrentOverages = res.currentOverages || 0;
                root.kiroOverageCap = res.overageCap || 0;
                root.kiroOverageCharges = res.overageCharges || 0;
                root.kiroOverageRate = res.overageRate || 0;
                root.kiroCurrencyCode = res.currencyCode || "USD";
                root.kiroCurrencySymbol = res.currencySymbol || "$";
                root.kiroResetDate = res.resetDate ? new Date(res.resetDate) : null;
                root.kiroResetTime = root.kiroResetDate ? Qt.formatDateTime(root.kiroResetDate, "MMM d, hh:mm") : "";
                root.kiroUsageAvailable = root.kiroUsageLimit > 0 || root.kiroCurrentUsage > 0;
                root.updateCountdowns();
                root.errorMsg = root.kiroUsageAvailable ? "" : "Kiro: usage snapshot is empty";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                if (root.kiroUsageAvailable)
                    root.recordKiroUsage(root.kiroPct);
            } catch (e) {
                root.kiroUsageAvailable = false;
                root.errorMsg = "Kiro: parse error";
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
            if (root.enabledTabs[root.activeTab] !== "mistral" && !root.panelShows("mistral"))
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
            if (root.enabledTabs[root.activeTab] !== "openrouter" && !root.panelShows("openrouter"))
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

    Plasma5Support.DataSource {
        id: grokUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "grok" && !root.panelShows("grok"))
                return;

            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root.grokLoggedIn = false;
                root.errorMsg = "Grok: run grok --oauth or configure an xAI key";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                root._grokApiKey = res.xaiApiKey || "";
                root.grokLoggedIn = res.loggedIn === true;
                root.grokPct = Math.max(0, Math.min(100, res.creditUsagePercent || 0));
                root.grokUsed = res.used || res.onDemandUsed || 0;
                root.grokMonthlyLimit = res.monthlyLimit || res.onDemandCap || 0;
                root.grokEmail = res.email || "";
                root.grokTeamName = res.teamName || "";
                root.grokTierId = res.tierId || "";
                root.grokBillingPeriodEnd = res.billingPeriodEnd || "";
                root.grokSessionCount = res.sessionCount || 0;
                root.grokTotalTokens = res.totalTokens || 0;
                root.grokTotalToolCalls = res.totalToolCalls || 0;
                root.grokError = res.billingError || "";
                root.grokHasBilling = res.hasBilling === true;
                root.grokQuotaKind = res.quotaKind || "";
                root.grokQuotaWindow = res.quotaWindow || "";
                root.grokQuotaExhausted = res.quotaExhausted === true;
                root.errorMsg = root.grokError;
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                if (root.grokHasBilling)
                    root.recordGrokUsage(root.grokPct);
            } catch (e) {
                root.grokError = "Grok: parse error";
                root.errorMsg = "Grok: parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    Plasma5Support.DataSource {
        id: zaiUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "zai" && !root.panelShows("zai"))
                return;

            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root._zaiToken = "";
                root.zaiKeyValid = false;
                root.zaiError = "";
                root.errorMsg = "Z.AI: no token configured";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error) {
                    root._zaiToken = res.zaiToken || "";
                    root.zaiKeyValid = res.keyValid === true;
                    root.zaiError = res.error;
                    root.errorMsg = "Z.AI: " + res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root._zaiToken = res.zaiToken || "";
                root.zaiKeyValid = res.keyValid === true;
                root.zaiLevel = res.level || "";
                root.zaiTokenPct = Math.max(0, Math.min(100, res.tokenPct || 0));
                root.zaiTokenUsed = res.tokenUsed !== undefined && res.tokenUsed !== null ? res.tokenUsed : null;
                root.zaiTokenLimit = res.tokenLimit !== undefined && res.tokenLimit !== null ? res.tokenLimit : null;
                root.zaiTokenResetDate = root.msFromNowToDate(res.tokenResetMs);
                root.zaiToolsPct = Math.max(0, Math.min(100, res.toolsPct || 0));
                root.zaiToolsRemaining = res.toolsRemaining !== undefined && res.toolsRemaining !== null ? res.toolsRemaining : null;
                root.zaiToolsResetDate = root.msFromNowToDate(res.toolsResetMs);
                root.zaiModels = res.models || [];
                root.zaiError = "";
                root.updateCountdowns();
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                root.recordZaiUsage(root.zaiTokenPct);
            } catch (e) {
                root.zaiError = "Z.AI: parse error";
                root.errorMsg = "Z.AI: parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    Plasma5Support.DataSource {
        id: copilotUsageSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "copilot" && !root.panelShows("copilot"))
                return;

            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root._githubToken = "";
                root.copilotKeyValid = false;
                root.copilotError = "";
                root.errorMsg = "Copilot: no token configured";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error) {
                    root._githubToken = res.githubToken || "";
                    root.copilotKeyValid = res.keyValid === true;
                    root.copilotError = res.error;
                    root.errorMsg = "Copilot: " + res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root._githubToken = res.githubToken || "";
                root.copilotKeyValid = res.keyValid === true;
                root.copilotUsername = res.username || "";
                root.copilotUsed = res.used || 0;
                root.copilotQuota = res.quota !== undefined && res.quota !== null ? res.quota : (Plasmoid.configuration.copilotQuota || 300);
                root.copilotPct = Math.max(0, Math.min(100, res.pct || 0));
                root.copilotResetDate = root.nextMonthResetDate();
                root.copilotError = "";
                root.updateCountdowns();
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                root.recordCopilotUsage(root.copilotPct);
            } catch (e) {
                root.copilotError = "Copilot: parse error";
                root.errorMsg = "Copilot: parse error";
                root.stale = root.lastUpdate !== "";
            }
        }
    }

    Plasma5Support.DataSource {
        id: deepseekBalanceSource

        engine: "executable"
        connectedSources: []
        onNewData: function (src, data) {
            disconnectSource(src);
            if (root.enabledTabs[root.activeTab] !== "deepseek" && !root.panelShows("deepseek"))
                return;

            var output = (data["stdout"] || "").trim();
            if (!output || output === "{}") {
                root._deepseekApiKey = "";
                root.deepseekKeyValid = false;
                root.deepseekError = "";
                root.errorMsg = "DeepSeek: no API key configured";
                root.stale = root.lastUpdate !== "";
                return;
            }
            try {
                var res = JSON.parse(output);
                if (res.error) {
                    root._deepseekApiKey = res.deepseekApiKey || "";
                    root.deepseekKeyValid = res.keyValid === true;
                    root.deepseekError = res.error;
                    root.errorMsg = "DeepSeek: " + res.error;
                    root.stale = root.lastUpdate !== "";
                    return;
                }
                root._deepseekApiKey = res.deepseekApiKey || "";
                root.deepseekKeyValid = res.keyValid === true;
                root.deepseekIsAvailable = res.isAvailable === true;
                root.deepseekBalances = res.balances || [];
                root.deepseekPrimaryCurrency = res.primaryCurrency || "";
                root.deepseekPrimaryTotal = res.primaryTotal || 0;
                root.deepseekPrimaryGranted = res.primaryGranted || 0;
                root.deepseekPrimaryToppedUp = res.primaryToppedUp || 0;
                root.deepseekError = "";
                root.errorMsg = "";
                root.stale = false;
                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm");
                root._offline = false;
                offlineRetryTimer.stop();
                root.recordDeepSeekBalance(root.deepseekPrimaryTotal);
            } catch (e) {
                root.deepseekError = "DeepSeek: parse error";
                root.errorMsg = "DeepSeek: parse error";
                root.stale = root.lastUpdate !== "";
            }
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

    Timer {
        interval: 300000 // 5 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchAllStatuses()
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
                costText: root.openaiTotalCostUSD > 0 ? "$" + root.openaiTotalCostUSD.toFixed(2) : (root._openaiApiKey ? "API" : (root.openaiCodexLoggedIn ? "Codex" : "—"))
                tooltipText: "OpenAI" + (root.codexSessionAvailable ? "\nCodex 5h: " + Math.round(100 - root.codexSessionPct) + "% left" : "") + (root.codexWeeklyAvailable ? "\nCodex weekly: " + Math.round(100 - root.codexWeeklyPct) + "% left" : "") + (root._openaiApiKey ? "\nAPI usage configured\nCost (30d): $" + root.openaiTotalCostUSD.toFixed(2) + "\nIn: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens) : "\nAPI usage needs an OpenAI API key") + (root.openaiCodexLoggedIn ? "\nCodex signed in" + (root.openaiEmail ? ": " + root.openaiEmail : "") : "")
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
