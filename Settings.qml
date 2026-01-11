import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "sathiAi"

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

    StringSetting {
        settingKey: "openaiApiKey"
        label: "OpenAI API Key"
        description: "Keys can be obtained from https://platform.openai.com/api-keys"
        placeholder: "Enter API key"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "ollamaUrl"
        label: "Ollama URL"
        description: "URL for your local Ollama instance (e.g. http://localhost:11434)"
        placeholder: "http://localhost:11434"
        defaultValue: "http://localhost:11434"
    }

    StringSetting {
        settingKey: "systemPrompt"
        label: "System Prompt"
        description: "Initial instruction given to the AI to define its behavior."
        placeholder: "You are a helpful assistant..."
        defaultValue: "You are a helpful assistant. Answer concisely. The chat client you are running in is small so keep answers brief." 
    }

    SelectionSetting {
        settingKey: "resizeCorner"
        label: "Resize Corner"
        description: "Choose which corner of the window should be used for resizing."
        options: [
            { "label": "Bottom Right", "value": "right" },
            { "label": "Bottom Left", "value": "left" }
        ]
        defaultValue: "right"
    }

    SliderSetting {
        settingKey: "maxMessageHistory"
        label: "Max Context History"
        description: "Limits the number of messages sent to the AI. Higher values provide better context but may slow down responses."
        defaultValue: 20
        minimum: 2
        maximum: 100
    }
}