import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: settingsPanelRoot
    property Item rootItem

    visible: rootItem.showSettings
    Layout.fillWidth: true
    spacing: 10

    // ── Services ───────────────────────────────────────────────
    PlasmaComponents.Label {
        text: "Services"
        font.bold: true
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
    }

    // 2-column grid of toggles
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 2

        Repeater {
            model: [
                {
                    id: "claude",
                    label: "Claude",
                    color: "#cc785c"
                },
                {
                    id: "antigravity",
                    label: "Antigravity",
                    color: "#4285f4"
                },
                {
                    id: "openai",
                    label: "OpenAI",
                    color: "#10a37f"
                },
                {
                    id: "mistral",
                    label: "Mistral",
                    color: "#ff7000"
                },
                {
                    id: "openrouter",
                    label: "OpenRouter",
                    color: "#9333ea"
                },
                {
                    id: "__spacer",
                    label: "",
                    color: "transparent"
                }
            ]
            RowLayout {
                spacing: 6
                visible: modelData.id !== "__spacer"
                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: modelData.color
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents.Label {
                    text: modelData.label
                    font.pixelSize: 11
                    color: Kirigami.Theme.textColor
                    Layout.preferredWidth: 80
                }
                QQC2.Switch {
                    implicitHeight: 20
                    checked: {
                        if (modelData.id === "claude")
                            return Plasmoid.configuration.claudeEnabled;
                        if (modelData.id === "antigravity")
                            return Plasmoid.configuration.antigravityEnabled;
                        if (modelData.id === "openai")
                            return Plasmoid.configuration.openaiEnabled;
                        if (modelData.id === "mistral")
                            return Plasmoid.configuration.mistralEnabled;
                        if (modelData.id === "openrouter")
                            return Plasmoid.configuration.openrouterEnabled;
                        return false;
                    }
                    onToggled: {
                        if (modelData.id === "claude")
                            Plasmoid.configuration.claudeEnabled = checked;
                        if (modelData.id === "antigravity")
                            Plasmoid.configuration.antigravityEnabled = checked;
                        if (modelData.id === "openai")
                            Plasmoid.configuration.openaiEnabled = checked;
                        if (modelData.id === "mistral")
                            Plasmoid.configuration.mistralEnabled = checked;
                        if (modelData.id === "openrouter")
                            Plasmoid.configuration.openrouterEnabled = checked;
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: rootItem.weeklyColor
            Layout.alignment: Qt.AlignVCenter
        }
        PlasmaComponents.Label {
            text: "Usage chart"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        QQC2.Switch {
            implicitHeight: 20
            checked: Plasmoid.configuration.showUsageChart
            onToggled: Plasmoid.configuration.showUsageChart = checked
        }
    }

    // Theme accent toggle
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: Kirigami.Theme.highlightColor
            Layout.alignment: Qt.AlignVCenter
        }
        PlasmaComponents.Label {
            text: "Theme accent"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        QQC2.Switch {
            implicitHeight: 20
            checked: Plasmoid.configuration.useThemeAccent
            onToggled: {
                Plasmoid.configuration.useThemeAccent = checked;
                rootItem.useThemeAccent = checked;
            }
        }
        PlasmaComponents.Label {
            text: "Use Plasma accent color"
            font.pixelSize: 9
            opacity: 0.45
            color: Kirigami.Theme.textColor
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    // Poll interval
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: Qt.rgba(1, 1, 1, 0.3)
            Layout.alignment: Qt.AlignVCenter
        }
        PlasmaComponents.Label {
            text: "Refresh"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        QQC2.ComboBox {
            id: pollCombo
            implicitHeight: 24
            Layout.preferredWidth: 120
            font.pixelSize: 10
            readonly property var secs: [60, 120, 300, 600, 900, 1800]
            model: ["1 min", "2 min", "5 min", "10 min", "15 min", "30 min"]
            currentIndex: Math.max(0, secs.indexOf(Plasmoid.configuration.pollIntervalSec || 300))
            onActivated: {
                var s = secs[currentIndex];
                Plasmoid.configuration.pollIntervalSec = s;
                rootItem.pollIntervalSec = s;
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }

    // ── Appearance ──────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }
    PlasmaComponents.Label {
        text: "Appearance"
        font.bold: true
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
    }

    // Grid of appearance settings
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 6

        // Row 1: Popup Background Color & Opacity
        PlasmaComponents.Label {
            text: "Popup BG"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        RowLayout {
            spacing: 4
            Layout.fillWidth: true
            Rectangle {
                width: 12
                height: 12
                radius: 2
                color: rootItem.resolvedPopupBg
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        rootItem.colorTarget = "popup";
                        rootItem.colorDialog.selectedColor = rootItem.popupBgColor;
                        rootItem.colorDialog.open();
                    }
                    QQC2.ToolTip.delay: 400
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: "Click to open color picker"
                }
            }
            QQC2.TextField {
                text: Plasmoid.configuration.popupBgColor || "#000000"
                placeholderText: "#000000"
                implicitHeight: 22
                Layout.fillWidth: true
                font.pixelSize: 9
                onTextEdited: {
                    if (/^#[0-9A-Fa-f]{6}$/.test(text)) {
                        Plasmoid.configuration.popupBgColor = text;
                        rootItem.popupBgColor = text;
                    }
                }
            }
        }
        RowLayout {
            spacing: 4
            PlasmaComponents.Label {
                text: "Opacity:"
                font.pixelSize: 10
                opacity: 0.6
            }
            QQC2.TextField {
                text: Math.round(rootItem.popupBgOpacity * 100)
                placeholderText: "0"
                implicitHeight: 22
                Layout.preferredWidth: 32
                font.pixelSize: 9
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                onTextEdited: {
                    var val = parseInt(text);
                    if (!isNaN(val) && val >= 0 && val <= 100) {
                        var opacityVal = val / 100.0;
                        Plasmoid.configuration.popupBgOpacity = opacityVal;
                        rootItem.popupBgOpacity = opacityVal;
                    }
                }
            }
            PlasmaComponents.Label {
                text: "%"
                font.pixelSize: 10
                opacity: 0.6
            }
        }

        // Row 2: Card Background Color & Opacity
        PlasmaComponents.Label {
            text: "Card BG"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        RowLayout {
            spacing: 4
            Layout.fillWidth: true
            Rectangle {
                width: 12
                height: 12
                radius: 2
                color: rootItem.resolvedCardBg
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        rootItem.colorTarget = "card";
                        rootItem.colorDialog.selectedColor = rootItem.cardBgColor;
                        rootItem.colorDialog.open();
                    }
                    QQC2.ToolTip.delay: 400
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: "Click to open color picker"
                }
            }
            QQC2.TextField {
                text: Plasmoid.configuration.cardBgColor || "#100a1a"
                placeholderText: "#100a1a"
                implicitHeight: 22
                Layout.fillWidth: true
                font.pixelSize: 9
                onTextEdited: {
                    if (/^#[0-9A-Fa-f]{6}$/.test(text)) {
                        Plasmoid.configuration.cardBgColor = text;
                        rootItem.cardBgColor = text;
                    }
                }
            }
        }
        RowLayout {
            spacing: 4
            PlasmaComponents.Label {
                text: "Opacity:"
                font.pixelSize: 10
                opacity: 0.6
            }
            QQC2.TextField {
                text: Math.round(rootItem.cardBgOpacity * 100)
                placeholderText: "90"
                implicitHeight: 22
                Layout.preferredWidth: 32
                font.pixelSize: 9
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                onTextEdited: {
                    var val = parseInt(text);
                    if (!isNaN(val) && val >= 0 && val <= 100) {
                        var opacityVal = val / 100.0;
                        Plasmoid.configuration.cardBgOpacity = opacityVal;
                        rootItem.cardBgOpacity = opacityVal;
                    }
                }
            }
            PlasmaComponents.Label {
                text: "%"
                font.pixelSize: 10
            }
        }

        // Row 3: Widget Background Style
        PlasmaComponents.Label {
            text: "Bg Style"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        QQC2.ComboBox {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            implicitHeight: 22
            font.pixelSize: 10
            model: ["Plasma Native", "Translucent (Flat)", "Glassmorphic (Shadow + Blur)"]
            currentIndex: {
                var val = rootItem.backgroundHints;
                if (val === 0)
                    return 0;
                if (val === 1)
                    return 1;
                if (val === 2)
                    return 2;
                return 1;
            }
            onActivated: {
                var hints = 1;
                if (index === 0)
                    hints = 0;
                else if (index === 1)
                    hints = 1;
                else if (index === 2)
                    hints = 2;
                Plasmoid.configuration.backgroundHints = hints;
                rootItem.backgroundHints = hints;
            }
        }
    }

    // History export / import
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: rootItem.activeAccent
            Layout.alignment: Qt.AlignVCenter
        }
        PlasmaComponents.Label {
            text: "History"
            font.pixelSize: 11
            color: Kirigami.Theme.textColor
            Layout.preferredWidth: 80
        }
        PlasmaComponents.Button {
            text: "Export"
            icon.name: "document-export"
            implicitHeight: 26
            font.pixelSize: 10
            onClicked: rootItem.exportHistory()
        }
        PlasmaComponents.Button {
            text: "Import"
            icon.name: "document-import"
            implicitHeight: 26
            font.pixelSize: 10
            onClicked: rootItem.importHistory()
        }
        Item {
            Layout.fillWidth: true
        }
    }

    PlasmaComponents.Label {
        visible: rootItem.historyIOMsg !== ""
        text: rootItem.historyIOMsg
        font.pixelSize: 9
        opacity: 0.6
        color: Kirigami.Theme.textColor
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ── API Keys ───────────────────────────────────────────────
    PlasmaComponents.Label {
        text: "API Keys"
        font.bold: true
        font.pixelSize: 10
        opacity: 0.5
        color: Kirigami.Theme.textColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        KeyRow {
            label: "Claude Admin"
            placeholder: "sk-ant-api03-…"
            configKey: "claudeAdminApiKey"
        }
        KeyRow {
            label: "OpenAI API"
            placeholder: "sk-proj-…"
            configKey: "openaiApiKey"
        }
        KeyRow {
            label: "Google AI"
            placeholder: "AIza…"
            configKey: "googleApiKey"
        }
        KeyRow {
            label: "Mistral"
            placeholder: "or $MISTRAL_API_KEY"
            configKey: "mistralApiKey"
            rowVisible: Plasmoid.configuration.mistralEnabled
        }
        KeyRow {
            label: "OpenRouter"
            placeholder: "or $OPENROUTER_API_KEY"
            configKey: "openrouterApiKey"
            rowVisible: Plasmoid.configuration.openrouterEnabled
        }
    }
}
