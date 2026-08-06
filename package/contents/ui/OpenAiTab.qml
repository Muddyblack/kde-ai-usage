import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: openAiTabRoot
    property Item rootItem

    property string subTab: "usage"

    visible: rootItem.enabledTabs[rootItem.activeTab] === "openai" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    // ── Usage / Stats sub-tab toggle ───────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
        // Stats come from local rollouts, so they exist even without a login.
        visible: rootItem.openaiCodexLoggedIn || rootItem.openaiHasApiKey || rootItem.codexStatsAvailable

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
                    readonly property bool active: openAiTabRoot.subTab === modelData.id

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 5
                    color: active ? Qt.rgba(0.06, 0.64, 0.5, 0.2) : "transparent"
                    border.width: active ? 1 : 0
                    border.color: Qt.rgba(0.06, 0.64, 0.5, 0.35)

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        font.pixelSize: 11
                        font.bold: parent.active
                        opacity: parent.active ? 1 : 0.55
                        color: Kirigami.Theme.textColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openAiTabRoot.subTab = parent.modelData.id
                    }
                }
            }
        }
    }

    // Codex / ChatGPT user identity & limits (top section, clean style)
    ColumnLayout {
        visible: rootItem.openaiCodexLoggedIn && openAiTabRoot.subTab === "usage"
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Kirigami.Icon {
                source: "user-identity"
                width: 14
                height: 14
                color: rootItem.openaiGreen
                isMask: true
                opacity: 0.7
            }
            PlasmaComponents.Label {
                text: rootItem.openaiEmail || (rootItem.openaiAccountId ? rootItem.openaiAccountId : "Codex / ChatGPT User")
                font.pixelSize: 10
                opacity: 0.6
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Live model + reasoning effort from the newest Codex rollout.
            Rectangle {
                visible: rootItem.codexModel !== ""
                implicitWidth: codexModelLabel.implicitWidth + 12
                implicitHeight: 16
                radius: 8
                color: Qt.rgba(rootItem.openaiGreen.r, rootItem.openaiGreen.g, rootItem.openaiGreen.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(rootItem.openaiGreen.r, rootItem.openaiGreen.g, rootItem.openaiGreen.b, 0.35)

                PlasmaComponents.Label {
                    id: codexModelLabel

                    anchors.centerIn: parent
                    text: rootItem.shortenModelName(rootItem.codexModel)
                    font.pixelSize: 8
                    color: rootItem.openaiGreen
                }
            }

            Rectangle {
                id: codexEffortChip

                readonly property color effortColor: {
                    if (rootItem.codexEffortLevel === "xhigh" || rootItem.codexEffortLevel === "high")
                        return rootItem.dangerColor;

                    if (rootItem.codexEffortLevel === "low" || rootItem.codexEffortLevel === "minimal")
                        return rootItem.openaiGreen;

                    return rootItem.warningColor;
                }

                visible: rootItem.codexEffortLevel !== ""
                implicitWidth: codexEffortLabel.implicitWidth + 12
                implicitHeight: 16
                radius: 8
                color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(effortColor.r, effortColor.g, effortColor.b, 0.35)
                QQC2.ToolTip.visible: codexEffortMA.containsMouse
                QQC2.ToolTip.text: "Reasoning effort: " + rootItem.codexEffortLevel

                PlasmaComponents.Label {
                    id: codexEffortLabel

                    anchors.centerIn: parent
                    text: "effort: " + rootItem.codexEffortLevel
                    font.pixelSize: 8
                    color: codexEffortChip.effortColor
                }

                MouseArea {
                    id: codexEffortMA

                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
            Rectangle {
                visible: rootItem.openaiPlanType !== ""
                implicitHeight: 18
                implicitWidth: codexPlanLabel.implicitWidth + 16
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: rootItem.openaiPlanType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.063, 0.639, 0.498, 0.18)
                border.width: 1
                border.color: rootItem.openaiPlanType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.063, 0.639, 0.498, 0.35)
                PlasmaComponents.Label {
                    id: codexPlanLabel
                    anchors.centerIn: parent
                    text: rootItem.openaiPlanType.toUpperCase()
                    font.pixelSize: 10
                    font.bold: true
                    color: rootItem.openaiPlanType === "free" ? Kirigami.Theme.textColor : rootItem.openaiGreen
                }
            }
            StatusChip {
                Layout.alignment: Qt.AlignVCenter
                indicator: rootItem.openaiStatus.indicator
                description: rootItem.openaiStatus.description
                affectedComponents: rootItem.openaiStatus.components
                incidents: rootItem.openaiStatus.incidents
                latestUpdate: rootItem.openaiStatus.latestUpdate
                statusUrl: "https://status.openai.com"
            }
        }

        // Codex plan limits (messages remaining)
        ColumnLayout {
            visible: rootItem.codexUsageAvailable
            Layout.fillWidth: true
            spacing: 12

            PopupRow {
                visible: rootItem.codexSessionAvailable
                label: "5 Hours"
                countdownText: rootItem.codexSessionCountdown === "resetting..." ? "resetting..." : (rootItem.codexSessionCountdown ? "in " + rootItem.codexSessionCountdown : "")
                value: rootItem.codexSessionPct
                barColor: rootItem.openaiGreen
                etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("cp", rootItem.codexSessionPct) : ""
                deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("cp", rootItem.codexSessionPct, 5 * 3600000, "last 5h") : ""
                tokenText: Math.round(100 - rootItem.codexSessionPct) + "% of messages left"
                tooltipText: "Codex 5-hour limit\nUsed: " + Math.round(rootItem.codexSessionPct) + "%  ·  " + Math.round(100 - rootItem.codexSessionPct) + "% left"
            }
            PopupRow {
                visible: rootItem.codexWeeklyAvailable
                label: "Weekly"
                countdownText: rootItem.codexWeeklyCountdown === "resetting..." ? "resetting..." : (rootItem.codexWeeklyCountdown ? "in " + rootItem.codexWeeklyCountdown : "")
                value: rootItem.codexWeeklyPct
                barColor: rootItem.openaiGreen
                etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("cw", rootItem.codexWeeklyPct) : ""
                deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("cw", rootItem.codexWeeklyPct, 7 * 24 * 3600000, "last week") : ""
                tokenText: Math.round(100 - rootItem.codexWeeklyPct) + "% of messages left"
                tooltipText: "Codex weekly limit\nUsed: " + Math.round(rootItem.codexWeeklyPct) + "%  ·  " + Math.round(100 - rootItem.codexWeeklyPct) + "% left"
            }

            PlasmaComponents.Label {
                visible: rootItem.codexLimitReached
                text: "⚠ Limit reached — wait for reset"
                font.pixelSize: 10
                font.bold: true
                color: rootItem.dangerColor
            }

            // Per-model additional rate limits
            Repeater {
                model: rootItem.codexAdditionalLimits
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
                            color: rootItem.openaiGreen
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
                                color: rootItem.dangerColor
                            }
                        }
                    }

                    PopupRow {
                        visible: modelData.session.available
                        label: "5 Hours"
                        countdownText: {
                            if (!modelData.session.reset)
                                return "";
                            var cd = rootItem.formatCountdown(modelData.session.reset);
                            return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                        }
                        value: modelData.session.pct
                        barColor: rootItem.openaiGreen
                        tokenText: Math.round(100 - modelData.session.pct) + "% of messages left"
                        tooltipText: modelData.name + " 5-hour limit\nUsed: " + Math.round(modelData.session.pct) + "%  ·  " + Math.round(100 - modelData.session.pct) + "% left"
                    }
                    PopupRow {
                        visible: modelData.weekly.available
                        label: "Weekly"
                        countdownText: {
                            if (!modelData.weekly.reset)
                                return "";
                            var cd = rootItem.formatCountdown(modelData.weekly.reset);
                            return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                        }
                        value: modelData.weekly.pct
                        barColor: rootItem.openaiGreen
                        tokenText: Math.round(100 - modelData.weekly.pct) + "% of messages left"
                        tooltipText: modelData.name + " weekly limit\nUsed: " + Math.round(modelData.weekly.pct) + "%  ·  " + Math.round(100 - modelData.weekly.pct) + "% left"
                    }
                }
            }
        }

        // Notice if no API key is added, matching Claude's tip box design
        PlasmaComponents.Label {
            visible: !rootItem.openaiHasApiKey
            text: rootItem.codexUsageAvailable ? "Plan limits above. Add an OpenAI API key in settings for API token/cost data." : "Codex plan limits are separate from OpenAI API billing. Add an OpenAI API key in settings for token and cost data."
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
        visible: rootItem.openaiHasApiKey && openAiTabRoot.subTab === "usage"
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            visible: rootItem.openaiCodexLoggedIn
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
                    color: rootItem.openaiGreen
                }
            }
            PlasmaComponents.Label {
                text: "$" + rootItem.openaiTotalCostUSD.toFixed(2)
                font.bold: true
                font.pixelSize: 13
                color: rootItem.openaiGreen
            }
        }

        PlasmaComponents.Label {
            text: rootItem.formatTokens(rootItem.openaiTotalInputTokens) + " in  ·  " + rootItem.formatTokens(rootItem.openaiTotalOutputTokens) + " out"
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
        }

        Rectangle {
            visible: Object.keys(rootItem.openaiModels).length === 0 && rootItem.errorMsg === ""
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
            visible: Object.keys(rootItem.openaiModels).length > 0

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Repeater {
                model: {
                    var keys = Object.keys(rootItem.openaiModels);
                    keys.sort(function (a, b) {
                        return rootItem.openaiModels[b].cost_usd - rootItem.openaiModels[a].cost_usd;
                    });
                    return keys;
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    // HoverHandler rather than a MouseArea: a MouseArea here would be a
                    // layout child, and anchoring it to fill the layout is undefined behavior.
                    HoverHandler {
                        id: modelHover
                    }
                    QQC2.ToolTip.visible: modelHover.hovered
                    QQC2.ToolTip.delay: 400
                    QQC2.ToolTip.text: {
                        var m = rootItem.openaiModels[modelData];
                        if (!m)
                            return modelData;
                        return modelData + "\nInput:  " + rootItem.formatTokens(m.input_tokens) + " tokens\nOutput: " + rootItem.formatTokens(m.output_tokens) + " tokens\nCost:   " + (m.priced ? "$" + m.cost_usd.toFixed(4) : "unpriced");
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
                            text: rootItem.formatTokens(rootItem.openaiModels[modelData].input_tokens) + " in"
                            font.pixelSize: 9
                            opacity: 0.4
                            color: Kirigami.Theme.textColor
                        }
                        PlasmaComponents.Label {
                            text: rootItem.formatTokens(rootItem.openaiModels[modelData].output_tokens) + " out"
                            font.pixelSize: 9
                            opacity: 0.4
                            color: Kirigami.Theme.textColor
                        }
                        PlasmaComponents.Label {
                            text: rootItem.openaiModels[modelData].priced ? "$" + rootItem.openaiModels[modelData].cost_usd.toFixed(3) : "—"
                            font.pixelSize: 11
                            font.bold: true
                            color: Kirigami.Theme.textColor
                            opacity: rootItem.openaiModels[modelData].priced ? 1.0 : 0.4
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
                            color: rootItem.openaiGreen
                            opacity: 0.7
                            width: rootItem.openaiTotalCostUSD > 0 ? parent.width * (rootItem.openaiModels[modelData].cost_usd / rootItem.openaiTotalCostUSD) : 0
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
        visible: !rootItem.openaiHasApiKey && !rootItem.openaiCodexLoggedIn && rootItem.enabledTabs[rootItem.activeTab] === "openai" && openAiTabRoot.subTab === "usage"
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

    // ── Stats: lifetime Codex activity from ~/.codex/sessions ──────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: openAiTabRoot.subTab === "stats" && !rootItem.codexStatsAvailable

        PlasmaComponents.Label {
            text: "No Codex history yet"
            font.pixelSize: 12
            font.bold: true
            opacity: 0.7
            color: Kirigami.Theme.textColor
        }

        PlasmaComponents.Label {
            text: "Run a Codex CLI session and stats will appear here."
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: openAiTabRoot.subTab === "stats" && rootItem.codexStatsAvailable

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

            PlasmaComponents.Label {
                visible: rootItem.codexStatsFavoriteModel !== ""
                text: "★ " + rootItem.shortenModelName(rootItem.codexStatsFavoriteModel)
                font.pixelSize: 9
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            StatTile {
                tileValue: rootItem.formatTokens(rootItem.codexStatsTotalTokens)
                tileLabel: "tokens"
                tileTip: "Cumulative tokens across all Codex sessions"
            }

            StatTile {
                tileValue: Math.round(rootItem.codexStatsTotalSessions).toString()
                tileLabel: "sessions"
                tileTip: Math.round(rootItem.codexStatsTotalMessages) + " prompts total"
            }

            StatTile {
                tileValue: Math.round(rootItem.codexStatsActiveDays) + (rootItem.codexStatsSpanDays > 0 ? "/" + Math.round(rootItem.codexStatsSpanDays) : "")
                tileLabel: "active days"
                tileTip: rootItem.codexStatsFirstDate ? "Since " + rootItem.codexStatsFirstDate : ""
            }

            StatTile {
                tileValue: Math.round(rootItem.codexStatsCurrentStreak) + "d"
                tileLabel: "streak"
                tileSub: "best " + Math.round(rootItem.codexStatsLongestStreak) + "d"
                tileTip: "Current consecutive-day streak\nLongest: " + Math.round(rootItem.codexStatsLongestStreak) + " days"
            }

            StatTile {
                tileValue: rootItem.formatDuration(rootItem.codexStatsLongestSessionMs)
                tileLabel: "longest session"
                tileSub: rootItem.codexStatsLongestSessionMessages > 0 ? Math.round(rootItem.codexStatsLongestSessionMessages) + " msgs" : ""
            }

            StatTile {
                tileValue: rootItem.formatTokens(rootItem.codexStatsTotalToolCalls)
                tileLabel: "tool calls"
                tileTip: "Function and custom tool invocations across all sessions"
            }
        }

        // ── Per-model breakdown ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: modelRepeater.count > 0

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            PlasmaComponents.Label {
                text: "Models"
                font.bold: true
                font.pixelSize: 11
                opacity: 0.7
                color: Kirigami.Theme.textColor
            }

            Repeater {
                id: modelRepeater

                model: {
                    var keys = Object.keys(rootItem.codexStatsModels);
                    keys.sort(function (a, b) {
                        return rootItem.codexStatsModels[b].total - rootItem.codexStatsModels[a].total;
                    });
                    return keys;
                }

                RowLayout {
                    required property string modelData

                    Layout.fillWidth: true
                    spacing: 8

                    PlasmaComponents.Label {
                        text: rootItem.shortenModelName(parent.modelData)
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
                        text: rootItem.codexStatsModels[parent.modelData].sessions + " sess"
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }

                    PlasmaComponents.Label {
                        text: rootItem.formatTokens(rootItem.codexStatsModels[parent.modelData].total)
                        font.pixelSize: 9
                        opacity: 0.4
                        color: Kirigami.Theme.textColor
                    }

                    PlasmaComponents.Label {
                        text: rootItem.codexStatsTotalTokens > 0 ? Math.round(rootItem.codexStatsModels[parent.modelData].total / rootItem.codexStatsTotalTokens * 100) + "%" : "—"
                        font.pixelSize: 11
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlasmaComponents.Label {
                visible: rootItem.codexStatsComputedDate !== ""
                text: "computed " + rootItem.codexStatsComputedDate.substring(0, 10)
                font.pixelSize: 8
                opacity: 0.35
                color: Kirigami.Theme.textColor
            }

            Item {
                Layout.fillWidth: true
            }

            // Local rollouts only cover this machine; the cloud dashboard has
            // the per-surface (CLI / extension / web) breakdown and credits.
            PlasmaComponents.Label {
                id: analyticsLink

                text: "Codex analytics ↗"
                font.pixelSize: 8
                font.underline: analyticsMA.containsMouse
                opacity: analyticsMA.containsMouse ? 0.9 : 0.45
                color: rootItem.openaiGreen
                QQC2.ToolTip.visible: analyticsMA.containsMouse
                QQC2.ToolTip.text: "Open chatgpt.com Codex usage analytics in your browser"

                MouseArea {
                    id: analyticsMA

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://chatgpt.com/codex/cloud/settings/analytics#usage")
                }
            }
        }
    }

    component StatTile: StatTileBase {
        accentColor: rootItem.openaiGreen
    }
}
