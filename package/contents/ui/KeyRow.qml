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
            if (kr.configKey === "mistralApiKey")
                return Plasmoid.configuration.mistralApiKey || "";
            if (kr.configKey === "openrouterApiKey")
                return Plasmoid.configuration.openrouterApiKey || "";
            if (kr.configKey === "grokApiKey")
                return Plasmoid.configuration.grokApiKey || "";
            if (kr.configKey === "zaiToken")
                return Plasmoid.configuration.zaiToken || "";
            if (kr.configKey === "githubToken")
                return Plasmoid.configuration.githubToken || "";
            if (kr.configKey === "deepseekApiKey")
                return Plasmoid.configuration.deepseekApiKey || "";
            if (kr.configKey === "moonshotApiKey")
                return Plasmoid.configuration.moonshotApiKey || "";
            return "";
        }
        onEditingFinished: {
            // A key is pasted, never typed, and a paste out of a browser or a
            // password manager often carries a trailing space or newline. Trim
            // once here, the same way the Python interpreter field does, so the
            // stored value is the one the user meant — and write it back to the
            // field, so what is shown is what was saved.
            var val = String(text).trim();
            if (val !== text)
                text = val;

            if (kr.configKey === "claudeAdminApiKey")
                Plasmoid.configuration.claudeAdminApiKey = val;
            if (kr.configKey === "openaiApiKey")
                Plasmoid.configuration.openaiApiKey = val;
            if (kr.configKey === "mistralApiKey")
                Plasmoid.configuration.mistralApiKey = val;
            if (kr.configKey === "openrouterApiKey")
                Plasmoid.configuration.openrouterApiKey = val;
            if (kr.configKey === "grokApiKey")
                Plasmoid.configuration.grokApiKey = val;
            if (kr.configKey === "zaiToken")
                Plasmoid.configuration.zaiToken = val;
            if (kr.configKey === "githubToken")
                Plasmoid.configuration.githubToken = val;
            if (kr.configKey === "deepseekApiKey")
                Plasmoid.configuration.deepseekApiKey = val;
            if (kr.configKey === "moonshotApiKey")
                Plasmoid.configuration.moonshotApiKey = val;
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
