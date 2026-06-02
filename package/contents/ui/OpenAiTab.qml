import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: openAiTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "openai" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    // Codex / ChatGPT user identity & limits (top section, clean style)
    ColumnLayout {
        visible: rootItem.openaiCodexLoggedIn
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
        }

        // Codex plan limits (messages remaining)
        ColumnLayout {
            visible: rootItem.codexUsageAvailable
            Layout.fillWidth: true
            spacing: 12

            PopupRow {
                label: "5 Hours"
                countdownText: rootItem.codexPrimaryCountdown === "resetting..." ? "resetting..." : (rootItem.codexPrimaryCountdown ? "in " + rootItem.codexPrimaryCountdown : "")
                value: rootItem.codexPrimaryPct
                barColor: rootItem.openaiGreen
                etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("cp", rootItem.codexPrimaryPct) : ""
                deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("cp", rootItem.codexPrimaryPct, 5 * 3600000, "last 5h") : ""
                tokenText: Math.round(100 - rootItem.codexPrimaryPct) + "% of messages left"
                tooltipText: "Codex 5-hour limit\nUsed: " + Math.round(rootItem.codexPrimaryPct) + "%  ·  " + Math.round(100 - rootItem.codexPrimaryPct) + "% left"
            }
            PopupRow {
                label: "Weekly"
                countdownText: rootItem.codexSecondaryCountdown === "resetting..." ? "resetting..." : (rootItem.codexSecondaryCountdown ? "in " + rootItem.codexSecondaryCountdown : "")
                value: rootItem.codexSecondaryPct
                barColor: rootItem.openaiGreen
                etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("cw", rootItem.codexSecondaryPct) : ""
                deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("cw", rootItem.codexSecondaryPct, 7 * 24 * 3600000, "last week") : ""
                tokenText: Math.round(100 - rootItem.codexSecondaryPct) + "% of messages left"
                tooltipText: "Codex weekly limit\nUsed: " + Math.round(rootItem.codexSecondaryPct) + "%  ·  " + Math.round(100 - rootItem.codexSecondaryPct) + "% left"
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
                        label: "5 Hours"
                        countdownText: {
                            if (!modelData.primary_reset)
                                return "";
                            var cd = rootItem.formatCountdown(modelData.primary_reset);
                            return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                        }
                        value: modelData.primary_pct
                        barColor: rootItem.openaiGreen
                        tokenText: Math.round(100 - modelData.primary_pct) + "% of messages left"
                        tooltipText: modelData.name + " 5-hour limit\nUsed: " + Math.round(modelData.primary_pct) + "%  ·  " + Math.round(100 - modelData.primary_pct) + "% left"
                    }
                    PopupRow {
                        label: "Weekly"
                        countdownText: {
                            if (!modelData.secondary_reset)
                                return "";
                            var cd = rootItem.formatCountdown(modelData.secondary_reset);
                            return cd === "resetting..." ? "resetting..." : (cd ? "in " + cd : "");
                        }
                        value: modelData.secondary_pct
                        barColor: rootItem.openaiGreen
                        tokenText: Math.round(100 - modelData.secondary_pct) + "% of messages left"
                        tooltipText: modelData.name + " weekly limit\nUsed: " + Math.round(modelData.secondary_pct) + "%  ·  " + Math.round(100 - modelData.secondary_pct) + "% left"
                    }
                }
            }
        }

        // Notice if no API key is added, matching Claude's tip box design
        PlasmaComponents.Label {
            visible: rootItem._openaiApiKey === ""
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
        visible: rootItem._openaiApiKey !== ""
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
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.delay: 400
                        QQC2.ToolTip.text: {
                            var m = rootItem.openaiModels[modelData];
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
        visible: rootItem._openaiApiKey === "" && !rootItem.openaiCodexLoggedIn && rootItem.enabledTabs[rootItem.activeTab] === "openai"
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
