import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "sathi.ai"

    StyledText {
        width: parent.width
        text: "Sathi AI Plugin Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    
    StringSetting {
        settingKey: "geminiApiKey"
        label: "Google Gemini API Key"
        description: "Keys can be obtained from https://aistudio.google.com/api-keys"
        placeholder: "Enter API key"
        defaultValue: ""
    }
}