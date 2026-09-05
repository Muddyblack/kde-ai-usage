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

        Kirigami.Icon {
            source: "code-context"
            width: 14
            height: 14
            color: rootItem.museBlue
            isMask: true
            opacity: 0.75
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
            color: Qt.rgba(0.0, 0.39, 0.88, 0.18)
            border.width: 1
            border.color: Qt.rgba(0.0, 0.39, 0.88, 0.35)
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
            color: "#ef4444"
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

        Repeater {
            model: [
                { "label": "Current", "available": rootItem.museCurrentAvailable, "pct": rootItem.museCurrentPct, "countdown": rootItem.museCurrentCountdown },
                { "label": "Weekly", "available": rootItem.museWeeklyAvailable, "pct": rootItem.museWeeklyPct, "countdown": rootItem.museWeeklyCountdown }
            ]
            delegate: ColumnLayout {
                visible: modelData.available
                Layout.fillWidth: true
                spacing: 4
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
                        text: Math.round(modelData.pct) + "%" + (modelData.countdown ? " · " + modelData.countdown : "")
                        font.pixelSize: 12
                        font.bold: true
                        color: rootItem.usageColor(modelData.pct)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        width: parent.width * Math.min(100, Math.max(0, modelData.pct)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: rootItem.usageColor(modelData.pct)
                    }
                }
            }
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
