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
    onActiveTabChanged: {
        // Switch chart window to the right series when tabs change so the chart
        // always shows meaningful data without requiring a manual toggle.
        var tab = root.enabledTabs[root.activeTab] || "";
        if (tab === "openai") {
            if (root.chartWindow !== "codex_primary" && root.chartWindow !== "codex_weekly") {
                root.chartWindow = "codex_primary";
                Plasmoid.configuration.chartWindow = "codex_primary";
            }
        } else if (tab === "claude") {
            if (root.chartWindow !== "session" && root.chartWindow !== "weekly") {
                root.chartWindow = "weekly";
                Plasmoid.configuration.chartWindow = "weekly";
            }
        } else if (tab === "antigravity") {
            root.chartWindow = "antigravity";
            Plasmoid.configuration.chartWindow = "antigravity";
        } else if (tab === "openrouter") {
            root.chartWindow = "openrouter";
            Plasmoid.configuration.chartWindow = "openrouter";
        }
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

    function _historyKey() {
        if (root.chartWindow === "session")
            return "s";
        if (root.chartWindow === "weekly")
            return "w";
        if (root.chartWindow === "codex_primary")
            return "cp";
        if (root.chartWindow === "codex_weekly")
            return "cw";
        if (root.chartWindow === "antigravity")
            return "ag";
        if (root.chartWindow === "openrouter")
            return "or";
        return "w";
    }

    // {t, v} view of the currently-selected chart window
    readonly property var weeklyUsageHistory: {
        var key = root._historyKey();
        var out = [];
        for (var i = 0; i < root.usageHistory.length; i++) {
            var p = root.usageHistory[i];
            var v = p[key];
            if (v === undefined || v === null)
                continue;
            out.push({
                t: p.t,
                v: v
            });
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
        var s = Qt.resolvedUrl("history_io.sh").toString().replace("file://", "");
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" bash " + s + " autosave";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    // Restore from the mirror file when plasmoid config has no history (e.g. fresh install).
    function autoloadHistory() {
        var s = Qt.resolvedUrl("history_io.sh").toString().replace("file://", "");
        var cmd = "bash " + s + " autoload";
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

    // ── History export / import ─────────────────────────────────────────────────
    property string historyIOMsg: ""

    function exportHistory() {
        var s = Qt.resolvedUrl("history_io.sh").toString().replace("file://", "");
        var json = JSON.stringify(root.usageHistory);
        // Pass the payload base64-encoded and decode it inside the shell, so the JSON
        // (quotes, brackets) never has to survive command-line quoting.
        var cmd = "WIDGET_HISTORY_JSON=\"$(printf %s '" + Qt.btoa(json) + "' | base64 -d)\" bash " + s + " export";
        historyIOSource.disconnectSource(cmd);
        historyIOSource.connectSource(cmd);
    }

    function importHistory() {
        var s = Qt.resolvedUrl("history_io.sh").toString().replace("file://", "");
        var cmd = "bash " + s + " import";
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
                return;
            }
            try {
                var res = JSON.parse(output);
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
            var s = Qt.resolvedUrl("get_claude_credentials.sh").toString().replace("file://", "");
            var cfgKey = Plasmoid.configuration.claudeAdminApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_CLAUDE_ADMIN_KEY=" + cfgKey + " " : "";
            var cmd = envPrefix + "bash " + s;
            credSource.disconnectSource(cmd);
            credSource.connectSource(cmd);
            // Read effort level + dream mode from ~/.claude/settings.json
            var settingsCmd = "cat \"$HOME/.claude/settings.json\" 2>/dev/null || echo '{}'";
            claudeSettingsSource.disconnectSource(settingsCmd);
            claudeSettingsSource.connectSource(settingsCmd);
        } else if (tab === "antigravity") {
            var s = Qt.resolvedUrl("get_antigravity_usage.sh").toString().replace("file://", "");
            var cmd = "bash " + s;
            antigravityUsageSource.disconnectSource(cmd);
            antigravityUsageSource.connectSource(cmd);
        } else if (tab === "openai") {
            var s = Qt.resolvedUrl("get_openai_usage.sh").toString().replace("file://", "");
            var cfgKey = Plasmoid.configuration.openaiApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENAI_API_KEY=" + cfgKey + " " : "";
            var cmd = envPrefix + "bash " + s;
            openaiCredSource.disconnectSource(cmd);
            openaiCredSource.connectSource(cmd);
        } else if (tab === "mistral") {
            var s = Qt.resolvedUrl("get_mistral_usage.sh").toString().replace("file://", "");
            var cfgKey = Plasmoid.configuration.mistralApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_MISTRAL_API_KEY=" + cfgKey + " " : "";
            var cmd = envPrefix + "bash " + s;
            mistralCredSource.disconnectSource(cmd);
            mistralCredSource.connectSource(cmd);
        } else if (tab === "openrouter") {
            var s = Qt.resolvedUrl("get_openrouter_usage.sh").toString().replace("file://", "");
            var cfgKey = Plasmoid.configuration.openrouterApiKey || "";
            var envPrefix = cfgKey ? "WIDGET_OPENROUTER_API_KEY=" + cfgKey + " " : "";
            var cmd = envPrefix + "bash " + s;
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
                spark: root.sparkSeries("s", 24)
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
                spark: root.sparkSeries("w", 24)
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
                // When Codex plan usage is available (and no API cost to show), surface the
                // 5-hour window % so the panel reflects "messages left" at a glance.
                pct: root.codexUsageAvailable && root.openaiTotalCostUSD <= 0 ? root.codexPrimaryPct : (root.openaiTotalCostUSD > 0 ? Math.min(100, (root.openaiTotalCostUSD / 10) * 100) : 0)
                iconColor: root.openaiGreen
                stale: root.stale && root.enabledTabs[root.activeTab] === "openai"
                visible: root.enabledTabs[root.activeTab] === "openai"
                showCost: !(root.codexUsageAvailable && root.openaiTotalCostUSD <= 0)
                costText: root.openaiTotalCostUSD > 0 ? "$" + root.openaiTotalCostUSD.toFixed(2) : (root._openaiApiKey ? "API" : (root.openaiCodexLoggedIn ? "Codex" : "—"))
                tooltipText: "OpenAI" + (root.codexUsageAvailable ? "\nCodex 5h: " + Math.round(100 - root.codexPrimaryPct) + "% left  ·  weekly: " + Math.round(100 - root.codexSecondaryPct) + "% left" : "") + (root._openaiApiKey ? "\nAPI usage configured\nCost (30d): $" + root.openaiTotalCostUSD.toFixed(2) + "\nIn: " + root.formatTokens(root.openaiTotalInputTokens) + "  Out: " + root.formatTokens(root.openaiTotalOutputTokens) : "\nAPI usage needs an OpenAI API key") + (root.openaiCodexLoggedIn ? "\nCodex signed in" + (root.openaiEmail ? ": " + root.openaiEmail : "") : "")
            }

            PanelSlot {
                pct: 0
                iconColor: root.mistralOrange
                stale: root.stale && root.enabledTabs[root.activeTab] === "mistral"
                visible: root.enabledTabs[root.activeTab] === "mistral"
                showCost: true
                costText: root.mistralKeyValid ? "✓ key" : "—"
                tooltipText: "Mistral AI" + (root.mistralKeyValid ? "\nAPI key configured" : "\nNo key set") + (root.mistralAvailableModels.length > 0 ? "\n" + root.mistralAvailableModels.length + " models" : "")
            }

            PanelSlot {
                pct: root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0 ? Math.min(100, (root.openrouterUsageUSD / root.openrouterLimitUSD) * 100) : 0
                iconColor: root.openrouterPurple
                stale: root.stale && root.enabledTabs[root.activeTab] === "openrouter"
                visible: root.enabledTabs[root.activeTab] === "openrouter" && !root.showSettings
                showCost: true
                costText: root.openrouterKeyValid ? (root.openrouterUsageUSD > 0 ? "$" + root.openrouterUsageUSD.toFixed(3) : "✓ key") : "—"
                tooltipText: "OpenRouter" + (root.openrouterLabel ? "\n" + root.openrouterLabel : "") + (root.openrouterUsageUSD > 0 ? "\nUsed: $" + root.openrouterUsageUSD.toFixed(4) : "") + (root.openrouterLimitUSD !== null ? "\nLimit: $" + root.openrouterLimitUSD.toFixed(2) : "")
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        id: popupRoot
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        // Shrinks to fit settings panel; expands to full content height for tabs
        Layout.minimumHeight: mainColumn.implicitHeight + (Kirigami.Units.largeSpacing + 4) * 2
        Layout.preferredHeight: Layout.minimumHeight
        Layout.maximumHeight: Layout.minimumHeight
        Behavior on Layout.minimumHeight {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // ── Glassmorphism backdrop ──────────────────────────────────────────
        // A translucent tinted layer that lets Plasma's native popup blur show
        // through, plus a faint accent glow and inner highlight for the "glass" look.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -(Kirigami.Units.largeSpacing + 4)
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
            anchors.margins: -(Kirigami.Units.largeSpacing + 4)
            radius: 12
            color: root.resolvedPopupBg
            visible: root.popupBgOpacity > 0
        }

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

            // ── Inline Settings panel ───────────────────────────────────────
            ColumnLayout {
                visible: root.showSettings
                Layout.fillWidth: true
                spacing: 10

                // ── Services ───────────────────────────────────────────────
                PlasmaComponents.Label {
                    text: "Services"
                    font.bold: true
                    font.pixelSize: 10
                    opacity: 0.5
                    color: Kirigami.Theme.textColor
                }

                // 2-column grid of toggles
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 2

                    Repeater {
                        model: [
                            {
                                id: "claude",
                                label: "Claude",
                                color: "#cc785c"
                            },
                            {
                                id: "antigravity",
                                label: "Antigravity",
                                color: "#4285f4"
                            },
                            {
                                id: "openai",
                                label: "OpenAI",
                                color: "#10a37f"
                            },
                            {
                                id: "mistral",
                                label: "Mistral",
                                color: "#ff7000"
                            },
                            {
                                id: "openrouter",
                                label: "OpenRouter",
                                color: "#9333ea"
                            },
                            {
                                id: "__spacer",
                                label: "",
                                color: "transparent"
                            }
                        ]
                        RowLayout {
                            spacing: 6
                            visible: modelData.id !== "__spacer"
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: modelData.color
                                Layout.alignment: Qt.AlignVCenter
                            }
                            PlasmaComponents.Label {
                                text: modelData.label
                                font.pixelSize: 11
                                color: Kirigami.Theme.textColor
                                Layout.preferredWidth: 80
                            }
                            QQC2.Switch {
                                implicitHeight: 20
                                checked: {
                                    if (modelData.id === "claude")
                                        return Plasmoid.configuration.claudeEnabled;
                                    if (modelData.id === "antigravity")
                                        return Plasmoid.configuration.antigravityEnabled;
                                    if (modelData.id === "openai")
                                        return Plasmoid.configuration.openaiEnabled;
                                    if (modelData.id === "mistral")
                                        return Plasmoid.configuration.mistralEnabled;
                                    if (modelData.id === "openrouter")
                                        return Plasmoid.configuration.openrouterEnabled;
                                    return false;
                                }
                                onToggled: {
                                    if (modelData.id === "claude")
                                        Plasmoid.configuration.claudeEnabled = checked;
                                    if (modelData.id === "antigravity")
                                        Plasmoid.configuration.antigravityEnabled = checked;
                                    if (modelData.id === "openai")
                                        Plasmoid.configuration.openaiEnabled = checked;
                                    if (modelData.id === "mistral")
                                        Plasmoid.configuration.mistralEnabled = checked;
                                    if (modelData.id === "openrouter")
                                        Plasmoid.configuration.openrouterEnabled = checked;
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.weeklyColor
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: "Usage chart"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    QQC2.Switch {
                        implicitHeight: 20
                        checked: Plasmoid.configuration.showUsageChart
                        onToggled: Plasmoid.configuration.showUsageChart = checked
                    }
                }

                // Theme accent toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Kirigami.Theme.highlightColor
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: "Theme accent"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    QQC2.Switch {
                        implicitHeight: 20
                        checked: Plasmoid.configuration.useThemeAccent
                        onToggled: {
                            Plasmoid.configuration.useThemeAccent = checked;
                            root.useThemeAccent = checked;
                        }
                    }
                    PlasmaComponents.Label {
                        text: "Use Plasma accent color"
                        font.pixelSize: 9
                        opacity: 0.45
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Poll interval
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Qt.rgba(1, 1, 1, 0.3)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: "Refresh"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    QQC2.ComboBox {
                        id: pollCombo
                        implicitHeight: 24
                        Layout.preferredWidth: 120
                        font.pixelSize: 10
                        readonly property var secs: [60, 120, 300, 600, 900, 1800]
                        model: ["1 min", "2 min", "5 min", "10 min", "15 min", "30 min"]
                        currentIndex: Math.max(0, secs.indexOf(Plasmoid.configuration.pollIntervalSec || 300))
                        onActivated: {
                            var s = secs[currentIndex];
                            Plasmoid.configuration.pollIntervalSec = s;
                            root.pollIntervalSec = s;
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                // ── Appearance ──────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }
                PlasmaComponents.Label {
                    text: "Appearance"
                    font.bold: true
                    font.pixelSize: 10
                    opacity: 0.5
                    color: Kirigami.Theme.textColor
                }

                // Grid of appearance settings
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 6

                    // Row 1: Popup Background Color & Opacity
                    PlasmaComponents.Label {
                        text: "Popup BG"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: root.resolvedPopupBg
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.2)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.colorTarget = "popup";
                                    colorDialog.selectedColor = root.popupBgColor;
                                    colorDialog.open();
                                }
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.text: "Click to open color picker"
                            }
                        }
                        QQC2.TextField {
                            text: Plasmoid.configuration.popupBgColor || "#000000"
                            placeholderText: "#000000"
                            implicitHeight: 22
                            Layout.fillWidth: true
                            font.pixelSize: 9
                            onTextEdited: {
                                if (/^#[0-9A-Fa-f]{6}$/.test(text)) {
                                    Plasmoid.configuration.popupBgColor = text;
                                    root.popupBgColor = text;
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 4
                        PlasmaComponents.Label {
                            text: "Opacity:"
                            font.pixelSize: 10
                            opacity: 0.6
                        }
                        QQC2.TextField {
                            text: Math.round(root.popupBgOpacity * 100)
                            placeholderText: "0"
                            implicitHeight: 22
                            Layout.preferredWidth: 32
                            font.pixelSize: 9
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }
                            onTextEdited: {
                                var val = parseInt(text);
                                if (!isNaN(val) && val >= 0 && val <= 100) {
                                    var opacityVal = val / 100.0;
                                    Plasmoid.configuration.popupBgOpacity = opacityVal;
                                    root.popupBgOpacity = opacityVal;
                                }
                            }
                        }
                        PlasmaComponents.Label {
                            text: "%"
                            font.pixelSize: 10
                            opacity: 0.6
                        }
                    }

                    // Row 2: Card Background Color & Opacity
                    PlasmaComponents.Label {
                        text: "Card BG"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: root.resolvedCardBg
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.2)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.colorTarget = "card";
                                    colorDialog.selectedColor = root.cardBgColor;
                                    colorDialog.open();
                                }
                                QQC2.ToolTip.delay: 400
                                QQC2.ToolTip.visible: containsMouse
                                QQC2.ToolTip.text: "Click to open color picker"
                            }
                        }
                        QQC2.TextField {
                            text: Plasmoid.configuration.cardBgColor || "#100a1a"
                            placeholderText: "#100a1a"
                            implicitHeight: 22
                            Layout.fillWidth: true
                            font.pixelSize: 9
                            onTextEdited: {
                                if (/^#[0-9A-Fa-f]{6}$/.test(text)) {
                                    Plasmoid.configuration.cardBgColor = text;
                                    root.cardBgColor = text;
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 4
                        PlasmaComponents.Label {
                            text: "Opacity:"
                            font.pixelSize: 10
                            opacity: 0.6
                        }
                        QQC2.TextField {
                            text: Math.round(root.cardBgOpacity * 100)
                            placeholderText: "90"
                            implicitHeight: 22
                            Layout.preferredWidth: 32
                            font.pixelSize: 9
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }
                            onTextEdited: {
                                var val = parseInt(text);
                                if (!isNaN(val) && val >= 0 && val <= 100) {
                                    var opacityVal = val / 100.0;
                                    Plasmoid.configuration.cardBgOpacity = opacityVal;
                                    root.cardBgOpacity = opacityVal;
                                }
                            }
                        }
                        PlasmaComponents.Label {
                            text: "%"
                            font.pixelSize: 10
                            opacity: 0.6
                        }
                    }
                }

                // History export / import
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.activeAccent
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: "History"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 80
                    }
                    PlasmaComponents.Button {
                        text: "Export"
                        icon.name: "document-export"
                        implicitHeight: 26
                        font.pixelSize: 10
                        onClicked: root.exportHistory()
                    }
                    PlasmaComponents.Button {
                        text: "Import"
                        icon.name: "document-import"
                        implicitHeight: 26
                        font.pixelSize: 10
                        onClicked: root.importHistory()
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                PlasmaComponents.Label {
                    visible: root.historyIOMsg !== ""
                    text: root.historyIOMsg
                    font.pixelSize: 9
                    opacity: 0.6
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // ── API Keys ───────────────────────────────────────────────
                PlasmaComponents.Label {
                    text: "API Keys"
                    font.bold: true
                    font.pixelSize: 10
                    opacity: 0.5
                    color: Kirigami.Theme.textColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    KeyRow {
                        label: "Claude Admin"
                        placeholder: "sk-ant-api03-…"
                        configKey: "claudeAdminApiKey"
                    }
                    KeyRow {
                        label: "OpenAI API"
                        placeholder: "sk-proj-…"
                        configKey: "openaiApiKey"
                    }
                    KeyRow {
                        label: "Google AI"
                        placeholder: "AIza…"
                        configKey: "googleApiKey"
                    }
                    KeyRow {
                        label: "Mistral"
                        placeholder: "or $MISTRAL_API_KEY"
                        configKey: "mistralApiKey"
                        rowVisible: Plasmoid.configuration.mistralEnabled
                    }
                    KeyRow {
                        label: "OpenRouter"
                        placeholder: "or $OPENROUTER_API_KEY"
                        configKey: "openrouterApiKey"
                        rowVisible: Plasmoid.configuration.openrouterEnabled
                    }
                }
            }

            // ── Claude tab ───────────────────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "claude" && !root.showSettings
                Layout.fillWidth: true
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
                        text: {
                            // Prettify rateLimitTier: "default_claude_ai" → "Default"
                            // "pro_claude_ai" → "Pro", etc.
                            var tier = root.claudeRateLimitTier.replace(/_claude_ai$/i, "").replace(/_/g, " ").replace(/\b\w/g, function (c) {
                                return c.toUpperCase();
                            });
                            if (tier)
                                return tier;
                            // Fall back to abbreviated org UUID or generic label
                            return root.claudeOrganizationUuid ? root.claudeOrganizationUuid.slice(0, 8) + "…" : "Claude Code User";
                        }
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Effort chip
                    Rectangle {
                        visible: root.claudeEffortLevel !== ""
                        implicitHeight: 16
                        implicitWidth: effortChipLabel.implicitWidth + 12
                        radius: 3
                        readonly property color effortColor: {
                            if (root.claudeEffortLevel === "high")
                                return Qt.rgba(0.8, 0.47, 0.36, 0.85);
                            if (root.claudeEffortLevel === "low")
                                return Qt.rgba(0.4, 0.7, 0.4, 0.7);
                            return Qt.rgba(1, 1, 1, 0.55);
                        }
                        color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.35)
                        QQC2.ToolTip.visible: effortMA.containsMouse
                        QQC2.ToolTip.text: "Thinking budget: " + root.claudeEffortLevel
                        QQC2.ToolTip.delay: 400
                        MouseArea {
                            id: effortMA
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                        }
                        PlasmaComponents.Label {
                            id: effortChipLabel
                            anchors.centerIn: parent
                            text: "effort: " + root.claudeEffortLevel
                            font.pixelSize: 9
                            font.bold: true
                            color: parent.effortColor
                        }
                    }

                    // Dream (extended thinking) chip
                    Rectangle {
                        visible: true
                        implicitHeight: 16
                        implicitWidth: dreamChipLabel.implicitWidth + 12
                        radius: 3
                        readonly property color dreamColor: root.claudeAutoDream ? Qt.rgba(0.43, 0.35, 0.78, 0.9) : Qt.rgba(1, 1, 1, 0.3)
                        color: Qt.rgba(dreamColor.r, dreamColor.g, dreamColor.b, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(dreamColor.r, dreamColor.g, dreamColor.b, 0.35)
                        QQC2.ToolTip.visible: dreamMA.containsMouse
                        QQC2.ToolTip.text: root.claudeAutoDream ? "Extended thinking (dream mode): ON\nClaude will reason longer on complex tasks" : "Extended thinking (dream mode): OFF"
                        QQC2.ToolTip.delay: 400
                        MouseArea {
                            id: dreamMA
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                        }
                        PlasmaComponents.Label {
                            id: dreamChipLabel
                            anchors.centerIn: parent
                            text: root.claudeAutoDream ? "dream: on" : "dream: off"
                            font.pixelSize: 9
                            font.bold: root.claudeAutoDream
                            color: parent.dreamColor
                        }
                    }

                    Rectangle {
                        implicitHeight: 18
                        implicitWidth: planLabelClaude.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        color: root.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.8, 0.47, 0.36, 0.18)
                        border.width: 1
                        border.color: root.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.8, 0.47, 0.36, 0.35)
                        PlasmaComponents.Label {
                            id: planLabelClaude
                            anchors.centerIn: parent
                            text: root.claudeSubscriptionType.toUpperCase()
                            font.pixelSize: 10
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
                    // referencing usageHistory.length makes these bindings re-evaluate on new samples
                    etaText: root.usageHistory.length >= 0 ? root.etaToFull("s", root.sessionPct) : ""
                    deltaText: root.usageHistory.length >= 0 ? root.periodDelta("s", root.sessionPct, 24 * 3600000, "yesterday") : ""
                    tokenText: root.sessionTokenLimit > 0 ? root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens" : ""
                    tooltipText: "Claude 5-hour rolling window\nUsage: " + Math.round(root.sessionPct) + "%" + (root.sessionTokenLimit > 0 ? "\n" + root.formatTokens(root.sessionTokensUsed) + " / " + root.formatTokens(root.sessionTokenLimit) + " tokens" : "") + (root.sessionResetTime ? "\nResets: " + root.sessionResetTime : "")
                }

                PopupRow {
                    label: "7 Days"
                    resetText: root.weeklyResetTime ? "resets " + root.weeklyResetTime : ""
                    countdownText: root.weeklyCountdown === "resetting..." ? "resetting..." : (root.weeklyCountdown ? "in " + root.weeklyCountdown : "")
                    value: root.weeklyPct
                    barColor: root.weeklyColor
                    etaText: root.usageHistory.length >= 0 ? root.etaToFull("w", root.weeklyPct) : ""
                    deltaText: root.usageHistory.length >= 0 ? root.periodDelta("w", root.weeklyPct, 7 * 24 * 3600000, "last week") : ""
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
            }

            // ── Antigravity / Gemini tab ──────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "antigravity" && !root.showSettings
                Layout.fillWidth: true
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
                        implicitHeight: 18
                        implicitWidth: planLabel.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        color: root.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.26, 0.66, 0.33, 0.18)
                        border.width: 1
                        border.color: root.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.26, 0.66, 0.33, 0.35)
                        PlasmaComponents.Label {
                            id: planLabel
                            anchors.centerIn: parent
                            text: root.antigravityPlanType
                            font.pixelSize: 10
                            font.bold: true
                            color: root.antigravityPlanType === "Free" ? Kirigami.Theme.textColor : root.googleGreen
                        }
                    }
                }

                PopupRow {
                    visible: root.antigravityPromptCreditsMonthly > 0
                    label: "Prompt Credits"
                    resetText: root.antigravityResetTime ? "resets " + root.antigravityResetTime : ""
                    countdownText: root.antigravityCountdown === "resetting..." ? "resetting..." : (root.antigravityCountdown ? "in " + root.antigravityCountdown : "")
                    value: root.antigravityPromptCreditsMonthly > 0 ? (1 - root.antigravityPromptCreditsAvailable / root.antigravityPromptCreditsMonthly) * 100 : 0
                    barColor: root.googleBlue
                    tokenText: root.antigravityPromptCreditsAvailable + " / " + root.formatTokens(root.antigravityPromptCreditsMonthly) + " left"
                    tooltipText: "Prompt Credits\nUsed: " + Math.round(value) + "%  ·  " + root.antigravityPromptCreditsAvailable + " / " + root.formatTokens(root.antigravityPromptCreditsMonthly) + " left" + (root.antigravityResetTime ? "\nResets: " + root.antigravityResetTime : "")
                }

                PopupRow {
                    visible: root.antigravityPromptCreditsMonthly === 0 && Object.keys(root.antigravityModels).length > 0
                    label: "Overall Quota"
                    resetText: root.antigravityResetTime ? "resets " + root.antigravityResetTime : ""
                    countdownText: root.antigravityCountdown === "resetting..." ? "resetting..." : (root.antigravityCountdown ? "in " + root.antigravityCountdown : "")
                    value: root.antigravityPct
                    barColor: root.googleBlue
                    etaText: root.usageHistory.length >= 0 ? root.etaToFull("ag", root.antigravityPct) : ""
                    deltaText: root.usageHistory.length >= 0 ? root.periodDelta("ag", root.antigravityPct, 30 * 24 * 3600000, "last month") : ""
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
            }

            // ── OpenAI tab ────────────────────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "openai" && !root.showSettings
                Layout.fillWidth: true
                spacing: 14

                // Codex / ChatGPT user identity & limits (top section, clean style)
                ColumnLayout {
                    visible: root.openaiCodexLoggedIn
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Kirigami.Icon {
                            source: "user-identity"
                            width: 14
                            height: 14
                            color: root.openaiGreen
                            isMask: true
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            text: root.openaiEmail || (root.openaiAccountId ? root.openaiAccountId : "Codex / ChatGPT User")
                            font.pixelSize: 10
                            opacity: 0.6
                            color: Kirigami.Theme.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: root.openaiPlanType !== ""
                            implicitHeight: 18
                            implicitWidth: codexPlanLabel.implicitWidth + 16
                            Layout.alignment: Qt.AlignVCenter
                            radius: 4
                            color: root.openaiPlanType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.063, 0.639, 0.498, 0.18)
                            border.width: 1
                            border.color: root.openaiPlanType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.063, 0.639, 0.498, 0.35)
                            PlasmaComponents.Label {
                                id: codexPlanLabel
                                anchors.centerIn: parent
                                text: root.openaiPlanType.toUpperCase()
                                font.pixelSize: 10
                                font.bold: true
                                color: root.openaiPlanType === "free" ? Kirigami.Theme.textColor : root.openaiGreen
                            }
                        }
                    }

                    // Codex plan limits (messages remaining)
                    ColumnLayout {
                        visible: root.codexUsageAvailable
                        Layout.fillWidth: true
                        spacing: 12

                        PopupRow {
                            label: "5 Hours"
                            countdownText: root.codexPrimaryCountdown === "resetting..." ? "resetting..." : (root.codexPrimaryCountdown ? "in " + root.codexPrimaryCountdown : "")
                            value: root.codexPrimaryPct
                            barColor: root.openaiGreen
                            etaText: root.usageHistory.length >= 0 ? root.etaToFull("cp", root.codexPrimaryPct) : ""
                            deltaText: root.usageHistory.length >= 0 ? root.periodDelta("cp", root.codexPrimaryPct, 5 * 3600000, "last 5h") : ""
                            tokenText: Math.round(100 - root.codexPrimaryPct) + "% of messages left"
                            tooltipText: "Codex 5-hour limit\nUsed: " + Math.round(root.codexPrimaryPct) + "%  ·  " + Math.round(100 - root.codexPrimaryPct) + "% left"
                        }
                        PopupRow {
                            label: "Weekly"
                            countdownText: root.codexSecondaryCountdown === "resetting..." ? "resetting..." : (root.codexSecondaryCountdown ? "in " + root.codexSecondaryCountdown : "")
                            value: root.codexSecondaryPct
                            barColor: root.openaiGreen
                            etaText: root.usageHistory.length >= 0 ? root.etaToFull("cw", root.codexSecondaryPct) : ""
                            deltaText: root.usageHistory.length >= 0 ? root.periodDelta("cw", root.codexSecondaryPct, 7 * 24 * 3600000, "last week") : ""
                            tokenText: Math.round(100 - root.codexSecondaryPct) + "% of messages left"
                            tooltipText: "Codex weekly limit\nUsed: " + Math.round(root.codexSecondaryPct) + "%  ·  " + Math.round(100 - root.codexSecondaryPct) + "% left"
                        }

                        PlasmaComponents.Label {
                            visible: root.codexLimitReached
                            text: "⚠ Limit reached — wait for reset"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.dangerColor
                        }

                        // Per-model additional rate limits
                        Repeater {
                            model: root.codexAdditionalLimits
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    PlasmaComponents.Label {
                                        text: modelData.name
                                        font.pixelSize: 10
                                        font.bold: true
                                        opacity: 0.8
                                        color: root.openaiGreen
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        visible: modelData.limit_reached
                                        implicitHeight: 14
                                        implicitWidth: limitReachedLbl.implicitWidth + 8
                                        radius: 3
                                        color: Qt.rgba(1, 0.3, 0.3, 0.18)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 0.3, 0.3, 0.4)
                                        PlasmaComponents.Label {
                                            id: limitReachedLbl
                                            anchors.centerIn: parent
                                            text: "LIMIT"
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: root.dangerColor
                                        }
                                    }
                                }

                                PopupRow {
                                    label: "5 Hours"
                                    countdownText: {
                                        if (!modelData.primary_reset)
                                            return "";
                                        var cd = root.formatCountdown(modelData.primary_reset);
                                        return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                                    }
                                    value: modelData.primary_pct
                                    barColor: root.openaiGreen
                                    tokenText: Math.round(100 - modelData.primary_pct) + "% of messages left"
                                    tooltipText: modelData.name + " 5-hour limit\nUsed: " + Math.round(modelData.primary_pct) + "%  ·  " + Math.round(100 - modelData.primary_pct) + "% left"
                                }
                                PopupRow {
                                    label: "Weekly"
                                    countdownText: {
                                        if (!modelData.secondary_reset)
                                            return "";
                                        var cd = root.formatCountdown(modelData.secondary_reset);
                                        return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                                    }
                                    value: modelData.secondary_pct
                                    barColor: root.openaiGreen
                                    tokenText: Math.round(100 - modelData.secondary_pct) + "% of messages left"
                                    tooltipText: modelData.name + " weekly limit\nUsed: " + Math.round(modelData.secondary_pct) + "%  ·  " + Math.round(100 - modelData.secondary_pct) + "% left"
                                }
                            }
                        }
                    }

                    // Notice if no API key is added, matching Claude's tip box design
                    PlasmaComponents.Label {
                        visible: root._openaiApiKey === ""
                        text: root.codexUsageAvailable ? "Plan limits above. Add an OpenAI API key in settings for API token/cost data." : "Codex plan limits are separate from OpenAI API billing. Add an OpenAI API key in settings for token and cost data."
                        font.pixelSize: 9
                        opacity: 0.45
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                    }
                }

                // API usage surface (bottom section, clean style)
                ColumnLayout {
                    visible: root._openaiApiKey !== ""
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        visible: root.openaiCodexLoggedIn
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
                        Rectangle {
                            height: 18
                            width: apiKeyBadgeLabel.implicitWidth + 12
                            radius: 4
                            color: Qt.rgba(0.063, 0.639, 0.498, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(0.063, 0.639, 0.498, 0.35)
                            PlasmaComponents.Label {
                                id: apiKeyBadgeLabel
                                anchors.centerIn: parent
                                text: "API KEY"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.openaiGreen
                            }
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
                        visible: Object.keys(root.openaiModels).length === 0 && root.errorMsg === ""
                        Layout.fillWidth: true
                        height: noApiUsageLabel.implicitHeight + 16
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        PlasmaComponents.Label {
                            id: noApiUsageLabel
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                                rightMargin: 10
                            }
                            text: "No API usage returned for the last 30 days."
                            font.pixelSize: 10
                            opacity: 0.55
                            color: Kirigami.Theme.textColor
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Per-model API usage, nested inside the API usage container
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: Object.keys(root.openaiModels).length > 0

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
                }

                // No login and no key
                ColumnLayout {
                    visible: root._openaiApiKey === "" && !root.openaiCodexLoggedIn && root.enabledTabs[root.activeTab] === "openai"
                    Layout.fillWidth: true
                    spacing: 6
                    PlasmaComponents.Label {
                        text: "Not connected"
                        font.pixelSize: 12
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "Add an OpenAI API key for API usage, or\nlog in with Codex CLI for account status."
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Mistral tab ─────────────────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "mistral" && !root.showSettings
                Layout.fillWidth: true
                spacing: 14

                // Status badge row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Kirigami.Icon {
                        source: "dialog-password"
                        width: 14
                        height: 14
                        color: root.mistralOrange
                        isMask: true
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "Mistral AI"
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        height: 18
                        width: mistralBadgeLabel.implicitWidth + 12
                        radius: 4
                        color: root.mistralKeyValid ? Qt.rgba(1.0, 0.44, 0.0, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: root.mistralKeyValid ? Qt.rgba(1.0, 0.44, 0.0, 0.35) : Qt.rgba(1, 1, 1, 0.12)
                        PlasmaComponents.Label {
                            id: mistralBadgeLabel
                            anchors.centerIn: parent
                            text: root.mistralKeyValid ? "ACTIVE" : (root._mistralApiKey ? "INVALID" : "NO KEY")
                            font.pixelSize: 9
                            font.bold: true
                            color: root.mistralKeyValid ? root.mistralOrange : Kirigami.Theme.textColor
                        }
                    }
                }

                // No key message
                ColumnLayout {
                    visible: !root._mistralApiKey && !root.mistralKeyValid
                    Layout.fillWidth: true
                    spacing: 6
                    PlasmaComponents.Label {
                        text: "Not connected"
                        font.pixelSize: 12
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "Set a Mistral API key in ⚙ settings or via\n$MISTRAL_API_KEY / ~/.config/mistral/api-key"
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Key valid: show model list
                ColumnLayout {
                    visible: root.mistralKeyValid && root.mistralAvailableModels.length > 0
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PlasmaComponents.Label {
                            text: "Available Models"
                            font.bold: true
                            font.pixelSize: 11
                            opacity: 0.7
                            color: Kirigami.Theme.textColor
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: root.mistralAvailableModels.length + " models"
                            font.bold: true
                            font.pixelSize: 13
                            color: root.mistralOrange
                        }
                    }

                    Repeater {
                        model: root.mistralAvailableModels.slice(0, 10)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.mistralOrange
                                opacity: 0.7
                                Layout.alignment: Qt.AlignVCenter
                            }
                            PlasmaComponents.Label {
                                text: modelData
                                font.pixelSize: 10
                                opacity: 0.65
                                color: Kirigami.Theme.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        visible: root.mistralAvailableModels.length > 10
                        text: "... and " + (root.mistralAvailableModels.length - 10) + " more"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }
                }

                // Note about billing
                Rectangle {
                    visible: root.mistralKeyValid
                    Layout.fillWidth: true
                    height: mistralNoteCol.implicitHeight + 16
                    radius: 6
                    color: Qt.rgba(1.0, 0.44, 0.0, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 0.44, 0.0, 0.20)
                    ColumnLayout {
                        id: mistralNoteCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 10
                        }
                        spacing: 4
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.mistralOrange
                                Layout.alignment: Qt.AlignVCenter
                            }
                            PlasmaComponents.Label {
                                text: "No public usage API"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.mistralOrange
                            }
                        }
                        PlasmaComponents.Label {
                            text: "Mistral doesn't expose billing data via REST.\nCheck usage at console.mistral.ai"
                            font.pixelSize: 10
                            opacity: 0.55
                            color: Kirigami.Theme.textColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ── OpenRouter tab ──────────────────────────────────────────────
            ColumnLayout {
                visible: root.enabledTabs[root.activeTab] === "openrouter" && !root.showSettings
                Layout.fillWidth: true
                spacing: 14

                // Account row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.openrouterKeyValid

                    Kirigami.Icon {
                        source: "user-identity"
                        width: 14
                        height: 14
                        color: root.openrouterPurple
                        isMask: true
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: root.openrouterLabel || "OpenRouter"
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        height: 18
                        width: orPlanLabel.implicitWidth + 12
                        radius: 4
                        color: root.openrouterIsFreeTier ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.576, 0.2, 0.918, 0.18)
                        border.width: 1
                        border.color: root.openrouterIsFreeTier ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.576, 0.2, 0.918, 0.35)
                        PlasmaComponents.Label {
                            id: orPlanLabel
                            anchors.centerIn: parent
                            text: root.openrouterIsFreeTier ? "FREE" : "PAID"
                            font.pixelSize: 9
                            font.bold: true
                            color: root.openrouterIsFreeTier ? Kirigami.Theme.textColor : root.openrouterPurple
                        }
                    }
                }

                // No key message
                ColumnLayout {
                    visible: !root.openrouterKeyValid && root._openrouterApiKey === ""
                    Layout.fillWidth: true
                    spacing: 6
                    PlasmaComponents.Label {
                        text: "Not connected"
                        font.pixelSize: 12
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: "Set an OpenRouter API key in ⚙ settings or via\n$OPENROUTER_API_KEY / ~/.config/openrouter/api-key"
                        font.pixelSize: 10
                        opacity: 0.5
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Usage stats
                ColumnLayout {
                    visible: root.openrouterKeyValid
                    Layout.fillWidth: true
                    spacing: 8

                    // Usage bar (only when limit is set)
                    PopupRow {
                        visible: root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0
                        label: "Credit Usage"
                        value: root.openrouterLimitUSD !== null && root.openrouterLimitUSD > 0 ? Math.min(100, (root.openrouterUsageUSD / root.openrouterLimitUSD) * 100) : 0
                        barColor: root.openrouterPurple
                        etaText: root.usageHistory.length >= 0 ? root.etaToFull("or", value) : ""
                        deltaText: root.usageHistory.length >= 0 ? root.periodDelta("or", value, 30 * 24 * 3600000, "last month") : ""
                        tokenText: "$" + root.openrouterUsageUSD.toFixed(4) + " / $" + (root.openrouterLimitUSD !== null ? root.openrouterLimitUSD.toFixed(2) : "∞") + " used"
                        tooltipText: "OpenRouter credit spend\n$" + root.openrouterUsageUSD.toFixed(4) + " of $" + (root.openrouterLimitUSD !== null ? root.openrouterLimitUSD.toFixed(2) : "unlimited") + " limit"
                    }

                    // Usage summary card
                    Rectangle {
                        Layout.fillWidth: true
                        height: orStatsCol.implicitHeight + 16
                        radius: 8
                        color: Qt.rgba(0.576, 0.2, 0.918, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(0.576, 0.2, 0.918, 0.22)

                        ColumnLayout {
                            id: orStatsCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 12
                            }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: "All-time Spend"
                                    font.pixelSize: 11
                                    opacity: 0.65
                                    color: Kirigami.Theme.textColor
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: "$" + root.openrouterUsageUSD.toFixed(4)
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: root.openrouterPurple
                                }
                            }

                            // Credit limit row
                            RowLayout {
                                visible: root.openrouterLimitUSD !== null
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: "Credit Limit"
                                    font.pixelSize: 11
                                    opacity: 0.65
                                    color: Kirigami.Theme.textColor
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: root.openrouterLimitUSD !== null ? "$" + root.openrouterLimitUSD.toFixed(2) : "∞"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.85
                                }
                            }

                            // Remaining row
                            RowLayout {
                                visible: root.openrouterLimitRemainingUSD !== null
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: "Remaining"
                                    font.pixelSize: 11
                                    opacity: 0.65
                                    color: Kirigami.Theme.textColor
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: root.openrouterLimitRemainingUSD !== null ? "$" + root.openrouterLimitRemainingUSD.toFixed(4) : "—"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: {
                                        if (root.openrouterLimitRemainingUSD === null)
                                            return Kirigami.Theme.textColor;
                                        var pct = root.openrouterLimitUSD > 0 ? ((root.openrouterLimitUSD - root.openrouterLimitRemainingUSD) / root.openrouterLimitUSD) * 100 : 0;
                                        return root.usageColor(pct);
                                    }
                                }
                            }

                            // Rate limit info
                            RowLayout {
                                visible: root.openrouterRateLimit && root.openrouterRateLimit.requests !== undefined
                                Layout.fillWidth: true
                                spacing: 8
                                PlasmaComponents.Label {
                                    text: "Rate Limit"
                                    font.pixelSize: 11
                                    opacity: 0.65
                                    color: Kirigami.Theme.textColor
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: root.openrouterRateLimit.requests !== undefined ? root.openrouterRateLimit.requests + " req / " + (root.openrouterRateLimit.interval || "min") : ""
                                    font.pixelSize: 10
                                    opacity: 0.65
                                    color: Kirigami.Theme.textColor
                                }
                            }
                        }
                    }

                    // Free tier note
                    Rectangle {
                        visible: root.openrouterIsFreeTier
                        Layout.fillWidth: true
                        height: orFreeCol.implicitHeight + 12
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        ColumnLayout {
                            id: orFreeCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 10
                            }
                            spacing: 3
                            PlasmaComponents.Label {
                                text: "Free tier active — rate limits apply"
                                font.pixelSize: 10
                                opacity: 0.5
                                color: Kirigami.Theme.textColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── Usage chart (Claude 5H/7D · Codex 5H/7D) ───────────────────
            Rectangle {
                id: usageChartContainer
                visible: !root.showSettings && root.showUsageChart && root.weeklyUsageHistory.length >= 1 && (root.enabledTabs[root.activeTab] === "claude" || (root.enabledTabs[root.activeTab] === "openai" && root.codexUsageAvailable) || root.enabledTabs[root.activeTab] === "antigravity" || root.enabledTabs[root.activeTab] === "openrouter")
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                implicitHeight: 184
                radius: 10
                color: root.resolvedCardBg
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

                // ── Window toggle — Claude: 5H/7D, Codex: 5H/7D (single-series tabs: hidden) ──
                RowLayout {
                    id: chartWindowToggle
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 7
                    anchors.rightMargin: 8
                    spacing: 4
                    visible: {
                        var tab = root.enabledTabs[root.activeTab];
                        if (tab === "claude") {
                            for (var i = 0; i < root.usageHistory.length; i++)
                                if (root.usageHistory[i].s !== undefined && root.usageHistory[i].s !== null)
                                    return true;
                            return false;
                        }
                        if (tab === "openai") {
                            for (var j = 0; j < root.usageHistory.length; j++)
                                if (root.usageHistory[j].cp !== undefined && root.usageHistory[j].cp !== null)
                                    return true;
                        }
                        return false;
                    }
                    Repeater {
                        model: {
                            var tab = root.enabledTabs[root.activeTab];
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
                            color: root.chartWindow === modelData.id ? root.activeAccent : Qt.rgba(1, 1, 1, 0.06)
                            opacity: root.chartWindow === modelData.id ? 0.9 : 1.0
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
                                font.bold: root.chartWindow === modelData.id
                                color: root.chartWindow === modelData.id ? "#ffffff" : Kirigami.Theme.textColor
                                opacity: root.chartWindow === modelData.id ? 1.0 : 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.chartWindow = modelData.id;
                                    Plasmoid.configuration.chartWindow = modelData.id;
                                }
                            }
                        }
                    }
                }

                // Y-axis labels
                PlasmaComponents.Label {
                    anchors.right: chartCanvas.left
                    anchors.rightMargin: 4
                    y: chartCanvas.y + 2
                    text: "100%"
                    font.pixelSize: 9
                    opacity: 0.35
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    anchors.right: chartCanvas.left
                    anchors.rightMargin: 4
                    y: chartCanvas.y + chartCanvas.height / 2 - 6
                    text: "50%"
                    font.pixelSize: 9
                    opacity: 0.35
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    anchors.right: chartCanvas.left
                    anchors.rightMargin: 4
                    y: chartCanvas.y + chartCanvas.height - 14
                    text: "0%"
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

                    property var history: root.weeklyUsageHistory
                    property color accentColor: root.activeAccent
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
                        var key = root._historyKey();
                        var slope = root.usageSlopePerHour(key, 2 * 3600000);
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
                        // Always pin the right edge to "now" so new/sparse data isn't squashed.
                        // Minimum window = 1 hour; otherwise span from earliest point to now.
                        var now_ms = new Date().getTime();
                        var maxT = now_ms;
                        var minT = pts[0].t;
                        var tRange = Math.max(maxT - minT, 3600000);

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
                            // map mouse x → nearest sample index
                            var ratio = Math.max(0, Math.min(1, mouse.x / chartCanvas.width));
                            chartCanvas.scrubIndex = Math.round(ratio * (pts.length - 1));
                        }
                        onExited: chartCanvas.scrubIndex = -1
                        QQC2.ToolTip.visible: chartCanvas.scrubIndex >= 0
                        QQC2.ToolTip.delay: 0
                        QQC2.ToolTip.text: {
                            var pts = chartCanvas.history;
                            if (chartCanvas.scrubIndex < 0 || chartCanvas.scrubIndex >= pts.length)
                                return "";
                            var p = pts[chartCanvas.scrubIndex];
                            return Math.round(p.v) + "%  ·  " + Qt.formatDateTime(new Date(p.t), "MMM d, hh:mm");
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
                        if (root.chartWindow === "session" || root.chartWindow === "codex_primary") {
                            return Qt.formatTime(new Date(timestamp), "hh:mm");
                        }
                        return Qt.formatDate(new Date(timestamp), "MMM d");
                    }

                    PlasmaComponents.Label {
                        text: {
                            var pts = root.weeklyUsageHistory;
                            if (!pts || pts.length < 1)
                                return "";
                            return xAxisRow.formatLabel(pts[0].t);
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
                            var pts = root.weeklyUsageHistory;
                            if (!pts || pts.length < 2)
                                return "";
                            var mid = pts[Math.floor(pts.length / 2)];
                            return xAxisRow.formatLabel(mid.t);
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
                            var pts = root.weeklyUsageHistory;
                            if (!pts || pts.length < 1)
                                return "";
                            return xAxisRow.formatLabel(pts[pts.length - 1].t);
                        }
                        font.pixelSize: 9
                        opacity: 0.40
                        color: Kirigami.Theme.textColor
                    }
                }
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
