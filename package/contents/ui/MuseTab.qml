import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: museTabRoot
    property Item rootItem

    // Inner sub-tab: "usage" (lifetime totals and spend) vs "stats" (local
    // activity), same split as the Claude, OpenAI and Copilot tabs.
    property string subTab: "usage"

    visible: rootItem.enabledTabs[rootItem.activeTab] === "muse" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.museHasLogin

        Kirigami.Icon {
            source: Qt.resolvedUrl("../icons/muse-color.svg")
            width: 14
            height: 14
        }

        PlasmaComponents.Label {
            text: rootItem.museFullName !== "" ? "Muse Code · " + rootItem.museFullName : "Muse Code"
            font.pixelSize: 10
            opacity: 0.65
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // The model the CLI will actually use next, read from its own
        // settings — never a name pinned in our source.
        Rectangle {
            visible: rootItem.museModel !== ""
            implicitHeight: 18
            implicitWidth: museModelLabel.implicitWidth + 12
            radius: 4
            color: Qt.rgba(rootItem.museBlue.r, rootItem.museBlue.g, rootItem.museBlue.b, 0.18)
            border.width: 1
            border.color: Qt.rgba(rootItem.museBlue.r, rootItem.museBlue.g, rootItem.museBlue.b, 0.35)

            PlasmaComponents.Label {
                id: museModelLabel
                anchors.centerIn: parent
                text: rootItem.shortenModelName(rootItem.museModel)
                font.pixelSize: 9
                font.bold: true
                color: rootItem.museBlue
            }
        }
    }

    ColumnLayout {
        visible: rootItem.museError !== ""
        Layout.fillWidth: true
        spacing: 6

        PlasmaComponents.Label {
            text: rootItem.museHasLogin ? "No Muse activity yet" : "Not connected"
            font.pixelSize: 12
            font.bold: true
            color: Kirigami.Theme.textColor
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: rootItem.museHasLogin ? "Run a Muse Code session and its local logs\nwill appear here." : "Sign in with `muse login`. Nothing to paste:\nthis tab only reads Muse's own local files."
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    SubTabBar {
        visible: rootItem.museError === ""
        accent: rootItem.museBlue
        currentId: museTabRoot.subTab
        onSelected: id => museTabRoot.subTab = id
    }

    // ── Lifetime totals ────────────────────────────────────────────────────────
    ColumnLayout {
        visible: museTabRoot.subTab === "usage" && rootItem.museError === ""
        Layout.fillWidth: true
        spacing: 8

        PopupRow {
            visible: rootItem.museCurrentAvailable
            label: "Current"
            value: rootItem.museCurrentPct
            barColor: rootItem.museBlue
            countdownText: rootItem.museCurrentCountdown !== "" ? "in " + rootItem.museCurrentCountdown : ""
            tooltipText: "Muse current window" + (rootItem.museCurrentCountdown !== "" ? "\nResets in " + rootItem.museCurrentCountdown : "")
        }

        PopupRow {
            visible: rootItem.museWeeklyAvailable
            label: "Weekly"
            value: rootItem.museWeeklyPct
            barColor: rootItem.museBlue
            countdownText: rootItem.museWeeklyCountdown !== "" ? "in " + rootItem.museWeeklyCountdown : ""
            tooltipText: "Muse weekly window" + (rootItem.museWeeklyCountdown !== "" ? "\nResets in " + rootItem.museWeeklyCountdown : "")
        }

        StatValueCard {
            accent: rootItem.museBlue
            rows: {
                var out = [
                    {
                        label: "Tokens",
                        value: rootItem.formatTokens(rootItem.museTotalTokens),
                        strong: true
                    },
                    {
                        label: "Output",
                        value: rootItem.formatTokens(rootItem.museOutputTokens)
                    }
                ];
                if (rootItem.museCostUSD > 0)
                    out.push({
                        label: "Spend (est.)",
                        value: "$" + rootItem.museCostUSD.toFixed(2)
                    });
                out.push({
                    label: "Model calls",
                    value: Math.round(rootItem.museModelCalls).toString()
                });
                return out;
            }
        }

        // Muse is the only provider whose plan quota cannot be read for free,
        // so the tab says why the bars are missing — and, when they are on,
        // that they are the one thing here that is not free.
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: !rootItem.museQuotaOn
            text: "Plan quota is off: Meta reports it only on a billed model call.\nEverything above is read from Muse's own local files."
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: rootItem.museQuotaOn && rootItem.museQuotaError !== ""
            text: {
                if (rootItem.museQuotaError === "rejected")
                    return "Plan quota: Meta refused the credential.";
                if (rootItem.museQuotaError === "unreachable")
                    return "Plan quota: could not reach Meta — the local numbers above are unaffected.";
                if (rootItem.museQuotaError === "no-credential")
                    return "Plan quota needs a Meta API key, or a `muse login` that stored one.";
                if (rootItem.museQuotaError === "no-model")
                    return "Plan quota needs a model: run Muse once so it caches its catalog.";
                return "";
            }
            font.pixelSize: 9
            opacity: 0.55
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: rootItem.museQuotaOn && rootItem.museQuotaError === "" && !rootItem.museCurrentAvailable && !rootItem.museWeeklyAvailable
            text: "No plan windows on this account — pay-as-you-go has none."
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
        }
    }

    // ── Local activity ─────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: museTabRoot.subTab === "stats" && rootItem.museError === ""

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
                text: "Muse Code CLI"
                font.pixelSize: 9
                opacity: 0.45
                color: Kirigami.Theme.textColor
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            StatTile {
                visible: rootItem.museTotalTokens > 0
                tileValue: rootItem.formatTokens(rootItem.museTotalTokens)
                tileLabel: "tokens"
                tileTip: rootItem.formatTokens(rootItem.museOutputTokens) + " output · " + rootItem.formatTokens(rootItem.museInputTokens) + " input (context is resent each call)"
            }
            StatTile {
                visible: rootItem.museCostUSD > 0
                tileValue: "$" + rootItem.museCostUSD.toFixed(2)
                tileLabel: "spend (est.)"
                tileTip: "Tokens priced with the model catalog Muse caches locally"
            }
            StatTile {
                tileValue: Math.round(rootItem.museStatsTotalSessions).toString()
                tileLabel: "sessions"
                tileTip: rootItem.formatTokens(rootItem.museStatsTotalMessages) + " messages total"
            }
            StatTile {
                tileValue: Math.round(rootItem.museStatsActiveDays) + (rootItem.museStatsSpanDays > 0 ? "/" + Math.round(rootItem.museStatsSpanDays) : "")
                tileLabel: "active days"
                tileTip: rootItem.museStatsFirstDate ? "Since " + Qt.formatDate(new Date(rootItem.museStatsFirstDate), "MMM d, yyyy") : ""
            }
            StatTile {
                tileValue: Math.round(rootItem.museStatsCurrentStreak) + "d"
                tileLabel: "streak"
                tileSub: "best " + Math.round(rootItem.museStatsLongestStreak) + "d"
                tileTip: "Current consecutive-day streak\nLongest: " + Math.round(rootItem.museStatsLongestStreak) + " days"
            }
            StatTile {
                tileValue: rootItem.formatDuration(rootItem.museStatsLongestSessionMs)
                tileLabel: "longest session"
                tileSub: rootItem.museStatsLongestSessionMessages > 0 ? Math.round(rootItem.museStatsLongestSessionMessages) + " msgs" : ""
            }
            StatTile {
                visible: rootItem.museStatsPeakHour >= 0
                tileValue: rootItem.museStatsPeakHour >= 0 ? (rootItem.museStatsPeakHour < 10 ? "0" : "") + rootItem.museStatsPeakHour + ":00" : "—"
                tileLabel: "peak hour"
                tileTip: "Hour of day with the most activity (UTC)"
            }
            StatTile {
                visible: rootItem.museStatsTotalToolCalls > 0
                tileValue: rootItem.formatTokens(rootItem.museStatsTotalToolCalls)
                tileLabel: "tool calls"
                tileTip: "Total tool invocations across all sessions"
            }
            StatTile {
                visible: rootItem.museStatsSubagentSessions > 0
                tileValue: Math.round(rootItem.museStatsSubagentSessions).toString()
                tileLabel: "subagents"
                tileTip: "Delegated subagent sessions, logged separately by Muse"
            }
        }

        StatsSparkline {
            series: rootItem.museStatsDailyTokens
            unit: "tokens"
            barColor: rootItem.museBlue
            formatValue: rootItem.formatTokens
        }

        StatsTopList {
            entries: rootItem.museStatsTopWorkspaces
            label: "Top workspaces"
            accent: rootItem.museBlue
        }

        // ── Per-model usage (all time) ─────────────────────────────────────
        Repeater {
            model: {
                var keys = Object.keys(rootItem.museStatsModels);
                keys.sort(function (a, b) {
                    return rootItem.museStatsModels[b].output - rootItem.museStatsModels[a].output;
                });
                return keys;
            }
            RowLayout {
                required property string modelData
                readonly property var entry: rootItem.museStatsModels[modelData] || ({})

                Layout.fillWidth: true
                spacing: 8

                PlasmaComponents.Label {
                    text: rootItem.shortenModelName(parent.modelData)
                    font.pixelSize: 10
                    opacity: 0.75
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: rootItem.formatTokens(parent.entry.output || 0) + " out"
                    font.pixelSize: 10
                    opacity: 0.6
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    visible: (parent.entry.cost || 0) > 0
                    text: "$" + (parent.entry.cost || 0).toFixed(2)
                    font.pixelSize: 10
                    color: rootItem.museBlue
                }
            }
        }
    }

    component StatTile: StatTileBase {
        accentColor: rootItem.museBlue
    }
}
