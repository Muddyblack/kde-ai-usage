import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// The accent-tinted "label on the left, number on the right" card the Copilot,
// DeepSeek and Muse tabs all show above their charts. Rows come from the
// caller so the card itself knows nothing about any provider:
//   StatValueCard {
//       accent: rootItem.museBlue
//       rows: [{ label: "Tokens", value: "1.2M", strong: true }, …]
//   }
Rectangle {
    id: card

    // [{ label, value, strong?, valueColor? }] — `strong` renders the headline
    // row (bigger, accent-coloured); omit it for the supporting rows.
    property var rows: []
    property color accent: Kirigami.Theme.highlightColor

    Layout.fillWidth: true
    Layout.preferredHeight: cardCol.implicitHeight + 24
    radius: 8
    color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.08)
    border.width: 1
    border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.22)

    ColumnLayout {
        id: cardCol

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        Repeater {
            model: card.rows

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                PlasmaComponents.Label {
                    text: parent.modelData.label || ""
                    font.pixelSize: 11
                    opacity: 0.65
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: parent.modelData.value || ""
                    font.pixelSize: parent.modelData.strong === true ? 14 : 12
                    font.bold: parent.modelData.strong === true
                    opacity: parent.modelData.strong === true ? 1.0 : 0.85
                    color: parent.modelData.valueColor !== undefined ? parent.modelData.valueColor : (parent.modelData.strong === true ? card.accent : Kirigami.Theme.textColor)
                }
            }
        }
    }
}
