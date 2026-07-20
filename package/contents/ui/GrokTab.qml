import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "grok" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.grokWhite
            isMask: true
        }
        PlasmaComponents.Label {
            text: rootItem.grokTeamName || rootItem.grokEmail || "Grok CLI"
            font.pixelSize: 10
            opacity: 0.65
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: rootItem.grokTierId
            visible: text !== ""
            font.pixelSize: 9
            font.bold: true
            opacity: 0.7
        }
    }

    ColumnLayout {
        visible: !rootItem.grokLoggedIn && rootItem._grokApiKey === ""
        Layout.fillWidth: true
        spacing: 6
        PlasmaComponents.Label {
            text: "Not connected"
            font.bold: true
        }
        PlasmaComponents.Label {
            text: "Run grok --oauth, or add an xAI API key in settings."
            font.pixelSize: 10
            opacity: 0.55
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    PopupRow {
        visible: rootItem.grokHasBilling
        label: "Credit usage"
        value: rootItem.grokPct
        barColor: rootItem.grokWhite
        resetText: rootItem.grokQuotaKind === "free-tier" ? rootItem.grokQuotaWindow : (rootItem.grokBillingPeriodEnd ? "resets " + rootItem.grokBillingPeriodEnd : "")
        tokenText: rootItem.grokMonthlyLimit > 0 ? rootItem.grokUsed.toFixed(2) + " / " + rootItem.grokMonthlyLimit.toFixed(2) : ""
        tooltipText: "Grok CLI billing credits"
    }

    PlasmaComponents.Label {
        visible: (rootItem.grokLoggedIn || rootItem._grokApiKey !== "") && !rootItem.grokHasBilling
        text: "Billing quota is not exposed for this Grok account."
        font.pixelSize: 10
        opacity: 0.55
        Layout.fillWidth: true
    }

    PlasmaComponents.Label {
        visible: rootItem.grokSessionCount > 0
        text: rootItem.grokSessionCount + (rootItem.grokSessionCount === 1 ? " local session · " : " local sessions · ") + rootItem.formatTokens(rootItem.grokTotalTokens) + " tokens · " + rootItem.grokTotalToolCalls + " tool calls"
        font.pixelSize: 10
        opacity: 0.55
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
