import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic as QC
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
// Shared with the Plasma widget. Quickshell sandboxes the QML engine to the
// config root, so these imports only resolve because the root is the repository
// root (see ../shell.qml) rather than this directory — from `hyprland/` they
// would escape it and load as qrc:/qs-blackhole.
import "../package/contents/code/Format.js" as Format
import "../package/contents/code/UsageHistory.js" as UsageHistory

ShellRoot {
    id: root

    readonly property string baseDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    // Shared provider backend — the same executable the Plasma widget calls.
    readonly property string backendCommand: baseDir + "/../package/contents/tools/sh/get-ai-usage"
    readonly property string iconSource: "file://" + baseDir + "/../package/contents/icons/org.muddyblack.aiUsageWidget.svg"
    readonly property string iconDir: "file://" + baseDir + "/../package/contents/icons/"

    // Brand logo for a provider, or "" when the backend ships no artwork for it
    // (callers fall back to the plain accent dot). The id→file mapping lives in
    // the backend contract so both frontends agree on it.
    function providerIcon(provider) {
        var file = provider && provider.icon ? provider.icon : "";
        return file === "" ? "" : root.iconDir + file;
    }

    // Shared with the Plasma widget: both variants mirror history to this file.
    readonly property string historyDir: {
        var xdg = Quickshell.env("XDG_DATA_HOME");
        var base = (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.local/share");
        return base + "/ai-usage-widget";
    }
    readonly property string historyPath: historyDir + "/usage-history-latest.json"

    // Settings the in-popup page writes; the backend reads the same file
    // (AI_USAGE_CONFIG / XDG_CONFIG_HOME) for provider toggles + API keys.
    readonly property string configDir: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        var base = (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.config");
        return base + "/ai-usage-widget";
    }
    readonly property string configPath: configDir + "/hyprland-settings.json"

    // All known providers, in display order (used by the settings toggles).
    readonly property var allProviders: [
        {
            id: "claude",
            label: "Claude",
            accent: "#cc785c"
        },
        {
            id: "antigravity",
            label: "Antigravity",
            accent: "#4285f4"
        },
        {
            id: "openai",
            label: "OpenAI",
            accent: "#10a37f"
        },
        {
            id: "kiro",
            label: "Kiro",
            accent: "#8b5cf6"
        },
        {
            id: "mistral",
            label: "Mistral",
            accent: "#ff7000"
        },
        {
            id: "openrouter",
            label: "OpenRouter",
            accent: "#9333ea"
        },
        {
            id: "grok",
            label: "Grok",
            accent: "#e6e6e6"
        },
        {
            id: "zai",
            label: "Z.AI",
            accent: "#126ef4"
        },
        {
            id: "copilot",
            label: "Copilot",
            accent: "#8b5cf6"
        },
        {
            id: "deepseek",
            label: "DeepSeek",
            accent: "#4f8cff"
        }
    ]

    // Live settings model. providers[id] === false → hidden; keys[*] → API keys.
    property var settings: ({
            providers: {},
            keys: {},
            pollSec: 300,
            showChart: true,
            pillMode: "always",
            position: "top-right",
            monitor: "focused",
            pythonPath: ""
        })
    property bool showSettings: false
    property bool pillRevealed: false
    property bool trayPillRevealed: false
    readonly property string pillMode: root.settings.pillMode || "always"
    readonly property string windowPosition: root.settings.position || "top-right"
    readonly property bool positionTop: root.windowPosition.indexOf("top-") === 0
    readonly property bool positionBottom: root.windowPosition.indexOf("bottom-") === 0
    readonly property bool positionLeft: root.windowPosition.indexOf("-left") !== -1
    readonly property bool positionCenter: root.windowPosition.indexOf("-center") !== -1
    readonly property bool positionRight: root.windowPosition.indexOf("-right") !== -1
    readonly property bool pillShown: root.pillMode === "always" || root.trayPillRevealed || (root.pillMode === "hover" && (root.pillRevealed || root.popupOpen))

    // ── Output selection ─────────────────────────────────────────────────────
    // "focused" → a single screenless window, which the compositor keeps on the
    // focused output; "all" → one pill per connected output; anything else is a
    // monitor name. A name that is not currently connected falls back to
    // "focused" rather than leaving the user with no pill at all.
    readonly property string monitorMode: root.settings.monitor || "focused"
    readonly property var panelScreens: {
        if (root.monitorMode === "all")
            return Quickshell.screens;
        if (root.monitorMode !== "focused") {
            var all = Quickshell.screens;
            for (var i = 0; i < all.length; i++)
                if (all[i].name === root.monitorMode)
                    return [all[i]];
        }
        return [null];
    }

    // With a pill on every output, only one popup may be open at a time: the one
    // belonging to the pill that was clicked (or, over IPC, the focused monitor).
    property string popupScreenName: ""

    function popupOwnedBy(screen) {
        if (root.panelScreens.length < 2)
            return true;
        return !!screen && screen.name === root.popupScreenName;
    }

    function openPopupOn(screen) {
        root.popupScreenName = screen ? screen.name : "";
        root.popupOpen = true;
    }

    // Where an IPC-driven popup should appear when several pills exist.
    function focusedScreenName() {
        var m = Hyprland.focusedMonitor;
        if (m && m.name)
            return m.name;
        var s = root.panelScreens[0];
        return s ? s.name : "";
    }

    function providerEnabled(id) {
        if (id === "zai" || id === "copilot" || id === "deepseek")
            return root.settings.providers[id] === true;
        return root.settings.providers[id] !== false;
    }

    Process {
        id: settingsLoad
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || printf '{}'", "ai-usage", root.configPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim());
                    root.settings = {
                        providers: d.providers || {},
                        keys: d.keys || {},
                        pollSec: d.pollSec || 300,
                        showChart: d.showChart !== false,
                        pillMode: d.pillMode || (d.floatingPill === false ? "tray" : "always"),
                        position: d.position || "top-right",
                        monitor: d.monitor || "focused",
                        pythonPath: d.pythonPath || ""
                    };
                } catch (e) {}
            }
        }
    }

    Process {
        id: settingsSave
    }

    function saveSettings() {
        var json = JSON.stringify(root.settings);
        settingsSave.exec({
            command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"", "ai-usage", json, root.configPath]
        });
    }

    // Mutate one nested settings field and persist. `section` is "providers" or
    // "keys"; assigning a fresh object makes the binding re-evaluate.
    function setSetting(section, key, value) {
        var s = JSON.parse(JSON.stringify(root.settings));
        s[section][key] = value;
        root.settings = s;
        root.saveSettings();
    }

    // Mutate a top-level settings field (pollSec, showChart) and persist.
    function setSetting2(key, value) {
        var s = JSON.parse(JSON.stringify(root.settings));
        s[key] = value;
        root.settings = s;
        root.saveSettings();
    }

    property string historyMsg: ""

    // Export a timestamped copy of the shared history via history-io.
    function exportHistory() {
        var tool = root.baseDir + "/../package/contents/tools/sh/history-io";
        exportProcess.exec({
            command: ["sh", "-c", "PYTHON3=\"$1\" WIDGET_HISTORY_JSON=\"$2\" exec \"$3\" export", "ai-usage", root.settings.pythonPath || "", JSON.stringify(root.usageHistory), tool]
        });
    }

    Process {
        id: exportProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(this.text.trim());
                    root.historyMsg = r.path ? "Saved to " + r.path : (r.error || "Export failed");
                } catch (e) {
                    root.historyMsg = "Export failed";
                }
                historyMsgTimer.restart();
            }
        }
    }

    Timer {
        id: historyMsgTimer
        interval: 6000
        onTriggered: root.historyMsg = ""
    }

    property var providers: []
    property string activeId: ""
    property string errorText: ""
    property bool loading: false
    property bool popupOpen: false
    property int updatedAt: 0

    // Unified usage history: [{t, s, w, cp, cw, kr, ag, or, mv, gr, za, gh, ds}] — same format
    // as the Plasma widget so the chart survives across both.
    property var usageHistory: []
    readonly property int historyLimit: 500

    // Clock driving the countdown chips (30 s tick).
    property double nowTick: new Date().getTime()

    readonly property color dangerColor: "#ff4d4d"

    // Chart state: remembered granularity carries across tabs like in Plasma.
    property string chartWindow: "weekly"
    property string chartGranularity: "7d"

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

    // ── Chart ranges ─────────────────────────────────────────────────────────
    // Which history series a provider has, and how wide each range is, comes
    // from the backend (chartWindows in the contract) — no table here.
    function windowsForProvider(id) {
        for (var i = 0; i < root.providers.length; i++) {
            if (root.providers[i].id === id)
                return root.providers[i].chartWindows || [];
        }
        return [];
    }

    // Window ID for a provider at the remembered granularity, so the selected
    // range carries across tabs.
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
        var win = windowForProvider(root.activeId, root.chartGranularity);
        if (root.chartWindow !== win)
            root.chartWindow = win;
    }

    function selectChartWindow(id) {
        root.chartWindow = id;
        var gran = windowGranularity(id);
        if (gran !== "")
            root.chartGranularity = gran;
    }

    // ── Countdown chips ──────────────────────────────────────────────────────
    function countdownFor(resetAt) {
        return Format.countdownFromEpoch(resetAt, root.nowTick);
    }

    // ── History persistence ──────────────────────────────────────────────────
    function recordHistory() {
        var history = UsageHistory.merge(root.usageHistory, UsageHistory.collect(root.providers), new Date().getTime(), root.historyLimit);
        if (history === root.usageHistory)
            return;
        root.usageHistory = history;
        saveProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"", "ai-usage", JSON.stringify(history), root.historyPath]
        });
    }

    Process {
        id: saveProcess
    }

    Process {
        id: loadProcess
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || printf '[]'", "ai-usage", root.historyPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data))
                        root.usageHistory = UsageHistory.normalize(data, root.historyLimit);
                } catch (e) {}
            }
        }
    }

    // ── Backend fetch ────────────────────────────────────────────────────────
    function applySnapshot(text) {
        root.loading = false;
        try {
            var data = JSON.parse((text || "").trim());
            root.providers = data.providers || [];
            root.updatedAt = data.updatedAt || 0;
            // Keep the active tab if it's still present; otherwise fall back to
            // the backend's suggestion or the first provider (e.g. after the
            // active provider is disabled in settings).
            var stillThere = false;
            for (var i = 0; i < root.providers.length; i++)
                if (root.providers[i].id === root.activeId)
                    stillThere = true;
            if (!stillThere)
                root.activeId = data.active || (root.providers[0] || {}).id || "";
            root.errorText = "";
            root.nowTick = new Date().getTime();
            root.recordHistory();
        } catch (e) {
            root.errorText = "usage backend returned no data";
        }
    }

    function refresh() {
        if (backendProcess.running)
            return;
        root.loading = true;
        // $PYTHON3 overrides the interpreter search in tools/sh/python-interp.sh.
        // Passed as a positional arg rather than interpolated into the script so
        // a path with spaces or shell metacharacters stays intact; an empty
        // value reads as unset there, which is the auto-detect default.
        backendProcess.exec({
            command: ["sh", "-c", "PYTHON3=\"$1\" exec \"$2\" --all", "ai-usage", root.settings.pythonPath || "", root.backendCommand],
            workingDirectory: root.baseDir + "/.."
        });
    }

    Process {
        id: backendProcess
        stdout: StdioCollector {
            onStreamFinished: root.applySnapshot(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.errorText = this.text.trim().split("\n")[0];
            }
        }
        onExited: function (exitCode) {
            root.loading = false;
            if (exitCode !== 0 && root.errorText === "")
                root.errorText = "usage backend failed";
        }
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

    // `qs ipc call panel toggle` from a keybind or script
    IpcHandler {
        target: "panel"

        function toggle(): void {
            if (root.popupOpen) {
                root.popupOpen = false;
                return;
            }
            // Pin it to the focused output, so a keybind opens exactly one popup
            // even when the pill is mirrored across every monitor.
            root.popupScreenName = root.focusedScreenName();
            root.popupOpen = true;
        }
        function refresh(): void {
            root.refresh();
        }
        function setTab(id: string): void {
            root.activeId = id;
        }
        function settings(): void {
            root.showSettings = !root.showSettings;
        }
        function trayEnter(): void {
            trayPillHideTimer.stop();
            root.trayPillRevealed = true;
        }
        function trayLeave(): void {
            trayPillHideTimer.restart();
        }
        function quit(): void {
            Qt.quit();
        }
    }

    Timer {
        id: trayPillHideTimer
        interval: 350
        onTriggered: root.trayPillRevealed = false
    }

    // ── Panel item ───────────────────────────────────────────────────────────
    // One instance per entry in panelScreens: a single screenless window in the
    // usual case, or one per output when the user pins the pill to all monitors.
    Variants {
        model: root.panelScreens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            visible: root.pillMode !== "tray" || root.trayPillRevealed
            implicitWidth: root.pillShown ? pill.implicitWidth + 12 : 72
            implicitHeight: root.pillShown ? 42 : 4
            color: "transparent"
            aboveWindows: true
            exclusiveZone: 0

            anchors {
                top: root.positionTop
                bottom: root.positionBottom
                left: root.positionLeft || root.positionCenter
                right: root.positionRight
            }

            margins {
                top: root.positionTop ? 8 : 0
                bottom: root.positionBottom ? 8 : 0
                left: root.positionLeft ? 12 : (root.positionCenter && panel.screen ? Math.max(0, (panel.screen.width - panel.width) / 2) : 0)
                right: root.positionRight ? 12 : 0
            }

            PanelPill {
                id: pill
                visible: root.pillShown
                anchors.centerIn: parent
                // The active provider's brand logo, falling back to the app icon for
                // providers that ship no artwork. PanelSlot tints whichever it gets to
                // the slot's severity colour, so the panel still reads at a glance.
                readonly property string brandLogo: root.providerIcon(root.activeProvider())
                iconSource: brandLogo !== "" ? brandLogo : root.iconSource
                active: root.popupOpen
                slots: {
                    var p = root.activeProvider();
                    if (root.loading && root.providers.length === 0)
                        return [
                            {
                                pct: 0,
                                color: "#cc785c",
                                text: "…",
                                tooltip: "Loading"
                            }
                        ];
                    return p && p.slots ? p.slots : [
                        {
                            pct: 0,
                            color: "#cc785c",
                            text: "—",
                            tooltip: "No data"
                        }
                    ];
                }
                stale: {
                    var p = root.activeProvider();
                    return root.errorText !== "" || (p ? !!p.stale : false);
                }
                hasError: {
                    var p = root.activeProvider();
                    return root.errorText !== "" || (p ? p.error !== "" : false);
                }
                onClicked: {
                    if (root.popupOpen && root.popupOwnedBy(panel.screen))
                        root.popupOpen = false;
                    else
                        root.openPopupOn(panel.screen);
                }
            }

            Rectangle {
                visible: root.pillMode === "hover" && !root.pillShown
                anchors.fill: parent
                color: "transparent"
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        pillHideTimer.stop();
                        root.pillRevealed = true;
                    }
                }
            }

            Timer {
                id: pillHideTimer
                interval: 650
                onTriggered: {
                    if (root.pillMode === "hover" && !pill.hovered && !root.popupOpen)
                        root.pillRevealed = false;
                }
            }

            // Hover tooltip (custom: the QQC2 ToolTip style needs Kirigami, which
            // isn't shipped with Quickshell)
            Timer {
                id: tooltipDelay
                interval: 500
                onTriggered: tooltipPopup.visible = pill.hovered && !root.popupOpen && pill.tooltipText !== ""
            }
            Connections {
                target: pill
                function onHoveredChanged() {
                    if (pill.hovered) {
                        pillHideTimer.stop();
                        tooltipDelay.restart();
                    } else {
                        tooltipDelay.stop();
                        tooltipPopup.visible = false;
                        pillHideTimer.restart();
                    }
                }
            }

            PopupWindow {
                id: tooltipPopup
                implicitWidth: tooltipLabel.implicitWidth + 20
                implicitHeight: tooltipLabel.implicitHeight + 14
                visible: false
                color: "transparent"

                anchor.window: panel
                anchor.rect.x: root.positionLeft ? 0 : (root.positionCenter ? (panel.width - width) / 2 : panel.width - width)
                anchor.rect.y: root.positionTop ? panel.height + 4 : -height - 4

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(0.04, 0.045, 0.06, 0.94)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: pill.tooltipText
                        color: "#e2e8f0"
                        font.pixelSize: 11
                    }
                }
            }

            // ── Popup (Plasma full representation port) ──────────────────────────
            PanelWindow {
                id: popup
                implicitWidth: 460
                implicitHeight: Math.min(680, mainColumn.implicitHeight + 40)
                visible: root.popupOpen && root.popupOwnedBy(panel.screen)
                color: "transparent"
                aboveWindows: true
                exclusiveZone: 0

                onVisibleChanged: {
                    // Only the popup that actually owns the open state may close it —
                    // the mirrored windows on other outputs are permanently hidden and
                    // would otherwise slam it shut the moment one opened.
                    if (!visible && root.popupOpen && root.popupOwnedBy(panel.screen))
                        root.popupOpen = false;
                }

                anchors {
                    top: root.positionTop
                    bottom: root.positionBottom
                    left: root.positionLeft || root.positionCenter
                    right: root.positionRight
                }
                margins {
                    top: root.positionTop ? (root.pillShown ? 44 : 8) : 0
                    bottom: root.positionBottom ? (root.pillShown ? 44 : 8) : 0
                    left: root.positionLeft ? 12 : (root.positionCenter && popup.screen ? Math.max(0, (popup.screen.width - popup.width) / 2) : 0)
                    right: root.positionRight ? 12 : 0
                }

                // Glassmorphism backdrop: tinted gradient, accent glow, top highlight
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(0.09, 0.10, 0.13, 0.96)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.rgba(0.06, 0.07, 0.09, 0.96)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(0.04, 0.045, 0.06, 0.97)
                        }
                    }
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true

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

                // The popup height is capped, but the settings page is far taller than
                // the cap once every provider and API-key field is listed — without a
                // Flickable the last rows (Python path, Save) are simply unreachable.
                Flickable {
                    id: contentFlick
                    anchors.fill: parent
                    anchors.margins: 20
                    clip: true
                    contentWidth: width
                    contentHeight: mainColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    // Leave wheel events to the chart's range controls when everything
                    // already fits, which is the usual case on the usage page.
                    interactive: contentHeight > height

                    QC.ScrollBar.vertical: QC.ScrollBar {
                        policy: contentFlick.interactive ? QC.ScrollBar.AsNeeded : QC.ScrollBar.AlwaysOff
                        width: 6
                    }

                    ColumnLayout {
                        id: mainColumn
                        width: contentFlick.width
                        spacing: 12

                        // ── Header ──────────────────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                id: headerBadge
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22

                                // Brand logos carry their own colours, so they render as-is.
                                // The generic app icon has none, so it is tinted to the active
                                // accent over a soft halo — the settings page always uses it.
                                readonly property string brandLogo: root.showSettings ? "" : root.providerIcon(root.activeProvider())

                                Image {
                                    id: headerHalo
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: root.iconSource
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: headerHalo
                                    source: headerHalo
                                    visible: !root.showSettings && headerBadge.brandLogo === ""
                                    colorization: 1
                                    colorizationColor: root.activeAccent
                                    opacity: 0.22
                                }
                                Image {
                                    id: headerIcon
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: root.iconSource
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: headerIcon
                                    source: headerIcon
                                    visible: !root.showSettings && headerBadge.brandLogo === ""
                                    colorization: 1
                                    colorizationColor: root.activeAccent
                                }
                                Image {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: headerBadge.brandLogo !== "" ? headerBadge.brandLogo : root.iconSource
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    fillMode: Image.PreserveAspectFit
                                    visible: root.showSettings || headerBadge.brandLogo !== ""
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: {
                                        if (root.showSettings)
                                            return "Settings";
                                        var p = root.activeProvider();
                                        return (p ? p.label : "AI") + " Usage";
                                    }
                                    font.bold: true
                                    font.pixelSize: 15
                                    color: "#f8fafc"
                                }
                                Text {
                                    visible: root.showSettings
                                    text: "Providers, API keys and refresh"
                                    font.pixelSize: 10
                                    opacity: 0.5
                                    color: "#f8fafc"
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // Settings gear / back toggle
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 26
                                radius: 6
                                color: gearMouse.containsMouse || root.showSettings ? Qt.rgba(1, 1, 1, 0.11) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: root.showSettings ? "←" : "⚙"
                                    color: "#e2e8f0"
                                    font.pixelSize: 14
                                    opacity: gearMouse.containsMouse || root.showSettings ? 1.0 : 0.6
                                }
                                MouseArea {
                                    id: gearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showSettings = !root.showSettings
                                }
                            }

                            Rectangle {
                                visible: !root.showSettings
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 26
                                radius: 6
                                color: refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "⟳"
                                    color: "#e2e8f0"
                                    font.pixelSize: 14
                                    opacity: refreshMouse.containsMouse ? 1.0 : 0.6
                                    rotation: root.loading ? refreshSpin.value : 0
                                }
                                // simple spin while a refresh is running
                                Item {
                                    id: refreshSpin
                                    property real value: 0
                                    NumberAnimation on value {
                                        running: root.loading
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                    }
                                }

                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.refresh()
                                }
                            }
                        }

                        // ── Settings page ────────────────────────────────────────────
                        SettingsPage {
                            visible: root.showSettings
                            Layout.fillWidth: true
                            shell: root
                        }

                        // ── Tab bar (Plasma style: logo + name) ─────────────────────
                        // A Flow rather than a row: the enabled provider set is
                        // user-configurable (up to eleven) while the popup width is fixed,
                        // so tabs have to wrap onto another line instead of running off the
                        // edge — and each one has to be as wide as its own label, or the
                        // longest ("Antigravity") gets clipped by its own border.
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root.providers.length > 1 && !root.showSettings

                            Repeater {
                                model: root.providers

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool isActive: root.activeId === modelData.id

                                    width: tabContent.implicitWidth + 18
                                    height: 32
                                    radius: 6
                                    color: isActive ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                                    border.width: 1
                                    border.color: isActive ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
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
                                        onClicked: {
                                            root.activeId = modelData.id;
                                            root.refresh();
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: parent.containsMouse && !isActive ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                        }
                                    }

                                    RowLayout {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Image {
                                            readonly property string logo: root.providerIcon(modelData)
                                            visible: logo !== ""
                                            source: logo
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 12
                                            sourceSize.width: 12
                                            sourceSize.height: 12
                                            fillMode: Image.PreserveAspectFit
                                            opacity: isActive ? 1.0 : 0.55
                                        }
                                        Rectangle {
                                            visible: root.providerIcon(modelData) === ""
                                            Layout.preferredWidth: 8
                                            Layout.preferredHeight: 8
                                            radius: 4
                                            color: modelData.accent
                                            opacity: isActive ? 1.0 : 0.5
                                        }
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 12
                                            font.bold: isActive
                                            color: "#f8fafc"
                                            opacity: isActive ? 1.0 : 0.6
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !root.showSettings
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // ── Provider detail line (plan / account) ───────────────────
                        Text {
                            visible: {
                                if (root.showSettings)
                                    return false;
                                var p = root.activeProvider();
                                return p && p.summary.detail !== "" && p.error === "";
                            }
                            Layout.fillWidth: true
                            text: {
                                var p = root.activeProvider();
                                return p ? p.summary.detail : "";
                            }
                            color: "#94a3b8"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        // ── Error banner ────────────────────────────────────────────
                        Rectangle {
                            visible: {
                                if (root.showSettings)
                                    return false;
                                var p = root.activeProvider();
                                return p && p.error !== "";
                            }
                            Layout.fillWidth: true
                            Layout.preferredHeight: errText.implicitHeight + 18
                            radius: 6
                            color: Qt.rgba(0.45, 0.06, 0.06, 0.32)
                            border.width: 1
                            border.color: Qt.rgba(0.95, 0.30, 0.30, 0.32)

                            Text {
                                id: errText
                                anchors.fill: parent
                                anchors.margins: 9
                                text: {
                                    var p = root.activeProvider();
                                    return p ? p.error : "";
                                }
                                color: "#fecaca"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }

                        // ── Usage rows ──────────────────────────────────────────────
                        ColumnLayout {
                            visible: !root.showSettings
                            Layout.fillWidth: true
                            spacing: 12

                            Repeater {
                                model: {
                                    var p = root.activeProvider();
                                    return p ? p.quotaWindows : [];
                                }

                                UsageRow {
                                    required property var modelData
                                    label: modelData.label || ""
                                    value: modelData.pct || 0
                                    resetText: modelData.resetText || ""
                                    countdownText: root.countdownFor(modelData.resetAt || 0)
                                    detail: modelData.detail || ""
                                    barColor: root.activeAccent
                                    showMeter: modelData.showMeter !== false
                                }
                            }
                        }

                        // ── Usage chart ─────────────────────────────────────────────
                        UsageChart {
                            extraVisible: !root.showSettings && root.settings.showChart && root.activeProvider() && root.activeProvider().summary.hasChart !== false
                            usageHistory: root.usageHistory
                            windows: root.windowsForProvider(root.activeId)
                            chartWindow: root.chartWindow
                            accent: root.activeAccent
                            currency: root.activeProvider() ? (root.activeProvider().details.currency || "") : ""
                            onWindowSelected: function (id) {
                                root.selectChartWindow(id);
                            }
                        }

                        // ── Footer ──────────────────────────────────────────────────
                        RowLayout {
                            visible: !root.showSettings
                            Layout.fillWidth: true

                            Rectangle {
                                visible: root.errorText !== ""
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: root.dangerColor
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                visible: root.errorText !== ""
                                text: root.errorText
                                color: root.dangerColor
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: root.updatedAt > 0 && root.errorText === ""
                                text: "updated " + new Date(root.updatedAt * 1000).toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                                color: "#f8fafc"
                                opacity: 0.45
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // Same reasoning as the popup's onVisibleChanged: only the owning output
            // grabs focus, or the hidden mirrors would fight over it.
            HyprlandFocusGrab {
                id: popupFocusGrab
                windows: [popup]
                active: root.popupOpen && root.popupOwnedBy(panel.screen)
                onCleared: {
                    if (root.popupOpen && root.popupOwnedBy(panel.screen))
                        root.popupOpen = false;
                }
            }
        }
    }
}
