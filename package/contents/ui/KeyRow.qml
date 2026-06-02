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
        text: {
            if (kr.configKey === "claudeAdminApiKey")
                return Plasmoid.configuration.claudeAdminApiKey || "";
            if (kr.configKey === "openaiApiKey")
                return Plasmoid.configuration.openaiApiKey || "";
            if (kr.configKey === "googleApiKey")
                return Plasmoid.configuration.googleApiKey || "";
            if (kr.configKey === "mistralApiKey")
                return Plasmoid.configuration.mistralApiKey || "";
            if (kr.configKey === "openrouterApiKey")
                return Plasmoid.configuration.openrouterApiKey || "";
            return "";
        }
        onEditingFinished: {
            if (kr.configKey === "claudeAdminApiKey")
                Plasmoid.configuration.claudeAdminApiKey = text;
            if (kr.configKey === "openaiApiKey")
                Plasmoid.configuration.openaiApiKey = text;
            if (kr.configKey === "googleApiKey")
                Plasmoid.configuration.googleApiKey = text;
            if (kr.configKey === "mistralApiKey")
                Plasmoid.configuration.mistralApiKey = text;
            if (kr.configKey === "openrouterApiKey")
                Plasmoid.configuration.openrouterApiKey = text;
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
