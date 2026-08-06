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

    ColumnLayout {
        visible: !rootItem.kimiKeyValid && !rootItem.kimiHasKey && rootItem.kimiError === ""
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
            text: "Set a Moonshot API key in settings or via\n$MOONSHOT_API_KEY / $KIMI_API_KEY"
            font.pixelSize: 10
            opacity: 0.5
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: rootItem.kimiError !== "" && !rootItem.kimiKeyValid
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
