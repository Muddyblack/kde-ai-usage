import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Cline is stats-only: its own session logs under ~/.cline, read offline.
ColumnLayout {
    id: clineTabRoot
    property Item rootItem

    readonly property var stats: rootItem.clineStats || ({})
    readonly property bool statsAvailable: stats.available === true

    visible: rootItem.enabledTabs[rootItem.activeTab] === "cline" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 8

    PlasmaComponents.Label {
        visible: !clineTabRoot.statsAvailable
        Layout.fillWidth: true
        Layout.topMargin: 8
        horizontalAlignment: Text.AlignHCenter
        text: "No Cline sessions yet.\nRun the Cline CLI and its session logs in ~/.cline will appear here."
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
        wrapMode: Text.WordWrap
    }

    // ── Recent usage: a lifetime token total says little on its own, since a
    // token costs very different amounts from model to model ────────────────
    StatValueCard {
        visible: clineTabRoot.statsAvailable && rootItem.clinePeriods.length > 0
        accent: rootItem.clineWhite
        rows: rootItem.clinePeriods.map(function (p) {
            return {
                label: p.label,
                value: rootItem.formatTokens(p.tokens || 0) + " tok · " + p.sessions + (p.sessions === 1 ? " session" : " sessions") + ((p.cost || 0) > 0 ? " · " + rootItem.formatMoney(p.cost, "USD") : ""),
                strong: p.key === "cline_30d"
            };
        })
    }

    ColumnLayout {
        visible: clineTabRoot.statsAvailable
        Layout.fillWidth: true
        spacing: 8

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
                text: "Cline CLI · all time"
                font.pixelSize: 9
                opacity: 0.45
                color: Kirigami.Theme.textColor
            }
            StatusChip {
                Layout.alignment: Qt.AlignVCenter
                status: rootItem.providerStatus.cline
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            StatTile {
                tileValue: rootItem.formatTokens(clineTabRoot.stats.totalTokens || 0)
                tileLabel: "tokens"
                tileTip: rootItem.formatTokens(clineTabRoot.stats.totalOutputTokens || 0) + " output · " + rootItem.formatTokens(clineTabRoot.stats.totalInputTokens || 0) + " input · " + rootItem.formatTokens(clineTabRoot.stats.totalCachedTokens || 0) + " cache read"
            }
            StatTile {
                visible: (clineTabRoot.stats.totalCostUSD || 0) > 0
                tileValue: rootItem.formatMoney(clineTabRoot.stats.totalCostUSD || 0, "USD")
                tileLabel: "spend"
                tileTip: "Cost Cline recorded per session"
            }
            StatTile {
                tileValue: Math.round(clineTabRoot.stats.totalSessions || 0).toString()
                tileLabel: "sessions"
            }
            StatTile {
                tileValue: Math.round(clineTabRoot.stats.activeDays || 0) + ((clineTabRoot.stats.spanDays || 0) > 0 ? "/" + Math.round(clineTabRoot.stats.spanDays) : "")
                tileLabel: "active days"
                tileTip: clineTabRoot.stats.firstDate ? "Since " + Qt.formatDate(new Date(clineTabRoot.stats.firstDate), "MMM d, yyyy") : ""
            }
            StatTile {
                tileValue: Math.round(clineTabRoot.stats.currentStreak || 0) + "d"
                tileLabel: "streak"
                tileSub: "best " + Math.round(clineTabRoot.stats.longestStreak || 0) + "d"
            }
            StatTile {
                visible: (clineTabRoot.stats.longestSessionMs || 0) > 0
                tileValue: rootItem.formatDuration(clineTabRoot.stats.longestSessionMs || 0)
                tileLabel: "longest session"
            }
            StatTile {
                visible: clineTabRoot.stats.peakHour !== undefined && clineTabRoot.stats.peakHour >= 0
                tileValue: clineTabRoot.stats.peakHour >= 0 ? (clineTabRoot.stats.peakHour < 10 ? "0" : "") + clineTabRoot.stats.peakHour + ":00" : "—"
                tileLabel: "peak hour"
                tileTip: "Hour of day when most sessions started"
            }
        }

        StatsSparkline {
            series: clineTabRoot.stats.dailySeries || []
            unit: "tokens"
            barColor: rootItem.clineWhite
            formatValue: rootItem.formatTokens
        }

        StatsTopList {
            entries: clineTabRoot.stats.topWorkspaces || []
            label: "Top workspaces"
            accent: rootItem.clineWhite
        }

        // ── Per-model usage (all time) ─────────────────────────────────────
        Repeater {
            model: {
                var m = clineTabRoot.stats.models || ({});
                var keys = Object.keys(m);
                keys.sort(function (a, b) {
                    return (m[b].total || 0) - (m[a].total || 0);
                });
                return keys;
            }
            RowLayout {
                required property string modelData
                readonly property var entry: (clineTabRoot.stats.models || ({}))[modelData] || ({})

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
                    text: rootItem.formatTokens(parent.entry.total || 0) + " tok"
                    font.pixelSize: 10
                    opacity: 0.6
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    visible: (parent.entry.cost || 0) > 0
                    text: rootItem.formatMoney(parent.entry.cost || 0, "USD")
                    font.pixelSize: 10
                    color: rootItem.clineWhite
                }
            }
        }
    }

    component StatTile: StatTileBase {
        accentColor: rootItem.clineWhite
    }
}
