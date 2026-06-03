import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// A labelled usage row: title + reset/countdown + animated %, a segmented bar,
// optional burn-rate ETA / period-comparison line, and an optional sub-label.
ColumnLayout {
    id: row
    property string label: ""
    property string resetText: ""
    property string countdownText: ""
    property real value: 0
    property color barColor: Kirigami.Theme.positiveTextColor
    property string tooltipText: ""
    property string tokenText: ""
    // Burn-rate ETA text (e.g. "~3h to 100%") and period-over-period delta text
    property string etaText: ""
    property string deltaText: ""

    // usage-level thresholds (kept local so this component is self-contained)
    readonly property color dangerColor: "#ff4d4d"
    readonly property color warningColor: "#ffa64d"

    readonly property int segmentCount: 20

    // Animated value driving the big % readout (rolls up/down)
    property real displayValue: 0
    onValueChanged: displayValue = value
    Component.onCompleted: displayValue = value
    Behavior on displayValue {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    Layout.fillWidth: true
    spacing: 5

    // Overlay mouse area for the tooltip. Must be in an Item with Layout
    // properties (not anchors) so the ColumnLayout can manage its geometry.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0   // zero-height so it doesn't push siblings
        // Extend visually over the whole row via z-ordered MouseArea
        MouseArea {
            // Reach up to cover the full ColumnLayout by using the parent chain
            x: 0
            y: -row.height   // position from top of the ColumnLayout
            width: row.width
            height: row.height
            hoverEnabled: true
            propagateComposedEvents: true
            QQC2.ToolTip.visible: containsMouse && row.tooltipText !== ""
            QQC2.ToolTip.text: row.tooltipText
            QQC2.ToolTip.delay: 500
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        PlasmaComponents.Label {
            text: row.label
            font.bold: true
            font.pixelSize: 13
            color: Kirigami.Theme.textColor
        }
        PlasmaComponents.Label {
            visible: row.resetText !== ""
            text: "· " + row.resetText
            font.pixelSize: 11
            opacity: 0.5
            color: Kirigami.Theme.textColor
        }
        Item {
            Layout.fillWidth: true
        }
        Rectangle {
            visible: row.countdownText !== ""
            height: 20
            width: cdLabel.implicitWidth + 14
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Layout.alignment: Qt.AlignVCenter
            PlasmaComponents.Label {
                id: cdLabel
                anchors.centerIn: parent
                text: row.countdownText
                font.pixelSize: 11
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }
        }
        Item {
            width: 2
        }
        PlasmaComponents.Label {
            text: Math.round(row.displayValue) + "%"
            font.bold: true
            font.pixelSize: 14
            color: row.value >= 90 ? row.dangerColor : row.value >= 70 ? row.warningColor : row.barColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ── Burn-rate ETA + period comparison ────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: row.etaText !== "" || row.deltaText !== ""

        PlasmaComponents.Label {
            visible: row.etaText !== ""
            text: "↗ " + row.etaText
            font.pixelSize: 10
            color: row.warningColor
            opacity: 0.9
        }
        Item {
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            visible: row.deltaText !== ""
            text: row.deltaText
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
        }
    }

    Item {
        Layout.fillWidth: true
        height: 8
        Row {
            anchors.fill: parent
            spacing: 3
            Repeater {
                model: row.segmentCount
                Rectangle {
                    width: (row.width - (row.segmentCount - 1) * 3) / row.segmentCount
                    height: parent.height
                    radius: 2
                    readonly property real segThresh: (index + 1) * (100 / row.segmentCount)
                    readonly property real prevThresh: index * (100 / row.segmentCount)
                    readonly property real fillRatio: {
                        if (row.value >= segThresh)
                            return 1.0;
                        if (row.value <= prevThresh)
                            return 0.0;
                        return (row.value - prevThresh) / (100 / row.segmentCount);
                    }
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            margins: 1
                        }
                        width: Math.max(0, (parent.width - 2) * parent.fillRatio)
                        radius: 1.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: Qt.lighter(row.barColor, 1.15)
                            }
                            GradientStop {
                                position: 1.0
                                color: row.barColor
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    PlasmaComponents.Label {
        visible: row.tokenText !== ""
        text: row.tokenText
        font.pixelSize: 9
        opacity: 0.45
        color: Kirigami.Theme.textColor
        Layout.topMargin: -2
    }
}
