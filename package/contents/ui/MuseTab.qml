import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: museTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "muse" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.museSessions > 0 || rootItem.museCurrentAvailable

        // Brand mark, with the generic symbolic icon as the only fallback —
        // same Image/status === Image.Error pattern the panel slots use.
        Item {
            width: 14
            height: 14
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: museHeaderIcon
                anchors.fill: parent
                source: Qt.resolvedUrl("../icons/muse-color.svg")
                sourceSize.width: 28
                sourceSize.height: 28
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: 0.9
                visible: status !== Image.Error
            }

            Kirigami.Icon {
                anchors.fill: parent
                source: "code-context"
                color: rootItem.museBlue
                isMask: true
                opacity: 0.75
                visible: museHeaderIcon.status === Image.Error
            }
        }

        PlasmaComponents.Label {
            text: rootItem.museEmail || rootItem.museFullName || "Muse"
            font.pixelSize: 10
            opacity: 0.65
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            visible: rootItem.museActiveModel !== ""
            text: rootItem.museActiveModel
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            visible: rootItem.musePlanType !== ""
            height: 18
            width: musePlanBadgeLabel.implicitWidth + 12
            radius: 4
            color: Qt.rgba(rootItem.museBlue.r, rootItem.museBlue.g, rootItem.museBlue.b, 0.18)
            border.width: 1
            border.color: Qt.rgba(rootItem.museBlue.r, rootItem.museBlue.g, rootItem.museBlue.b, 0.35)
            PlasmaComponents.Label {
                id: musePlanBadgeLabel
                anchors.centerIn: parent
                text: rootItem.musePlanType
                font.pixelSize: 9
                font.bold: true
                color: rootItem.museBlue
            }
        }
    }

    ColumnLayout {
        visible: rootItem.museSessions === 0 && !rootItem.museCurrentAvailable && rootItem.museError === ""
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
            text: "Run muse once and log in with\n`muse login`"
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.museError !== "" && rootItem.museSessions === 0 && !rootItem.museCurrentAvailable
        Layout.fillWidth: true
        spacing: 6
        PlasmaComponents.Label {
            text: "Muse error"
            font.pixelSize: 12
            font.bold: true
            color: Kirigami.Theme.negativeTextColor
        }
        PlasmaComponents.Label {
            text: rootItem.museError
            font.pixelSize: 10
            opacity: 0.7
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.museCurrentAvailable || rootItem.museWeeklyAvailable
        Layout.fillWidth: true
        spacing: 8

        // Shared segmented bar, same as every other quota tab. Muse exposes no
        // token counts or burn rate, so tokenText/etaText stay unset.
        PopupRow {
            visible: rootItem.museCurrentAvailable
            label: "Current"
            value: rootItem.museCurrentPct
            barColor: rootItem.museBlue
            countdownText: rootItem.museCurrentCountdown !== "" ? "in " + rootItem.museCurrentCountdown : ""
            tooltipText: "Muse current usage window" + (rootItem.museCurrentCountdown !== "" ? "\nResets in " + rootItem.museCurrentCountdown : "")
        }

        PopupRow {
            visible: rootItem.museWeeklyAvailable
            label: "Weekly"
            value: rootItem.museWeeklyPct
            barColor: rootItem.museBlue
            countdownText: rootItem.museWeeklyCountdown !== "" ? "in " + rootItem.museWeeklyCountdown : ""
            tooltipText: "Muse weekly usage window" + (rootItem.museWeeklyCountdown !== "" ? "\nResets in " + rootItem.museWeeklyCountdown : "")
        }
    }

    // Why the quota bars are missing, when the reason is worth acting on. A
    // disabled switch or an absent login are the user's own doing and stay
    // silent; a refused or unreachable endpoint is not.
    RowLayout {
        visible: !rootItem.museCurrentAvailable && !rootItem.museWeeklyAvailable && (rootItem.museQuotaError === "rejected" || rootItem.museQuotaError === "unreachable")
        Layout.fillWidth: true
        spacing: 5

        Kirigami.Icon {
            source: rootItem.museQuotaError === "rejected" ? "dialog-warning" : "network-disconnect"
            width: 11
            height: 11
            isMask: true
            color: Kirigami.Theme.neutralTextColor
            opacity: 0.8
            Layout.alignment: Qt.AlignVCenter
        }

        PlasmaComponents.Label {
            text: rootItem.museQuotaError === "rejected" ? "Live quota refused — check the Muse login" : "Live quota unreachable — showing local statistics"
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    PlasmaComponents.Label {
        visible: !rootItem.museCurrentAvailable && !rootItem.museWeeklyAvailable && (rootItem.museSessions > 0 || rootItem.museTotalOutputTokens > 0)
        text: rootItem.museSessions + " sessions · " + rootItem.formatTokens(rootItem.museTotalOutputTokens) + " out"
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
