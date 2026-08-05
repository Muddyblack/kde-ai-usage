import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One tile in a provider's "Stats" grid: a big accented value with a small
// caption underneath. Providers subclass this to pin their accent colour, e.g.
//   component StatTile: StatTileBase { accentColor: rootItem.openaiGreen }
Rectangle {
    id: tile

    property string tileLabel: ""
    property string tileValue: ""
    property string tileSub: ""
    property string tileTip: ""
    property color accentColor: Kirigami.Theme.highlightColor

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 5
    color: Qt.rgba(1, 1, 1, 0.04)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    QQC2.ToolTip.visible: tile.tileTip !== "" && tileMA.containsMouse
    QQC2.ToolTip.delay: 400
    QQC2.ToolTip.text: tile.tileTip

    MouseArea {
        id: tileMA

        anchors.fill: parent
        hoverEnabled: true
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: tile.tileValue
            font.pixelSize: 14
            font.bold: true
            color: tile.accentColor
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: tile.tileLabel + (tile.tileSub ? " · " + tile.tileSub : "")
            font.pixelSize: 8
            opacity: 0.5
            color: Kirigami.Theme.textColor
        }
    }
}
