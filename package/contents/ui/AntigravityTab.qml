import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: antigravityTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "antigravity" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.antigravityEmail !== "" || rootItem.antigravityPlanType !== ""
        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.googleBlue
            isMask: true
            opacity: 0.7
        }
        PlasmaComponents.Label {
            text: rootItem.antigravityEmail || "Gemini Code Assist"
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Rectangle {
            visible: rootItem.antigravityPlanType !== ""
            implicitHeight: 18
            implicitWidth: planLabel.implicitWidth + 16
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: rootItem.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.26, 0.66, 0.33, 0.18)
            border.width: 1
            border.color: rootItem.antigravityPlanType === "Free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.26, 0.66, 0.33, 0.35)
            PlasmaComponents.Label {
                id: planLabel
                anchors.centerIn: parent
                text: rootItem.antigravityPlanType
                font.pixelSize: 10
                font.bold: true
                color: rootItem.antigravityPlanType === "Free" ? Kirigami.Theme.textColor : rootItem.googleGreen
            }
        }
    }

    PopupRow {
        visible: rootItem.antigravityPromptCreditsMonthly > 0
        label: "Prompt Credits"
        resetText: rootItem.antigravityResetTime ? "resets " + rootItem.antigravityResetTime : ""
        countdownText: rootItem.antigravityCountdown === "resetting..." ? "resetting..." : (rootItem.antigravityCountdown ? "in " + rootItem.antigravityCountdown : "")
        value: rootItem.antigravityPromptCreditsMonthly > 0 ? (1 - rootItem.antigravityPromptCreditsAvailable / rootItem.antigravityPromptCreditsMonthly) * 100 : 0
        barColor: rootItem.googleBlue
        tokenText: rootItem.antigravityPromptCreditsAvailable + " / " + rootItem.formatTokens(rootItem.antigravityPromptCreditsMonthly) + " left"
        tooltipText: "Prompt Credits\nUsed: " + Math.round(value) + "%  ·  " + rootItem.antigravityPromptCreditsAvailable + " / " + rootItem.formatTokens(rootItem.antigravityPromptCreditsMonthly) + " left" + (rootItem.antigravityResetTime ? "\nResets: " + rootItem.antigravityResetTime : "")
    }

    PopupRow {
        visible: rootItem.antigravityPromptCreditsMonthly === 0 && Object.keys(rootItem.antigravityModels).length > 0
        label: "Overall Quota"
        resetText: rootItem.antigravityResetTime ? "resets " + rootItem.antigravityResetTime : ""
        countdownText: rootItem.antigravityCountdown === "resetting..." ? "resetting..." : (rootItem.antigravityCountdown ? "in " + rootItem.antigravityCountdown : "")
        value: rootItem.antigravityPct
        barColor: rootItem.googleBlue
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("ag", rootItem.antigravityPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("ag", rootItem.antigravityPct, 30 * 24 * 3600000, "last month") : ""
        tooltipText: "Average quota usage across Gemini models\n" + Math.round(rootItem.antigravityPct) + "% used" + (rootItem.antigravityResetTime ? "\nResets: " + rootItem.antigravityResetTime : "")
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Object.keys(rootItem.antigravityModels).length > 0

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
        PlasmaComponents.Label {
            text: "Model Quotas"
            font.bold: true
            font.pixelSize: 11
            opacity: 0.7
            color: Kirigami.Theme.textColor
        }

        Repeater {
            model: Object.keys(rootItem.antigravityModels).sort()
            // Wrap in a plain Item so the MouseArea can use anchors.fill without
            // conflicting with layout management (the Item is the layout delegate).
            Item {
                Layout.fillWidth: true
                implicitHeight: modelRow.implicitHeight

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.delay: 400
                    QQC2.ToolTip.text: {
                        var m = rootItem.antigravityModels[modelData];
                        var txt = (m.displayName || modelData) + "\n" + Math.round(m.usedPct) + "% used";
                        if (m.isExhausted)
                            txt += "\n⚠ Quota exhausted";
                        if (m.resetTime)
                            txt += "\nResets: " + Qt.formatDateTime(new Date(m.resetTime), "MMM d, hh:mm");
                        return txt;
                    }
                }

                RowLayout {
                    id: modelRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    PlasmaComponents.Label {
                        text: rootItem.antigravityModels[modelData].displayName || modelData
                        font.pixelSize: 10
                        color: rootItem.antigravityModels[modelData].isExhausted ? rootItem.dangerColor : Kirigami.Theme.textColor
                        opacity: rootItem.antigravityModels[modelData].isExhausted ? 1.0 : 0.65
                        Layout.preferredWidth: 120
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                margins: 1
                            }
                            width: Math.max(0, (parent.width - 2) * (rootItem.antigravityModels[modelData].usedPct / 100))
                            radius: 2
                            color: rootItem.antigravityModels[modelData].isExhausted ? rootItem.dangerColor : rootItem.antigravityModels[modelData].usedPct >= 70 ? rootItem.warningColor : rootItem.googleBlue
                            Behavior on width {
                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        text: rootItem.antigravityModels[modelData].isExhausted ? "100%" : Math.round(rootItem.antigravityModels[modelData].usedPct) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        color: rootItem.usageColor(rootItem.antigravityModels[modelData].usedPct)
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
