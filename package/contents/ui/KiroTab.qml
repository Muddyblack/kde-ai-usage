import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: kiroTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "kiro" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.kiroUsageAvailable

        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.kiroPurple
            isMask: true
            opacity: 0.7
        }
        PlasmaComponents.Label {
            text: "Kiro"
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
            Layout.fillWidth: true
        }
        Rectangle {
            visible: rootItem.kiroPlanType !== ""
            implicitHeight: 18
            implicitWidth: kiroPlanLabel.implicitWidth + 16
            radius: 4
            color: rootItem.kiroPlanType === "free" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0.545, 0.361, 0.965, 0.18)
            border.width: 1
            border.color: rootItem.kiroPlanType === "free" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.545, 0.361, 0.965, 0.35)

            PlasmaComponents.Label {
                id: kiroPlanLabel
                anchors.centerIn: parent
                text: rootItem.kiroPlanType.toUpperCase()
                font.pixelSize: 9
                font.bold: true
                color: rootItem.kiroPlanType === "free" ? Kirigami.Theme.textColor : rootItem.kiroPurple
            }
        }
    }

    PopupRow {
        visible: rootItem.kiroUsageAvailable
        label: rootItem.kiroDisplayNamePlural !== "" ? rootItem.kiroDisplayNamePlural : "Credits"
        countdownText: rootItem.kiroCountdown === "resetting..." ? "resetting..." : (rootItem.kiroCountdown ? "in " + rootItem.kiroCountdown : "")
        value: rootItem.kiroPct
        barColor: rootItem.kiroPurple
        etaText: rootItem.usageHistory.length >= 0 ? rootItem.etaToFull("kr", rootItem.kiroPct) : ""
        deltaText: rootItem.usageHistory.length >= 0 ? rootItem.periodDelta("kr", rootItem.kiroPct, 30 * 24 * 3600000, "last month") : ""
        tokenText: rootItem.kiroUsageLimit > 0 ? rootItem.kiroCurrentUsage.toFixed(2) + " / " + rootItem.kiroUsageLimit.toFixed(0) + " used" : rootItem.kiroCurrentUsage.toFixed(2) + " used"
        tooltipText: "Kiro monthly credit usage\nUsed: " + rootItem.kiroCurrentUsage.toFixed(2) + (rootItem.kiroUsageLimit > 0 ? " / " + rootItem.kiroUsageLimit.toFixed(0) : "") + (rootItem.kiroResetTime ? "\nResets: " + rootItem.kiroResetTime : "")
    }

    Rectangle {
        visible: rootItem.kiroUsageAvailable
        Layout.fillWidth: true
        height: kiroStatsCol.implicitHeight + 16
        radius: 8
        color: Qt.rgba(0.545, 0.361, 0.965, 0.08)
        border.width: 1
        border.color: Qt.rgba(0.545, 0.361, 0.965, 0.22)

        ColumnLayout {
            id: kiroStatsCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PlasmaComponents.Label {
                    text: "Current Usage"
                    font.pixelSize: 11
                    opacity: 0.65
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: rootItem.kiroCurrentUsage.toFixed(2) + " " + (rootItem.kiroDisplayNamePlural || "credits").toLowerCase()
                    font.bold: true
                    font.pixelSize: 13
                    color: rootItem.kiroPurple
                }
            }

            RowLayout {
                visible: rootItem.kiroUsageLimit > 0
                Layout.fillWidth: true
                spacing: 8
                PlasmaComponents.Label {
                    text: "Remaining"
                    font.pixelSize: 11
                    opacity: 0.65
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: rootItem.kiroRemaining.toFixed(2)
                    font.bold: true
                    font.pixelSize: 12
                    color: rootItem.usageColor(rootItem.kiroPct)
                }
            }

            RowLayout {
                visible: rootItem.kiroCurrentOverages > 0 || rootItem.kiroOverageCharges > 0
                Layout.fillWidth: true
                spacing: 8
                PlasmaComponents.Label {
                    text: "Overage"
                    font.pixelSize: 11
                    opacity: 0.65
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: rootItem.kiroCurrencySymbol + rootItem.kiroOverageCharges.toFixed(2) + " (" + rootItem.kiroCurrentOverages.toFixed(2) + ")"
                    font.bold: true
                    font.pixelSize: 12
                    color: rootItem.warningColor
                }
            }

            RowLayout {
                visible: rootItem.kiroOverageRate > 0
                Layout.fillWidth: true
                spacing: 8
                PlasmaComponents.Label {
                    text: "Overage Rate"
                    font.pixelSize: 11
                    opacity: 0.65
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: rootItem.kiroCurrencySymbol + rootItem.kiroOverageRate.toFixed(2) + "/" + (rootItem.kiroDisplayName || "credit").toLowerCase()
                    font.bold: true
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                    opacity: 0.85
                }
            }
        }
    }

    PlasmaComponents.Label {
        visible: rootItem.kiroUsageAvailable
        text: "Read locally from Kiro app state. No API key or network request required."
        font.pixelSize: 9
        opacity: 0.45
        color: Kirigami.Theme.textColor
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    ColumnLayout {
        visible: !rootItem.kiroUsageAvailable
        Layout.fillWidth: true
        spacing: 6

        PlasmaComponents.Label {
            text: "No local Kiro usage data found"
            font.pixelSize: 12
            font.bold: true
            color: Kirigami.Theme.textColor
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: "Open Kiro and sign in at least once so the widget can read the local usage snapshot from ~/.config/Kiro/User/globalStorage/state.vscdb."
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
