import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: claudeTabRoot
    property Item rootItem

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
    }

    PopupRow {
        label: "5 Hours"
        resetText: rootItem.sessionResetTime ? "resets " + rootItem.sessionResetTime : ""
        countdownText: rootItem.sessionCountdown === "resetting..." ? "resetting..." : (rootItem.sessionCountdown ? "in " + rootItem.sessionCountdown : "")
        value: rootItem.sessionPct
        barColor: rootItem.sessionColor
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("s", rootItem.sessionPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("s", rootItem.sessionPct, 24 * 3600000, "yesterday") : ""
        tokenText: rootItem.sessionTokenLimit > 0 ? rootItem.formatTokens(rootItem.sessionTokensUsed) + " / " + rootItem.formatTokens(rootItem.sessionTokenLimit) + " tokens" : ""
        tooltipText: "Claude 5-hour rolling window\nUsage: " + Math.round(rootItem.sessionPct) + "%" + (rootItem.sessionTokenLimit > 0 ? "\n" + rootItem.formatTokens(rootItem.sessionTokensUsed) + " / " + rootItem.formatTokens(rootItem.sessionTokenLimit) + " tokens" : "") + (rootItem.sessionResetTime ? "\nResets: " + rootItem.sessionResetTime : "")
    }

    PopupRow {
        label: "7 Days"
        resetText: rootItem.weeklyResetTime ? "resets " + rootItem.weeklyResetTime : ""
        countdownText: rootItem.weeklyCountdown === "resetting..." ? "resetting..." : (rootItem.weeklyCountdown ? "in " + rootItem.weeklyCountdown : "")
        value: rootItem.weeklyPct
        barColor: rootItem.weeklyColor
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("w", rootItem.weeklyPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("w", rootItem.weeklyPct, 7 * 24 * 3600000, "last week") : ""
        tokenText: rootItem.weeklyTokenLimit > 0 ? rootItem.formatTokens(rootItem.weeklyTokensUsed) + " / " + rootItem.formatTokens(rootItem.weeklyTokenLimit) + " tokens" : ""
        tooltipText: "Claude 7-day rolling window\nUsage: " + Math.round(rootItem.weeklyPct) + "%" + (rootItem.weeklyTokenLimit > 0 ? "\n" + rootItem.formatTokens(rootItem.weeklyTokensUsed) + " / " + rootItem.formatTokens(rootItem.weeklyTokenLimit) + " tokens" : "") + (rootItem.weeklyResetTime ? "\nResets: " + rootItem.weeklyResetTime : "")
    }

    Rectangle {
        visible: rootItem.claudeExtraTokens > 0
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
        visible: rootItem.claudeExtraUsageEnabled && rootItem.claudeExtraUsageLimit > 0
        label: "Extra Purchases"
        value: rootItem.claudeExtraUsagePct
        barColor: rootItem.claudeOrange
        tokenText: rootItem.claudeExtraUsageUsed.toFixed(2) + " / " + rootItem.claudeExtraUsageLimit.toFixed(2) + " " + rootItem.claudeExtraUsageCurrency + " used"
        tooltipText: "Claude pay-as-you-go credit spend\nLimit: " + rootItem.claudeExtraUsageLimit + " " + rootItem.claudeExtraUsageCurrency
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: Object.keys(rootItem.claudeModels).length > 0

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
}
