import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: claudeTabRoot
    property Item rootItem

    // Inner sub-tab: "usage" (live quota/cost) vs "stats" (local /stats activity)
    property string subTab: "usage"

    visible: rootItem.enabledTabs[rootItem.activeTab] === "claude" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.claudeSubscriptionType !== ""

        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.claudeOrange
            isMask: true
            opacity: 0.7
        }
        PlasmaComponents.Label {
            text: {
                // Prettify rateLimitTier: "default_claude_ai" → "Default"
                // "pro_claude_ai" → "Pro", etc.
                var tier = rootItem.claudeRateLimitTier.replace(/_claude_ai$/i, "").replace(/_/g, " ").replace(/\b\w/g, function (c) {
                    return c.toUpperCase();
                });
                if (tier)
                    return tier;
                // Fall back to abbreviated org UUID or generic label
                return rootItem.claudeOrganizationUuid ? rootItem.claudeOrganizationUuid.slice(0, 8) + "…" : "Claude Code User";
            }
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Effort chip
        Rectangle {
            visible: rootItem.claudeEffortLevel !== ""
            implicitHeight: 16
            implicitWidth: effortChipLabel.implicitWidth + 12
            radius: 3
            readonly property color effortColor: {
                if (rootItem.claudeEffortLevel === "high")
                    return Qt.rgba(0.8, 0.47, 0.36, 0.85);
                if (rootItem.claudeEffortLevel === "low")
                    return Qt.rgba(0.4, 0.7, 0.4, 0.7);
                return Qt.rgba(1, 1, 1, 0.55);
            }
            color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.35)
            QQC2.ToolTip.visible: effortMA.containsMouse
            QQC2.ToolTip.text: "Thinking budget: " + rootItem.claudeEffortLevel
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
                text: "effort: " + rootItem.claudeEffortLevel
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
            readonly property color dreamColor: rootItem.claudeAutoDream ? Qt.rgba(0.43, 0.35, 0.78, 0.9) : Qt.rgba(1, 1, 1, 0.3)
            color: Qt.rgba(dreamColor.r, dreamColor.g, dreamColor.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(dreamColor.r, dreamColor.g, dreamColor.b, 0.35)
            QQC2.ToolTip.visible: dreamMA.containsMouse
            QQC2.ToolTip.text: rootItem.claudeAutoDream ? "Extended thinking (dream mode): ON\nClaude will reason longer on complex tasks" : "Extended thinking (dream mode): OFF"
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
                text: rootItem.claudeAutoDream ? "dream: on" : "dream: off"
                font.pixelSize: 9
                font.bold: rootItem.claudeAutoDream
                color: parent.dreamColor
            }
        }

        Rectangle {
            implicitHeight: 18
            implicitWidth: planLabelClaude.implicitWidth + 16
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: rootItem.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.8, 0.47, 0.36, 0.18)
            border.width: 1
            border.color: rootItem.claudeSubscriptionType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.8, 0.47, 0.36, 0.35)
            PlasmaComponents.Label {
                id: planLabelClaude
                anchors.centerIn: parent
                text: rootItem.claudeSubscriptionType.toUpperCase()
                font.pixelSize: 10
                font.bold: true
                color: rootItem.claudeSubscriptionType === "free" ? Kirigami.Theme.textColor : rootItem.claudeOrange
            }
        }

        StatusChip {
            Layout.alignment: Qt.AlignVCenter
            indicator: rootItem.claudeStatus.indicator
            description: rootItem.claudeStatus.description
            affectedComponents: rootItem.claudeStatus.components
            incidents: rootItem.claudeStatus.incidents
            latestUpdate: rootItem.claudeStatus.latestUpdate
            statusUrl: "https://status.claude.com"
        }
    }

    // ── Usage / Stats sub-tab toggle ───────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
                model: [
                    {
                        id: "usage",
                        label: "Usage"
                    },
                    {
                        id: "stats",
                        label: "Stats"
                    }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 5
                    readonly property bool active: claudeTabRoot.subTab === modelData.id
                    color: active ? Qt.rgba(0.8, 0.47, 0.36, 0.20) : "transparent"
                    border.width: active ? 1 : 0
                    border.color: Qt.rgba(0.8, 0.47, 0.36, 0.35)
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        font.bold: parent.active
                        color: parent.active ? rootItem.claudeOrange : Kirigami.Theme.textColor
                        opacity: parent.active ? 1.0 : 0.6
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: claudeTabRoot.subTab = modelData.id
                    }
                }
            }
        }
    }

    PopupRow {
        visible: claudeTabRoot.subTab === "usage"
        label: "5 Hours"
        resetText: rootItem.sessionResetTime ? "resets " + rootItem.sessionResetTime : ""
        countdownText: rootItem.sessionCountdown === "resetting..." ? "resetting..." : (rootItem.sessionCountdown ? "in " + rootItem.sessionCountdown : "")
        value: rootItem.sessionPct
        barColor: rootItem.sessionColor
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("s", rootItem.sessionPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("s", rootItem.sessionPct, 24 * 3600000, "yesterday") : ""
        tokenText: rootItem.sessionTokensUsed > 0 ? rootItem.formatTokens(rootItem.sessionTokensUsed) + (rootItem.sessionTokenLimit > 0 ? " / " + rootItem.formatTokens(rootItem.sessionTokenLimit) : "") + " tokens" : ""
        tooltipText: "Claude 5-hour rolling window\nUsage: " + Math.round(rootItem.sessionPct) + "%" + (rootItem.sessionTokensUsed > 0 ? "\n" + rootItem.formatTokens(rootItem.sessionTokensUsed) + (rootItem.sessionTokenLimit > 0 ? " / " + rootItem.formatTokens(rootItem.sessionTokenLimit) : "") + " tokens" : "") + (rootItem.sessionResetTime ? "\nResets: " + rootItem.sessionResetTime : "")
    }

    PopupRow {
        visible: claudeTabRoot.subTab === "usage"
        label: "7 Days"
        resetText: rootItem.weeklyResetTime ? "resets " + rootItem.weeklyResetTime : ""
        countdownText: rootItem.weeklyCountdown === "resetting..." ? "resetting..." : (rootItem.weeklyCountdown ? "in " + rootItem.weeklyCountdown : "")
        value: rootItem.weeklyPct
        barColor: rootItem.weeklyColor
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("w", rootItem.weeklyPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("w", rootItem.weeklyPct, 7 * 24 * 3600000, "last week") : ""
        tokenText: rootItem.weeklyTokensUsed > 0 ? rootItem.formatTokens(rootItem.weeklyTokensUsed) + (rootItem.weeklyTokenLimit > 0 ? " / " + rootItem.formatTokens(rootItem.weeklyTokenLimit) : "") + " tokens" : ""
        tooltipText: "Claude 7-day rolling window\nUsage: " + Math.round(rootItem.weeklyPct) + "%" + (rootItem.weeklyTokensUsed > 0 ? "\n" + rootItem.formatTokens(rootItem.weeklyTokensUsed) + (rootItem.weeklyTokenLimit > 0 ? " / " + rootItem.formatTokens(rootItem.weeklyTokenLimit) : "") + " tokens" : "") + (rootItem.weeklyResetTime ? "\nResets: " + rootItem.weeklyResetTime : "")
    }

    // ── API cost estimate (subscription users without admin API key) ───────────
    // Shown when we have token data but no real billing data from an admin key.
    // Assumes a 3:1 input:output token ratio (typical for coding workflows).
    // Pricing: sonnet-4 ($3/$15 per M), opus-4 ($15/$75 per M).
    Rectangle {
        id: apiCostEstimate
        visible: claudeTabRoot.subTab === "usage" && rootItem.weeklyTokensUsed > 0 && rootItem._claudeAdminToken === ""
        Layout.fillWidth: true
        height: costEstCol.implicitHeight + 16
        radius: 6
        color: Qt.rgba(0.8, 0.47, 0.36, 0.06)
        border.width: 1
        border.color: Qt.rgba(0.8, 0.47, 0.36, 0.15)

        readonly property real _tok: rootItem.weeklyTokensUsed / 1000000
        // blended rate: 0.75 input + 0.25 output
        readonly property real _sonnet: _tok * (0.75 * 3.0 + 0.25 * 15.0)
        readonly property real _opus: _tok * (0.75 * 15.0 + 0.25 * 75.0)

        QQC2.ToolTip.visible: costEstMA.containsMouse
        QQC2.ToolTip.delay: 300
        QQC2.ToolTip.text: "Estimated API cost for your 7-day token usage\n" + "if billed at pay-as-you-go rates.\n\n" + "Assumes 3:1 input:output token ratio.\n" + "Actual cost depends on model mix used.\n\n" + "Add a Claude Admin API key in settings\nfor exact per-model billing data."

        MouseArea {
            id: costEstMA
            anchors.fill: parent
            hoverEnabled: true
        }

        ColumnLayout {
            id: costEstCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                PlasmaComponents.Label {
                    text: "API equiv. (7d)"
                    font.pixelSize: 10
                    font.bold: true
                    opacity: 0.55
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    text: "~" + rootItem.formatTokens(rootItem.weeklyTokensUsed) + " tokens"
                    font.pixelSize: 9
                    opacity: 0.35
                    color: Kirigami.Theme.textColor
                }
                Item {
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: "est. ≈"
                    font.pixelSize: 9
                    opacity: 0.4
                    color: Kirigami.Theme.textColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // sonnet-4
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 4
                    color: Qt.rgba(0.8, 0.47, 0.36, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(0.8, 0.47, 0.36, 0.22)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: "sonnet-4"
                            font.pixelSize: 8
                            opacity: 0.5
                            color: Kirigami.Theme.textColor
                        }
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: "$" + apiCostEstimate._sonnet.toFixed(apiCostEstimate._sonnet < 0.01 ? 4 : 2)
                            font.pixelSize: 12
                            font.bold: true
                            color: rootItem.claudeOrange
                        }
                    }
                }

                // opus-4
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 4
                    color: Qt.rgba(0.8, 0.47, 0.36, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(0.8, 0.47, 0.36, 0.15)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: "opus-4"
                            font.pixelSize: 8
                            opacity: 0.5
                            color: Kirigami.Theme.textColor
                        }
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: "$" + apiCostEstimate._opus.toFixed(apiCostEstimate._opus < 0.01 ? 4 : 2)
                            font.pixelSize: 12
                            font.bold: true
                            color: Kirigami.Theme.textColor
                            opacity: 0.75
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: claudeTabRoot.subTab === "usage" && rootItem.claudeExtraTokens > 0
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
                color: rootItem.claudeOrange
            }
            PlasmaComponents.Label {
                text: "Extra budget"
                font.pixelSize: 11
                font.bold: true
                color: rootItem.claudeOrange
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: rootItem.formatTokens(rootItem.claudeExtraTokens) + " tokens remaining"
                font.pixelSize: 11
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }
        }
    }

    PopupRow {
        visible: claudeTabRoot.subTab === "usage" && rootItem.claudeExtraUsageEnabled && rootItem.claudeExtraUsageLimit > 0
        label: "Extra Purchases"
        value: rootItem.claudeExtraUsagePct
        barColor: rootItem.claudeOrange
        tokenText: rootItem.claudeExtraUsageUsed.toFixed(2) + " / " + rootItem.claudeExtraUsageLimit.toFixed(2) + " " + rootItem.claudeExtraUsageCurrency + " used"
        tooltipText: "Claude pay-as-you-go credit spend\nLimit: " + rootItem.claudeExtraUsageLimit + " " + rootItem.claudeExtraUsageCurrency
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: claudeTabRoot.subTab === "usage" && Object.keys(rootItem.claudeModels).length > 0

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
                text: "$" + rootItem.claudeTotalCostUSD.toFixed(2)
                font.bold: true
                font.pixelSize: 13
                color: rootItem.claudeOrange
            }
        }
        PlasmaComponents.Label {
            text: rootItem.formatTokens(rootItem.claudeTotalInputTokens) + " in  ·  " + rootItem.formatTokens(rootItem.claudeTotalOutputTokens) + " out"
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
        }

        Repeater {
            model: {
                var keys = Object.keys(rootItem.claudeModels);
                keys.sort(function (a, b) {
                    return rootItem.claudeModels[b].cost_usd - rootItem.claudeModels[a].cost_usd;
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
                        var m = rootItem.claudeModels[modelData];
                        if (!m)
                            return modelData;
                        return modelData + "\nInput:  " + rootItem.formatTokens(m.input_tokens) + " tokens\nOutput: " + rootItem.formatTokens(m.output_tokens) + " tokens\nCost:   " + (m.priced ? "$" + m.cost_usd.toFixed(4) : "unpriced");
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    PlasmaComponents.Label {
                        text: rootItem.shortenModelName(modelData)
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
                        text: rootItem.formatTokens(rootItem.claudeModels[modelData].input_tokens) + " in"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: rootItem.formatTokens(rootItem.claudeModels[modelData].output_tokens) + " out"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: rootItem.claudeModels[modelData].priced ? "$" + rootItem.claudeModels[modelData].cost_usd.toFixed(3) : "—"
                        font.pixelSize: 11
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: rootItem.claudeModels[modelData].priced ? 1.0 : 0.4
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
                        color: rootItem.claudeOrange
                        opacity: 0.7
                        width: rootItem.claudeTotalCostUSD > 0 ? parent.width * (rootItem.claudeModels[modelData].cost_usd / rootItem.claudeTotalCostUSD) : 0
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

    // ── No-stats placeholder ───────────────────────────────────────────────────
    PlasmaComponents.Label {
        visible: claudeTabRoot.subTab === "stats" && !rootItem.claudeStatsAvailable
        Layout.fillWidth: true
        Layout.topMargin: 8
        horizontalAlignment: Text.AlignHCenter
        text: "No local activity stats yet.\nRun Claude Code to generate ~/.claude/stats-cache.json"
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
        wrapMode: Text.WordWrap
    }

    // ── Claude Code local activity stats (mirrors `/stats`) ────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: claudeTabRoot.subTab === "stats" && rootItem.claudeStatsAvailable

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PlasmaComponents.Label {
                text: "Activity Stats"
                font.bold: true
                font.pixelSize: 11
                opacity: 0.7
                color: Kirigami.Theme.textColor
            }
            Item {
                Layout.fillWidth: true
            }
            // Favorite (most-used) model chip.
            Rectangle {
                visible: rootItem.claudeStatsFavoriteModel !== ""
                implicitHeight: 16
                implicitWidth: favLabel.implicitWidth + 14
                radius: 3
                color: Qt.rgba(0.8, 0.47, 0.36, 0.15)
                border.width: 1
                border.color: Qt.rgba(0.8, 0.47, 0.36, 0.35)
                PlasmaComponents.Label {
                    id: favLabel
                    anchors.centerIn: parent
                    text: "★ " + rootItem.shortenModelName(rootItem.claudeStatsFavoriteModel)
                    font.pixelSize: 9
                    font.bold: true
                    color: rootItem.claudeOrange
                }
            }
        }

        // ── Stat tiles grid ────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            StatTile {
                tileValue: rootItem.formatTokens(rootItem.claudeStatsTotalTokens)
                tileLabel: "tokens"
                tileTip: "Total input+output tokens across all models (all time)"
            }
            StatTile {
                tileValue: Math.round(rootItem.claudeStatsTotalSessions).toString()
                tileLabel: "sessions"
                tileTip: rootItem.formatTokens(rootItem.claudeStatsTotalMessages) + " messages total"
            }
            StatTile {
                tileValue: Math.round(rootItem.claudeStatsActiveDays) + (rootItem.claudeStatsSpanDays > 0 ? "/" + Math.round(rootItem.claudeStatsSpanDays) : "")
                tileLabel: "active days"
                tileTip: rootItem.claudeStatsFirstDate ? "Since " + Qt.formatDate(new Date(rootItem.claudeStatsFirstDate), "MMM d, yyyy") : ""
            }
            StatTile {
                tileValue: Math.round(rootItem.claudeStatsCurrentStreak) + "d"
                tileLabel: "streak"
                tileSub: "best " + Math.round(rootItem.claudeStatsLongestStreak) + "d"
                tileTip: "Current consecutive-day streak\nLongest: " + Math.round(rootItem.claudeStatsLongestStreak) + " days"
            }
            StatTile {
                tileValue: rootItem.formatDuration(rootItem.claudeStatsLongestSessionMs)
                tileLabel: "longest session"
            }
            StatTile {
                visible: rootItem.claudeStatsPeakHour >= 0
                tileValue: rootItem.claudeStatsPeakHour >= 0 ? (rootItem.claudeStatsPeakHour < 10 ? "0" : "") + rootItem.claudeStatsPeakHour + ":00" : "—"
                tileLabel: "peak hour"
                tileTip: "Hour of day with the most activity"
            }
        }

        // ── Tokens-per-day sparkline ───────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: rootItem.claudeStatsDailyTokens.length > 1

            PlasmaComponents.Label {
                text: "Tokens / day"
                font.pixelSize: 9
                opacity: 0.45
                color: Kirigami.Theme.textColor
            }
            Row {
                id: sparkRow
                Layout.fillWidth: true
                height: 34
                spacing: 1
                readonly property real maxTok: {
                    var mx = 1;
                    var arr = rootItem.claudeStatsDailyTokens;
                    for (var i = 0; i < arr.length; i++)
                        if (arr[i].total > mx)
                            mx = arr[i].total;
                    return mx;
                }
                readonly property real barW: Math.max(1, (width - (rootItem.claudeStatsDailyTokens.length - 1)) / rootItem.claudeStatsDailyTokens.length)
                Repeater {
                    model: rootItem.claudeStatsDailyTokens
                    Rectangle {
                        required property var modelData
                        width: sparkRow.barW
                        height: sparkRow.height
                        color: "transparent"
                        QQC2.ToolTip.visible: barMA.containsMouse
                        QQC2.ToolTip.delay: 300
                        QQC2.ToolTip.text: modelData.date + "\n" + rootItem.formatTokens(modelData.total) + " tokens"
                        MouseArea {
                            id: barMA
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: 1
                            height: Math.max(2, parent.height * (modelData.total / sparkRow.maxTok))
                            color: rootItem.claudeOrange
                            opacity: barMA.containsMouse ? 1.0 : 0.6
                        }
                    }
                }
            }
        }

        // ── Per-model token usage (all time) ───────────────────────────────
        Repeater {
            model: {
                var keys = Object.keys(rootItem.claudeStatsModels);
                keys.sort(function (a, b) {
                    return rootItem.claudeStatsModels[b].total - rootItem.claudeStatsModels[a].total;
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
                        var m = rootItem.claudeStatsModels[modelData];
                        if (!m)
                            return modelData;
                        return modelData + "\nInput:  " + rootItem.formatTokens(m.input) + "\nOutput: " + rootItem.formatTokens(m.output) + "\nCache read: " + rootItem.formatTokens(m.cacheRead) + "\nCache write: " + rootItem.formatTokens(m.cacheCreation);
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    PlasmaComponents.Label {
                        text: rootItem.shortenModelName(modelData)
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
                        text: rootItem.formatTokens(rootItem.claudeStatsModels[modelData].input) + " in"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: rootItem.formatTokens(rootItem.claudeStatsModels[modelData].output) + " out"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: rootItem.claudeStatsTotalTokens > 0 ? Math.round(rootItem.claudeStatsModels[modelData].total / rootItem.claudeStatsTotalTokens * 100) + "%" : "—"
                        font.pixelSize: 11
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 38
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
                        color: rootItem.claudeOrange
                        opacity: 0.7
                        width: rootItem.claudeStatsTotalTokens > 0 ? parent.width * (rootItem.claudeStatsModels[modelData].total / rootItem.claudeStatsTotalTokens) : 0
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

        // Freshness note — Claude recomputes this cache daily, so it can lag.
        PlasmaComponents.Label {
            visible: rootItem.claudeStatsComputedDate !== ""
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "computed " + rootItem.claudeStatsComputedDate
            font.pixelSize: 8
            opacity: 0.35
            color: Kirigami.Theme.textColor
        }
    }

    component StatTile: Rectangle {
        id: tile
        property string tileLabel: ""
        property string tileValue: ""
        property string tileSub: ""
        property string tileTip: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
        QQC2.ToolTip.visible: tile.tileTip !== "" && tileMA.containsMouse
        QQC2.ToolTip.delay: 400
        QQC2.ToolTip.text: tile.tileTip
        MouseArea {
            id: tileMA
            anchors.fill: parent
            hoverEnabled: true
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: tile.tileValue
                font.pixelSize: 14
                font.bold: true
                color: rootItem.claudeOrange
            }
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: tile.tileLabel + (tile.tileSub ? " · " + tile.tileSub : "")
                font.pixelSize: 8
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }
        }
    }
}
