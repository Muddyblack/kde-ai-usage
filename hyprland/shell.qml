import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic as QC
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string baseDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    // Shared provider backend used independently of either desktop frontend.
    readonly property string snapshotCommand: baseDir + "/../package/contents/tools/sh/get-usage-snapshot"
    readonly property string iconSource: "file://" + baseDir + "/../package/contents/icons/org.muddyblack.aiUsageWidget.svg"

    // Shared with the Plasma widget: both variants mirror history to this file.
    readonly property string historyDir: {
        var xdg = Quickshell.env("XDG_DATA_HOME");
        var base = (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.local/share");
        return base + "/ai-usage-widget";
    }
    readonly property string historyPath: historyDir + "/usage-history-latest.json"

    // Settings the in-popup page writes; the snapshot script reads the same file
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
        }
    ]

    // Live settings model. providers[id] === false → hidden; keys[*] → API keys.
    property var settings: ({
            providers: {},
            keys: {},
            pollSec: 300,
            showChart: true,
            pillMode: "always",
            position: "top-right"
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

    function providerEnabled(id) {
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
                        position: d.position || "top-right"
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
            command: ["sh", "-c", "WIDGET_HISTORY_JSON=\"$1\" \"$2\" export", "ai-usage", JSON.stringify(root.usageHistory), tool]
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

    // Unified usage history: [{t, s, w, cp, cw, kr, ag, or, mv, gr}] — same format
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

    // ── Chart window mapping (mirrors Plasma's _windowForTab) ────────────────
    function windowsForProvider(id) {
        var H = 3600000;
        if (id === "claude")
            return [
                {
                    id: "session",
                    key: "s",
                    label: "5H",
                    size: 5 * H
                },
                {
                    id: "day",
                    key: "s",
                    label: "24H",
                    size: 24 * H
                },
                {
                    id: "weekly",
                    key: "w",
                    label: "7D",
                    size: 168 * H
                }
            ];
        if (id === "openai")
            return [
                {
                    id: "codex_primary",
                    key: "cp",
                    label: "5H",
                    size: 5 * H
                },
                {
                    id: "codex_day",
                    key: "cp",
                    label: "24H",
                    size: 24 * H
                },
                {
                    id: "codex_weekly",
                    key: "cw",
                    label: "7D",
                    size: 168 * H
                }
            ];
        if (id === "kiro")
            return [
                {
                    id: "kiro",
                    key: "kr",
                    label: "30D",
                    size: 720 * H
                }
            ];
        if (id === "antigravity")
            return [
                {
                    id: "antigravity",
                    key: "ag",
                    label: "30D",
                    size: 720 * H
                }
            ];
        if (id === "openrouter")
            return [
                {
                    id: "openrouter",
                    key: "or",
                    label: "30D",
                    size: 720 * H
                }
            ];
        if (id === "mistral")
            return [
                {
                    id: "mistral",
                    key: "mv",
                    label: "30D",
                    size: 720 * H
                }
            ];
        if (id === "grok")
            return [
                {
                    id: "grok",
                    key: "gr",
                    label: "30D",
                    size: 720 * H
                }
            ];
        return [];
    }

    function windowGranularity(win) {
        if (win === "session" || win === "codex_primary")
            return "5h";
        if (win === "day" || win === "codex_day")
            return "24h";
        if (win === "weekly" || win === "codex_weekly")
            return "7d";
        return "";
    }

    function windowForProvider(id, gran) {
        if (id === "claude")
            return gran === "5h" ? "session" : gran === "24h" ? "day" : "weekly";
        if (id === "openai")
            return gran === "5h" ? "codex_primary" : gran === "24h" ? "codex_day" : "codex_weekly";
        var wins = windowsForProvider(id);
        return wins.length > 0 ? wins[0].id : "weekly";
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

    // ── Countdown chips (Plasma formatCountdown port) ────────────────────────
    function countdownFor(resetAt) {
        if (!resetAt || resetAt <= 0)
            return "";
        var diffMs = resetAt * 1000 - root.nowTick;
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

    // ── History persistence ──────────────────────────────────────────────────
    function recordHistory() {
        var patch = {};
        var any = false;
        for (var i = 0; i < root.providers.length; i++) {
            var hist = root.providers[i].hist;
            if (!hist)
                continue;
            for (var k in hist) {
                patch[k] = hist[k];
                any = true;
            }
        }
        if (!any)
            return;
        var history = root.usageHistory.slice();
        var now = new Date().getTime();
        if (history.length > 0 && now - history[history.length - 1].t < 120000) {
            var last = history[history.length - 1];
            for (var kk in patch)
                last[kk] = patch[kk];
            history[history.length - 1] = last;
        } else {
            patch.t = now;
            history.push(patch);
        }
        if (history.length > root.historyLimit)
            history = history.slice(history.length - root.historyLimit);
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
                        root.usageHistory = data;
                } catch (e) {}
            }
        }
    }

    // ── Snapshot fetch ───────────────────────────────────────────────────────
    function applySnapshot(text) {
        root.loading = false;
        try {
            var data = JSON.parse((text || "").trim());
            root.providers = data.providers || [];
            root.updatedAt = data.updatedAt || 0;
            // Keep the active tab if it's still present; otherwise fall back to
            // the snapshot's suggestion or the first provider (e.g. after the
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
            root.errorText = "snapshot parse failed";
        }
    }

    function refresh() {
        if (snapshotProcess.running)
            return;
        root.loading = true;
        snapshotProcess.exec({
            command: [root.snapshotCommand],
            workingDirectory: root.baseDir + "/.."
        });
    }

    Process {
        id: snapshotProcess
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
                root.errorText = "snapshot command failed";
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
            root.popupOpen = !root.popupOpen;
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
    PanelWindow {
        id: panel
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
            iconSource: root.iconSource
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
            onClicked: root.popupOpen = !root.popupOpen
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
            visible: root.popupOpen
            color: "transparent"
            aboveWindows: true
            exclusiveZone: 0

            onVisibleChanged: {
                if (!visible && root.popupOpen)
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

            ColumnLayout {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 12

                // ── Header ──────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22

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
                            visible: !root.showSettings
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
                            visible: !root.showSettings
                            colorization: 1
                            colorizationColor: root.activeAccent
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: root.iconSource
                            sourceSize.width: 18
                            sourceSize.height: 18
                            visible: root.showSettings
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

                // ── Tab bar (Plasma style: fill-width, dot + name) ──────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.providers.length > 1 && !root.showSettings

                    Repeater {
                        model: root.providers

                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool isActive: root.activeId === modelData.id

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
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
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle {
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
                        return p && p.detail !== "" && p.error === "";
                    }
                    Layout.fillWidth: true
                    text: {
                        var p = root.activeProvider();
                        return p ? p.detail : "";
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
                            return p ? p.rows : [];
                        }

                        UsageRow {
                            required property var modelData
                            label: modelData.label || ""
                            value: modelData.value || 0
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
                    extraVisible: !root.showSettings && root.settings.showChart && root.activeProvider() && root.activeProvider().hasChart !== false
                    usageHistory: root.usageHistory
                    windows: root.windowsForProvider(root.activeId)
                    chartWindow: root.chartWindow
                    accent: root.activeAccent
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

        HyprlandFocusGrab {
            id: popupFocusGrab
            windows: [popup]
            active: root.popupOpen
            onCleared: {
                if (root.popupOpen)
                    root.popupOpen = false;
            }
        }
    }
}
