import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

ColumnLayout {
    id: statsSectionRoot

    property var stats: ({})
    property string providerId: ""
    property color accent: "#38bdf8"
    property string currency: "USD"

    readonly property bool hasStats: stats && stats.available === true
    // Every provider draws one per-day sparkline, but not every provider
    // counts tokens — the Copilot CLI records messages only (see stats.py).
    // Where the sessions went: repositories for Copilot, workspace folders for
    // Muse. One list, named by whichever the provider reported.
    readonly property var topGroups: stats.topRepositories || stats.topWorkspaces || []
    readonly property string topGroupsLabel: stats.topRepositories ? "Top repositories" : "Top workspaces"
    readonly property var dailySeries: stats.dailySeries || stats.dailyTokens || []
    readonly property string dailyUnit: stats.dailyUnit || "tokens"
    // Cursor reports its dashboard figures for the billing cycle, not a lifetime
    // total like the local CLI logs.
    readonly property string periodLabel: providerId === "cursor" ? "this billing cycle" : "all time"

    function formatTokens(n) {
        if (!n || n <= 0)
            return "0";
        if (n >= 1000000)
            return (n / 1000000).toFixed(2) + "M";
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

    function shortenModelName(name) {
        if (!name)
            return "";
        return name.replace(/gpt-4o-mini/g, "4o-mini").replace(/gpt-4o/g, "4o").replace(/gpt-4-turbo/g, "4-turbo").replace(/gpt-4-32k/g, "4-32k").replace(/gpt-4/g, "4").replace(/gpt-3\.5-turbo/g, "3.5-turbo").replace(/o1-mini/g, "o1-mini").replace(/o3-mini/g, "o3-mini").replace(/o4-mini/g, "o4-mini").replace(/claude-3-5-/g, "3.5-").replace(/claude-3-/g, "3-").replace(/claude-/g, "").replace(/-\d{8}$/, "").replace(/-20\d{2}-\d{2}-\d{2}$/, "");
    }

    Layout.fillWidth: true
    spacing: 12

    // ── Placeholder if no stats available ──────────────────────────────────────
    Rectangle {
        visible: !statsSectionRoot.hasStats
        Layout.fillWidth: true
        Layout.preferredHeight: noStatsText.implicitHeight + 24
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.03)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        Text {
            id: noStatsText
            anchors.centerIn: parent
            width: parent.width - 24
            text: {
                if (statsSectionRoot.providerId === "openai")
                    return "No Codex history yet.\nRun a Codex CLI session and stats will appear here.";
                if (statsSectionRoot.providerId === "copilot")
                    return "No local activity stats yet.\nRun the Copilot CLI to fill ~/.copilot/session-store.db";
                if (statsSectionRoot.providerId === "muse")
                    return "No Muse sessions yet.\nRun Muse Code and its own logs will appear here.";
                if (statsSectionRoot.providerId === "cursor")
                    return "No Cursor usage this billing cycle yet.\nRequests made with Cursor or cursor-agent will appear here.";
                return "No local activity stats yet.\nRun Claude Code to generate ~/.claude/stats-cache.json";
            }
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            color: "#94a3b8"
            wrapMode: Text.WordWrap
        }
    }

    // ── Stats Content ──────────────────────────────────────────────────────────
    ColumnLayout {
        visible: statsSectionRoot.hasStats
        Layout.fillWidth: true
        spacing: 10

        // Header with title and favorite model chip
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Activity Stats"
                font.pixelSize: 11
                font.bold: true
                color: "#f8fafc"
                opacity: 0.85
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: (statsSectionRoot.stats.favoriteModel || "") !== ""
                implicitHeight: 18
                implicitWidth: favLabel.implicitWidth + 14
                radius: 4
                color: Qt.rgba(statsSectionRoot.accent.r, statsSectionRoot.accent.g, statsSectionRoot.accent.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(statsSectionRoot.accent.r, statsSectionRoot.accent.g, statsSectionRoot.accent.b, 0.35)

                Text {
                    id: favLabel
                    anchors.centerIn: parent
                    text: "★ " + statsSectionRoot.shortenModelName(statsSectionRoot.stats.favoriteModel || "")
                    font.pixelSize: 9
                    font.bold: true
                    color: statsSectionRoot.accent
                }
            }
        }

        // Stat tiles grid (3 columns)
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            // Tokens
            StatTile {
                visible: (statsSectionRoot.stats.totalTokens || 0) > 0
                tileValue: statsSectionRoot.formatTokens(statsSectionRoot.stats.totalTokens || 0)
                tileLabel: "tokens"
                tileTip: "Total tokens across all models (" + statsSectionRoot.periodLabel + ")"
                accentColor: statsSectionRoot.accent
            }

            // Sessions
            StatTile {
                tileValue: Math.round(statsSectionRoot.stats.totalSessions || 0).toString()
                tileLabel: "sessions"
                tileTip: statsSectionRoot.formatTokens(statsSectionRoot.stats.totalMessages || 0) + " messages total"
                accentColor: statsSectionRoot.accent
            }

            // Active Days
            StatTile {
                tileValue: Math.round(statsSectionRoot.stats.activeDays || 0) + ((statsSectionRoot.stats.spanDays || 0) > 0 ? "/" + Math.round(statsSectionRoot.stats.spanDays) : "")
                tileLabel: "active days"
                tileTip: statsSectionRoot.stats.firstDate ? "Since " + statsSectionRoot.stats.firstDate : ""
                accentColor: statsSectionRoot.accent
            }

            // Streak
            StatTile {
                tileValue: Math.round(statsSectionRoot.stats.currentStreak || 0) + "d"
                tileLabel: "streak"
                tileSub: "best " + Math.round(statsSectionRoot.stats.longestStreak || 0) + "d"
                tileTip: "Current consecutive-day streak\nLongest: " + Math.round(statsSectionRoot.stats.longestStreak || 0) + " days"
                accentColor: statsSectionRoot.accent
            }

            // Longest Session
            StatTile {
                tileValue: statsSectionRoot.formatDuration(statsSectionRoot.stats.longestSessionMs || 0)
                tileLabel: "longest session"
                tileSub: (statsSectionRoot.stats.longestSessionMessages || 0) > 0 ? Math.round(statsSectionRoot.stats.longestSessionMessages) + " msgs" : ""
                accentColor: statsSectionRoot.accent
            }

            // Peak Hour
            StatTile {
                visible: (statsSectionRoot.stats.peakHour !== undefined && statsSectionRoot.stats.peakHour >= 0)
                tileValue: (statsSectionRoot.stats.peakHour !== undefined && statsSectionRoot.stats.peakHour >= 0) ? ((statsSectionRoot.stats.peakHour < 10 ? "0" : "") + statsSectionRoot.stats.peakHour + ":00") : "—"
                tileLabel: "peak hour"
                tileTip: "Hour of day with the most activity"
                accentColor: statsSectionRoot.accent
            }

            // Tool Calls
            StatTile {
                visible: (statsSectionRoot.stats.totalToolCalls || 0) > 0
                tileValue: statsSectionRoot.formatTokens(statsSectionRoot.stats.totalToolCalls || 0)
                tileLabel: "tool calls"
                tileTip: "Total tool invocations across all sessions"
                accentColor: statsSectionRoot.accent
            }

            // Spend (Claude)
            StatTile {
                visible: (statsSectionRoot.stats.totalCostUSD || 0) > 0
                // Muse states its catalog's own currency; every other provider
                // reporting spend here is USD and sends no currency field.
                tileValue: {
                    var amount = (statsSectionRoot.stats.totalCostUSD || 0).toFixed(2);
                    var cur = statsSectionRoot.stats.currency || "USD";
                    if (cur === "USD")
                        return "$" + amount;

                    if (cur === "CNY")
                        return "¥" + amount;

                    return amount + " " + cur;
                }
                tileLabel: "spend"
                tileTip: "Total cost across all models (" + statsSectionRoot.periodLabel + ")"
                accentColor: statsSectionRoot.accent
            }

            // Web Searches (Claude)
            StatTile {
                visible: (statsSectionRoot.stats.totalWebSearches || 0) > 0
                tileValue: statsSectionRoot.formatTokens(statsSectionRoot.stats.totalWebSearches || 0)
                tileLabel: "web searches"
                tileTip: "Total web search requests across all models"
                accentColor: statsSectionRoot.accent
            }

            // Files touched (Copilot)
            StatTile {
                visible: (statsSectionRoot.stats.totalFiles || 0) > 0
                tileValue: statsSectionRoot.formatTokens(statsSectionRoot.stats.totalFiles || 0)
                tileLabel: "files touched"
                tileTip: "Distinct files read or edited across all sessions"
                accentColor: statsSectionRoot.accent
            }

            // Repositories (Copilot)
            StatTile {
                visible: (statsSectionRoot.stats.totalRepositories || 0) > 0
                tileValue: Math.round(statsSectionRoot.stats.totalRepositories || 0).toString()
                tileLabel: "repos"
                tileTip: "Repositories the CLI has been run in"
                accentColor: statsSectionRoot.accent
            }
        }

        // ── Tokens-per-day sparkline ───────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: statsSectionRoot.dailySeries.length > 1

            Text {
                text: statsSectionRoot.dailyUnit === "tokens" ? "Tokens / day" : (statsSectionRoot.dailyUnit === "requests" ? "Requests / day" : "Messages / day")
                font.pixelSize: 9
                color: "#94a3b8"
                opacity: 0.8
            }

            Row {
                id: sparkRow
                Layout.fillWidth: true
                height: 32
                spacing: 1

                readonly property real maxTok: {
                    var mx = 1;
                    var arr = statsSectionRoot.dailySeries;
                    for (var i = 0; i < arr.length; i++) {
                        if (arr[i].total > mx)
                            mx = arr[i].total;
                    }
                    return mx;
                }
                readonly property real barW: Math.max(1, (width - (Math.max(1, statsSectionRoot.dailySeries.length) - 1)) / Math.max(1, statsSectionRoot.dailySeries.length))

                Repeater {
                    model: statsSectionRoot.dailySeries

                    Rectangle {
                        required property var modelData
                        width: sparkRow.barW
                        height: sparkRow.height
                        color: "transparent"

                        QQC2.ToolTip.visible: sparkMA.containsMouse
                        QQC2.ToolTip.delay: 200
                        QQC2.ToolTip.text: modelData.date + "\n" + statsSectionRoot.formatTokens(modelData.total) + " " + statsSectionRoot.dailyUnit

                        MouseArea {
                            id: sparkMA
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: 1
                            height: Math.max(2, parent.height * (modelData.total / sparkRow.maxTok))
                            color: statsSectionRoot.accent
                            opacity: sparkMA.containsMouse ? 1.0 : 0.65
                        }
                    }
                }
            }
        }

        // ── Busiest repositories (Copilot) / workspaces (Muse) ─────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: statsSectionRoot.topGroups.length > 0

            Text {
                text: statsSectionRoot.topGroupsLabel
                font.pixelSize: 9
                color: "#94a3b8"
                opacity: 0.8
            }

            Repeater {
                model: statsSectionRoot.topGroups

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: modelData.name
                        font.pixelSize: 10
                        color: "#f8fafc"
                        opacity: 0.85
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Math.round(modelData.sessions) + (modelData.sessions === 1 ? " session" : " sessions")
                        font.pixelSize: 10
                        color: statsSectionRoot.accent
                    }
                }
            }
        }

        // ── Per-model token breakdown ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: Object.keys(statsSectionRoot.stats.models || ({})).length > 0

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Text {
                text: "Models"
                font.pixelSize: 11
                font.bold: true
                color: "#f8fafc"
                opacity: 0.8
            }

            Repeater {
                model: {
                    var m = statsSectionRoot.stats.models || ({});
                    var keys = Object.keys(m);
                    keys.sort(function (a, b) {
                        return (m[b].total || 0) - (m[a].total || 0);
                    });
                    return keys;
                }

                ColumnLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 2

                    readonly property var modelEntry: (statsSectionRoot.stats.models || ({}))[modelData] || ({})

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: statsSectionRoot.shortenModelName(parent.parent.modelData)
                            font.pixelSize: 10
                            color: "#f8fafc"
                            opacity: 0.85
                            Layout.preferredWidth: 90
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: (parent.parent.modelEntry.input !== undefined)
                            text: statsSectionRoot.formatTokens(parent.parent.modelEntry.input || 0) + " in"
                            font.pixelSize: 9
                            color: "#94a3b8"
                            opacity: 0.7
                        }

                        Text {
                            visible: (parent.parent.modelEntry.output !== undefined)
                            text: statsSectionRoot.formatTokens(parent.parent.modelEntry.output || 0) + " out"
                            font.pixelSize: 9
                            color: "#94a3b8"
                            opacity: 0.7
                        }

                        Text {
                            visible: (parent.parent.modelEntry.sessions !== undefined && parent.parent.modelEntry.input === undefined)
                            text: (parent.parent.modelEntry.sessions || 0) + " sess"
                            font.pixelSize: 9
                            color: "#94a3b8"
                            opacity: 0.7
                        }

                        Text {
                            visible: (parent.parent.modelEntry.cost || 0) > 0
                            text: "$" + (parent.parent.modelEntry.cost || 0).toFixed(2)
                            font.pixelSize: 9
                            color: statsSectionRoot.accent
                            opacity: 0.85
                        }

                        Text {
                            text: (statsSectionRoot.stats.totalTokens || 0) > 0 ? Math.round((parent.parent.modelEntry.total || 0) / statsSectionRoot.stats.totalTokens * 100) + "%" : "—"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#f8fafc"
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Progress bar
                    Item {
                        Layout.fillWidth: true
                        height: 3

                        Rectangle {
                            anchors.fill: parent
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            radius: 1.5
                            color: statsSectionRoot.accent
                            opacity: 0.7
                            width: (statsSectionRoot.stats.totalTokens || 0) > 0 ? parent.width * Math.min(1, Math.max(0, (parent.parent.modelEntry.total || 0) / statsSectionRoot.stats.totalTokens)) : 0
                            Behavior on width {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer freshness and external link
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: (statsSectionRoot.stats.computedDate || "") !== ""
                text: "computed " + (statsSectionRoot.stats.computedDate || "").substring(0, 10)
                font.pixelSize: 8
                color: "#94a3b8"
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                visible: statsSectionRoot.providerId === "openai" || statsSectionRoot.providerId === "cursor"
                text: statsSectionRoot.providerId === "cursor" ? "Cursor dashboard ↗" : "Codex analytics ↗"
                font.pixelSize: 8
                font.underline: analyticsMA.containsMouse
                color: statsSectionRoot.accent
                opacity: analyticsMA.containsMouse ? 1.0 : 0.7

                QQC2.ToolTip.visible: analyticsMA.containsMouse
                QQC2.ToolTip.text: statsSectionRoot.providerId === "cursor" ? "Open the cursor.com usage dashboard in your browser" : "Open chatgpt.com Codex usage analytics in your browser"

                MouseArea {
                    id: analyticsMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(statsSectionRoot.providerId === "cursor" ? "https://cursor.com/dashboard?tab=usage" : "https://chatgpt.com/codex/cloud/settings/analytics#usage")
                }
            }
        }
    }

    // ── Stat Tile Component ────────────────────────────────────────────────────
    component StatTile: Rectangle {
        id: tile

        property string tileLabel: ""
        property string tileValue: ""
        property string tileSub: ""
        property string tileTip: ""
        property color accentColor: "#38bdf8"

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        QQC2.ToolTip.visible: tile.tileTip !== "" && tileMA.containsMouse
        QQC2.ToolTip.delay: 300
        QQC2.ToolTip.text: tile.tileTip

        MouseArea {
            id: tileMA
            anchors.fill: parent
            hoverEnabled: true
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.tileValue
                font.pixelSize: 13
                font.bold: true
                color: tile.accentColor
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.tileLabel + (tile.tileSub ? " · " + tile.tileSub : "")
                font.pixelSize: 8
                color: "#94a3b8"
                opacity: 0.8
            }
        }
    }
}
