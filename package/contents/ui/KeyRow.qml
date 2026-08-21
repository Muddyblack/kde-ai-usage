import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// One API-key settings row: label + masked text field (bound to a plasmoid config
// key) + reveal toggle.
RowLayout {
    id: kr
    property string label: ""
    property string placeholder: ""
    property string configKey: ""
    property bool rowVisible: true
    Layout.fillWidth: true
    spacing: 4
    visible: rowVisible

    PlasmaComponents.Label {
        text: kr.label
        font.pixelSize: 10
        opacity: 0.6
        color: Kirigami.Theme.textColor
        Layout.preferredWidth: 76
        elide: Text.ElideRight
    }
    QQC2.TextField {
        id: kf
        Layout.fillWidth: true
        placeholderText: kr.placeholder
        font.pixelSize: 10
        implicitHeight: 26
        echoMode: krReveal.checked ? TextInput.Normal : TextInput.Password
        // Plasmoid.configuration is a QQmlPropertyMap, so it supports bracket
        // access by key name — no need to enumerate every provider here.
        text: Plasmoid.configuration[kr.configKey] || ""
        onEditingFinished: {
            // A key is pasted, never typed, and a paste out of a browser or a
            // password manager often carries a trailing space or newline. Trim
            // once here, the same way the Python interpreter field does, so the
            // stored value is the one the user meant — and write it back to the
            // field, so what is shown is what was saved.
            var val = String(text).trim();
            if (val !== text)
                text = val;
            Plasmoid.configuration[kr.configKey] = val;
        }
    }
    QQC2.ToolButton {
        id: krReveal
        checkable: true
        implicitWidth: 26
        implicitHeight: 26
        icon.name: checked ? "password-show-off" : "password-show-on"
        display: QQC2.AbstractButton.IconOnly
    }
}
