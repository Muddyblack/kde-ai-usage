import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: copilotTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "copilot" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    readonly property real remaining: Math.max(0, rootItem.copilotQuota - rootItem.copilotUsed)

    function fmtRequests(value) {
        return value.toFixed(value % 1 === 0 ? 0 : 1);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.copilotKeyValid

        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.copilotPurple
            isMask: true
            opacity: 0.75
        }

        PlasmaComponents.Label {
            text: rootItem.copilotUsername !== "" ? "GitHub Copilot · @" + rootItem.copilotUsername : "GitHub Copilot"
            font.pixelSize: 10
            opacity: 0.65
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            implicitHeight: 18
            implicitWidth: copilotBadgeLabel.implicitWidth + 12
            radius: 4
            color: Qt.rgba(0.55, 0.36, 0.96, 0.18)
            border.width: 1
            border.color: Qt.rgba(0.55, 0.36, 0.96, 0.35)

            PlasmaComponents.Label {
                id: copilotBadgeLabel
                anchors.centerIn: parent
                text: "CONNECTED"
                font.pixelSize: 9
                font.bold: true
                color: rootItem.copilotPurple
            }
        }
    }

    ColumnLayout {
        visible: !rootItem.copilotKeyValid && !rootItem.copilotHasKey && rootItem.copilotError === ""
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
            text: "Set a GitHub token in settings or via\n$GITHUB_TOKEN / ~/.config/github-copilot/token"
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.copilotError !== "" && !rootItem.copilotKeyValid
        Layout.fillWidth: true
        spacing: 6

        PlasmaComponents.Label {
            text: "Copilot error"
            font.pixelSize: 12
            font.bold: true
            color: "#ef4444"
        }

        PlasmaComponents.Label {
            text: rootItem.copilotError
            font.pixelSize: 10
            opacity: 0.7
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.copilotKeyValid
        Layout.fillWidth: true
        spacing: 8

        PopupRow {
            label: "Premium Requests"
            value: rootItem.copilotPct
            barColor: rootItem.copilotPurple
            countdownText: rootItem.copilotCountdown !== "" ? "in " + rootItem.copilotCountdown : ""
            tokenText: copilotTabRoot.fmtRequests(rootItem.copilotUsed) + " / " + copilotTabRoot.fmtRequests(rootItem.copilotQuota)
            tooltipText: "GitHub Copilot premium requests" + (rootItem.copilotCountdown !== "" ? "\nResets in " + rootItem.copilotCountdown : "")
        }

        Rectangle {
            Layout.fillWidth: true
            height: copilotStatsCol.implicitHeight + 16
            radius: 8
            color: Qt.rgba(0.55, 0.36, 0.96, 0.08)
            border.width: 1
            border.color: Qt.rgba(0.55, 0.36, 0.96, 0.22)

            ColumnLayout {
                id: copilotStatsCol
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
                        text: "Used"
                        font.pixelSize: 11
                        opacity: 0.65
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: copilotTabRoot.fmtRequests(rootItem.copilotUsed)
                        font.pixelSize: 14
                        font.bold: true
                        color: rootItem.copilotPurple
                    }
                }

                RowLayout {
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
                        text: copilotTabRoot.fmtRequests(copilotTabRoot.remaining)
                        font.pixelSize: 12
                        font.bold: true
                        color: rootItem.usageColor(rootItem.copilotPct)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PlasmaComponents.Label {
                        text: "Reset"
                        font.pixelSize: 11
                        opacity: 0.65
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: rootItem.copilotCountdown !== "" ? rootItem.copilotCountdown : "next month"
                        font.pixelSize: 12
                        color: Kirigami.Theme.textColor
                        opacity: 0.85
                    }
                }
            }
        }
    }
}
