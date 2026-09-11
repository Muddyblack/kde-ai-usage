import QtQuick
import QtQuick.Controls.Basic as QC
import "../../hyprland"
import "../../hyprland/ProviderRegistry.js" as ProviderRegistry
import "../../package/contents/code/Format.js" as Format
import "../../package/contents/code/UsageHistory.js" as UsageHistory

// The Windows tray popup (windows/app.py places, shows and hides it).
//
// The content is the Hyprland panel's own — PopupContent.qml and the settings
// page inside it — so this file is only the window around it plus the `shell`
// interface those read: state, settings and history, backed by the `backend`
// object app.py exposes instead of Quickshell processes. Keep the two roots'
// interfaces in step; AiUsageShell.qml is the other implementation.
Window {
    id: root

    width: 460
    height: Math.min(680, mainColumn.implicitHeight + 40)
    visible: false
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    title: "AI Usage"

    // ── Environment ──────────────────────────────────────────────────────────
    readonly property string iconSource: backend.appIcon
    readonly property string iconDir: backend.iconDir
    readonly property string configPath: backend.configPath
    readonly property var allProviders: ProviderRegistry.providers

    // What this frontend does not have, so the settings page leaves it out: no
    // floating pill to place, no monitor to pin it to, and no interpreter to
    // choose — the app ships its own.
    readonly property bool pillControls: false
    readonly property bool interpreterControls: false
    readonly property var screenNames: []
    readonly property string monitorMode: "focused"
    readonly property string baseDir: ""

    readonly property bool autostartAvailable: backend.autostartAvailable
    readonly property bool autostart: backend.autostart
    function setAutostart(enabled) {
        backend.setAutostart(enabled);
    }

    function providerIcon(provider) {
        var file = provider && provider.icon ? provider.icon : "";
        return file === "" ? "" : root.iconDir + file;
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    // The same JSON file the backend reads its toggles and keys from. On Linux
    // it is also the Hyprland panel's, so fields this frontend has no use for
    // (pill mode, position, interpreter) are carried through untouched.
    property var settings: ({
            providers: {},
            keys: {},
            pollSec: 300,
            showChart: true,
            museQuota: false,
            antigravityChartFilter: "both"
        })
    property bool showSettings: false
    readonly property string antigravityChartFilter: root.settings.antigravityChartFilter || "both"

    function loadSettings() {
        var d = {};
        try {
            d = JSON.parse(backend.loadSettings() || "{}") || {};
        } catch (e) {}
        var s = Object.assign({}, d);
        s.providers = d.providers || {};
        s.keys = d.keys || {};
        s.pollSec = d.pollSec || 300;
        s.showChart = d.showChart !== false;
        s.museQuota = d.museQuota === true;
        s.antigravityChartFilter = d.antigravityChartFilter || "both";
        root.settings = s;
    }

    function saveSettings() {
        backend.saveSettings(JSON.stringify(root.settings));
    }

    function setSetting(section, key, value) {
        var s = JSON.parse(JSON.stringify(root.settings));
        s[section][key] = value;
        root.settings = s;
        root.saveSettings();
    }

    function setSetting2(key, value) {
        var s = JSON.parse(JSON.stringify(root.settings));
        s[key] = value;
        root.settings = s;
        root.saveSettings();
    }

    function providerEnabled(id) {
        return ProviderRegistry.enabled(root.settings, id);
    }

    // ── Provider state ───────────────────────────────────────────────────────
    property var providers: []
    property string activeId: ""
    property string errorText: ""
    readonly property bool loading: backend.busy
    property int updatedAt: 0
    property double nowTick: new Date().getTime()
    readonly property color dangerColor: "#ff4d4d"

    property string chartWindow: "weekly"
    property string chartGranularity: "7d"
    property string activeSubTab: "usage"
    readonly property bool activeHasStats: {
        var p = activeProvider();
        return p && (p.id === "claude" || p.id === "openai" || p.id === "copilot" || p.id === "muse" || p.id === "cursor" || p.id === "cline");
    }

    function activeProvider() {
        if (root.providers.length === 0)
            return null;
        for (var i = 0; i < root.providers.length; i++) {
            if (root.providers[i].id === root.activeId)
                return root.providers[i];
        }
        return root.providers[0];
    }

    readonly property color activeAccent: {
        var p = activeProvider();
        return p ? p.accent : "#cc785c";
    }

    function windowsForProvider(id) {
        for (var i = 0; i < root.providers.length; i++) {
            if (root.providers[i].id === id)
                return root.providers[i].chartWindows || [];
        }
        return [];
    }

    function windowForProvider(id, gran) {
        var wins = windowsForProvider(id);
        if (wins.length === 0)
            return root.chartWindow;
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].granularity === gran)
                return wins[i].id;
        }
        return wins[wins.length - 1].id;
    }

    function windowGranularity(win) {
        var wins = windowsForProvider(root.activeId);
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].id === win)
                return wins[i].granularity;
        }
        return "";
    }

    onActiveIdChanged: {
        activeSubTab = "usage";
        var win = windowForProvider(root.activeId, root.chartGranularity);
        if (root.chartWindow !== win)
            root.chartWindow = win;
        root.publishTray();
    }

    function selectChartWindow(id) {
        root.chartWindow = id;
        var gran = windowGranularity(id);
        if (gran !== "")
            root.chartGranularity = gran;
    }

    function countdownFor(resetAt) {
        return Format.countdownFromEpoch(resetAt, root.nowTick);
    }

    // The tray icon draws the active tab's first slot as a ring, and its
    // tooltip lists every provider — the glance the Hyprland pill gives.
    function publishTray() {
        var p = root.activeProvider();
        var slot = p && p.slots && p.slots.length > 0 ? p.slots[0] : null;
        var lines = ["AI Usage"];
        for (var i = 0; i < root.providers.length; i++) {
            var q = root.providers[i];
            if (q.label && q.summary && q.summary.text)
                lines.push(q.label + ": " + q.summary.text);
        }
        backend.publishTrayState(slot ? (slot.pct || 0) : -1, slot ? String(slot.color || "") : "", lines.join("\n"));
    }

    // ── Backend fetch ────────────────────────────────────────────────────────
    function applySnapshot(text) {
        try {
            var data = JSON.parse((text || "").trim());
            root.providers = data.providers || [];
            root.updatedAt = data.updatedAt || 0;
            var stillThere = false;
            for (var i = 0; i < root.providers.length; i++)
                if (root.providers[i].id === root.activeId)
                    stillThere = true;
            if (!stillThere)
                root.activeId = data.active || (root.providers[0] || {}).id || "";
            root.errorText = "";
            root.nowTick = new Date().getTime();
            root.recordHistory();
            root.publishTray();
        } catch (e) {
            root.errorText = "usage backend returned no data";
        }
    }

    function refresh() {
        backend.refresh();
    }

    Timer {
        interval: Math.max(30, root.settings.pollSec || 300) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowTick = new Date().getTime()
    }

    // ── History ──────────────────────────────────────────────────────────────
    // The same state machine as the other frontends (UsageHistory.js) over the
    // same shared file, which aiusage.historyio owns here as it does behind
    // tools/sh/history-io on Linux.
    property var usageHistory: []
    readonly property int historyLimit: 10000
    property var historyStore: UsageHistory.newStore(root.historyLimit)
    property bool historySaving: false
    property string historyMsg: ""

    function syncUsageHistory() {
        if (root.usageHistory !== root.historyStore.history)
            root.usageHistory = root.historyStore.history;
    }

    function recordHistory() {
        UsageHistory.record(root.historyStore, UsageHistory.collect(root.providers), new Date().getTime());
        root.syncUsageHistory();
        root.saveHistory();
    }

    function saveHistory() {
        if (root.historySaving)
            return;
        var batch = UsageHistory.take(root.historyStore);
        if (!batch)
            return;
        root.historySaving = true;
        historySaveTimeout.restart();
        backend.history(batch.op, JSON.stringify(batch.points));
    }

    function finishHistorySave(result) {
        historySaveTimeout.stop();
        root.historySaving = false;
        var res = null;
        try {
            res = JSON.parse(result);
        } catch (e) {}
        if (!res || res.error) {
            UsageHistory.failed(root.historyStore);
            return;
        }
        UsageHistory.done(root.historyStore, res.data);
        root.syncUsageHistory();
        root.saveHistory();
    }

    function exportHistory() {
        backend.history("export", "");
    }

    // A save that never answers would hold its batch in flight for the rest of
    // the session. failed() is idempotent, so a late answer after this is fine.
    Timer {
        id: historySaveTimeout
        interval: 30000
        onTriggered: {
            root.historySaving = false;
            UsageHistory.failed(root.historyStore);
        }
    }

    Timer {
        id: historyMsgTimer
        interval: 6000
        onTriggered: root.historyMsg = ""
    }

    Connections {
        target: backend

        function onSnapshotReady(text) {
            root.applySnapshot(text);
        }

        function onRefreshFailed(message) {
            root.errorText = message;
        }

        function onHistoryFinished(op, result) {
            if (op === "autoload") {
                try {
                    var r = JSON.parse(result);
                    if (r && Array.isArray(r.data)) {
                        UsageHistory.adopt(root.historyStore, r.data);
                        root.syncUsageHistory();
                    }
                } catch (e) {}
                UsageHistory.opened(root.historyStore);
                root.saveHistory();
            } else if (op === "export") {
                try {
                    var x = JSON.parse(result);
                    root.historyMsg = x.path ? "Saved to " + x.path : (x.error || "Export failed");
                } catch (e) {
                    root.historyMsg = "Export failed";
                }
                historyMsgTimer.restart();
            } else {
                root.finishHistorySave(result);
            }
        }
    }

    Component.onCompleted: {
        root.loadSettings();
        backend.history("autoload", "");
    }

    // ── Window ───────────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: root.hide()
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(0.09, 0.10, 0.13, 0.97)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(0.06, 0.07, 0.09, 0.97)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0.04, 0.045, 0.06, 0.98)
            }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.18)
        }
    }

    // Capped height, so the settings page scrolls rather than running off the
    // screen — see the same Flickable in AiUsageShell.qml.
    Flickable {
        id: contentFlick
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        QC.ScrollBar.vertical: QC.ScrollBar {
            policy: contentFlick.interactive ? QC.ScrollBar.AsNeeded : QC.ScrollBar.AlwaysOff
            width: 6
        }

        PopupContent {
            id: mainColumn
            width: contentFlick.width
            shell: root
        }
    }
}
