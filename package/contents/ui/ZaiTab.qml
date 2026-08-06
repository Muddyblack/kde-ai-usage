import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: zaiTabRoot
    property Item rootItem

    visible: rootItem.enabledTabs[rootItem.activeTab] === "zai" && !rootItem.showSettings
    Layout.fillWidth: true
    spacing: 14

    function fmt(value) {
        if (value === null || value === undefined)
            return "—";
        if (value >= 1000000)
            return (value / 1000000).toFixed(1) + "M";
        if (value >= 1000)
            return (value / 1000).toFixed(1) + "K";
        return String(value);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: rootItem.zaiKeyValid

        Kirigami.Icon {
            source: "user-identity"
            width: 14
            height: 14
            color: rootItem.zaiBlue
            isMask: true
            opacity: 0.75
        }

        PlasmaComponents.Label {
            text: rootItem.zaiLevel !== "" ? "Z.AI · " + rootItem.zaiLevel : "Z.AI"
            font.pixelSize: 10
            opacity: 0.65
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            implicitHeight: 18
            implicitWidth: zaiBadgeLabel.implicitWidth + 12
            radius: 4
            color: Qt.rgba(0.07, 0.43, 0.96, 0.18)
            border.width: 1
            border.color: Qt.rgba(0.07, 0.43, 0.96, 0.35)

            PlasmaComponents.Label {
                id: zaiBadgeLabel
                anchors.centerIn: parent
                text: "CONNECTED"
                font.pixelSize: 9
                font.bold: true
                color: rootItem.zaiBlue
            }
        }
    }

    ColumnLayout {
        visible: !rootItem.zaiKeyValid && !rootItem.zaiHasKey && rootItem.zaiError === ""
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
            text: "Set a Z.AI token in settings or via\n$ZAI_TOKEN / ~/.config/zai/token"
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.zaiError !== "" && !rootItem.zaiKeyValid
        Layout.fillWidth: true
        spacing: 6

        PlasmaComponents.Label {
            text: "Z.AI error"
            font.pixelSize: 12
            font.bold: true
            color: "#ef4444"
        }

        PlasmaComponents.Label {
            text: rootItem.zaiError
            font.pixelSize: 10
            opacity: 0.7
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.zaiKeyValid
        Layout.fillWidth: true
        spacing: 8

        PopupRow {
            label: "5h Tokens"
            value: rootItem.zaiTokenPct
            barColor: rootItem.zaiBlue
            countdownText: rootItem.zaiTokenCountdown !== "" ? "in " + rootItem.zaiTokenCountdown : ""
            tokenText: rootItem.zaiTokenUsed === null || rootItem.zaiTokenLimit === null ? "—" : zaiTabRoot.fmt(rootItem.zaiTokenUsed) + " / " + zaiTabRoot.fmt(rootItem.zaiTokenLimit)
            tooltipText: "Z.AI token quota" + (rootItem.zaiTokenCountdown !== "" ? "\nResets in " + rootItem.zaiTokenCountdown : "")
        }

        PopupRow {
            label: "Monthly Tools"
            value: rootItem.zaiToolsPct
            barColor: rootItem.zaiBlue
            countdownText: rootItem.zaiToolsCountdown !== "" ? "in " + rootItem.zaiToolsCountdown : ""
            tokenText: rootItem.zaiToolsRemaining !== null ? zaiTabRoot.fmt(rootItem.zaiToolsRemaining) + " remaining" : "—"
            tooltipText: "Z.AI monthly tool quota" + (rootItem.zaiToolsCountdown !== "" ? "\nResets in " + rootItem.zaiToolsCountdown : "")
        }

        Rectangle {
            visible: rootItem.zaiModels.length > 0
            Layout.fillWidth: true
            height: zaiModelsCol.implicitHeight + 20
            radius: 8
            color: Qt.rgba(0.07, 0.43, 0.96, 0.08)
            border.width: 1
            border.color: Qt.rgba(0.07, 0.43, 0.96, 0.22)

            ColumnLayout {
                id: zaiModelsCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                PlasmaComponents.Label {
                    text: "Model usage"
                    font.pixelSize: 11
                    font.bold: true
                    opacity: 0.75
                    color: Kirigami.Theme.textColor
                }

                Repeater {
                    model: rootItem.zaiModels.slice(0, 5)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PlasmaComponents.Label {
                            text: modelData.modelCode || "unknown"
                            font.pixelSize: 10
                            color: Kirigami.Theme.textColor
                            opacity: 0.7
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        PlasmaComponents.Label {
                            text: zaiTabRoot.fmt(modelData.usage)
                            font.pixelSize: 10
                            font.bold: true
                            color: rootItem.zaiBlue
                        }
                    }
                }
            }
        }
    }
}
