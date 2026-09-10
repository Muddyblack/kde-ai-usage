import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: kimiTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "kimi" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    // ── Kimi Code plan (the `kimi` CLI login) ────────────────────────────────
    ColumnLayout {
        visible: rootItem.kimiPlanAvailable
        Layout.fillWidth: true
        spacing: 12

        Repeater {
            model: rootItem.kimiPlanWindows
            PopupRow {
                readonly property string countdown: {
                    rootItem.countdownTick;
                    return rootItem.formatCountdown(rootItem.dateFromEpoch(modelData.resetAt));
                }
                label: modelData.label
                countdownText: countdown === "resetting..." ? countdown : (countdown ? "in " + countdown : "")
                value: modelData.pct
                barColor: rootItem.kimiBlue
                tokenText: modelData.used + " / " + modelData.limit + " used"
                tooltipText: "Kimi Code " + modelData.label.toLowerCase() + "\nUsed: " + modelData.used + " / " + modelData.limit
            }
        }

        // A used-up plan answers without windows, only "Credits used up".
        PopupRow {
            visible: rootItem.kimiPlanExhausted && rootItem.kimiPlanWindows.length === 0
            label: "Kimi Code plan"
            value: 100
            barColor: rootItem.kimiBlue
            tokenText: rootItem.kimiPlanMessage || "Plan quota used up"
            tooltipText: "Kimi Code reports the plan quota as used up for this billing cycle"
        }

        RowLayout {
            visible: rootItem.kimiBooster !== null
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: "Extra usage"
                font.pixelSize: 11
                opacity: 0.65
                color: Kirigami.Theme.textColor
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: rootItem.kimiBooster ? rootItem.formatMoney(rootItem.kimiBooster.balance, rootItem.kimiBooster.currency) + " of " + rootItem.formatMoney(rootItem.kimiBooster.total, rootItem.kimiBooster.currency) : ""
                font.pixelSize: 12
                font.bold: true
                color: Kirigami.Theme.textColor
            }
        }

        PlasmaComponents.Label {
            text: "Read with the kimi CLI login (~/.kimi-code). Run kimi once when the login expires."
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    // The plan failed while the Moonshot balance still answers.
    PlasmaComponents.Label {
        visible: rootItem.kimiPlanError !== "" && rootItem.kimiKeyValid
        text: "Kimi Code: " + rootItem.kimiPlanError
        font.pixelSize: 10
        opacity: 0.6
        color: Kirigami.Theme.textColor
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    ColumnLayout {
        visible: !rootItem.kimiKeyValid && !rootItem.kimiHasKey && !rootItem.kimiPlanAvailable && rootItem.kimiError === ""
        Layout.fillWidth: true
        spacing: 6
        PlasmaComponents.Label {
            text: "Not connected"
            font.pixelSize: 12
            font.bold: true
            opacity: 0.7
            color: Kirigami.Theme.textColor
        }
        PlasmaComponents.Label {
            text: "Sign in to Kimi Code (kimi → /login), or set a Moonshot API key in settings or via $MOONSHOT_API_KEY / $KIMI_API_KEY"
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.kimiError !== "" && !rootItem.kimiKeyValid && !rootItem.kimiPlanAvailable
        Layout.fillWidth: true
        spacing: 6
        PlasmaComponents.Label {
            text: "Kimi error"
            font.pixelSize: 12
            font.bold: true
            color: "#ef4444"
        }
        PlasmaComponents.Label {
            text: rootItem.kimiError
            font.pixelSize: 10
            opacity: 0.7
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Rectangle {
        visible: rootItem.kimiKeyValid
        Layout.fillWidth: true
        height: balanceColumn.implicitHeight + 24
        radius: 8
        color: Qt.rgba(0.12, 0.23, 0.54, 0.10)
        border.width: 1
        border.color: Qt.rgba(0.12, 0.23, 0.54, 0.28)

        ColumnLayout {
            id: balanceColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            PlasmaComponents.Label {
                text: "Kimi / Moonshot"
                font.pixelSize: 11
                font.bold: true
                color: Kirigami.Theme.textColor
            }

            Repeater {
                model: [
                    {
                        label: "Available balance",
                        value: rootItem.kimiAvailableBalance,
                        prominent: true
                    },
                    {
                        label: "Voucher balance",
                        value: rootItem.kimiVoucherBalance,
                        prominent: false
                    },
                    {
                        label: "Cash balance",
                        value: rootItem.kimiCashBalance,
                        prominent: false
                    }
                ]
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: modelData.label
                        font.pixelSize: 11
                        opacity: 0.65
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        text: rootItem.formatMoney(modelData.value, "USD")
                        font.pixelSize: modelData.prominent ? 16 : 12
                        font.bold: modelData.prominent
                        color: modelData.prominent ? rootItem.kimiBlue : Kirigami.Theme.textColor
                    }
                }
            }
        }
    }
}
