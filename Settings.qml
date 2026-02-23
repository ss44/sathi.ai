import QtQuick
import QtQuick.Controls
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
        settingKey: "anthropicApiKey"
        label: "Anthropic API Key"
        description: "Keys can be obtained from https://platform.claude.com/settings/keys"
        placeholder: "Enter API key"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "ollamaUrl"
        label: "Ollama URL"
        description: "URL for your local Ollama instance (e.g. http://localhost:11434)"
        placeholder: "http://localhost:11434"
        defaultValue: ""
    }

    // --- OpenAI-Compatible Providers Section ---
    // Stores config as JSON via the StringSetting below. The custom UI provides a friendly
    // dropdown interface for adding/removing providers without editing JSON directly.
    Item {
        id: openaiProviderSection
        width: parent.width
        height: openaiSectionCol.height

        property var presets: [
            { id: "openai",     name: "OpenAI",      url: "https://api.openai.com/v1",     needsUrl: false, needsApiKey: true },
            { id: "groq",       name: "Groq",        url: "https://api.groq.com/openai/v1", needsUrl: false, needsApiKey: true },
            { id: "openrouter", name: "OpenRouter",   url: "https://openrouter.ai/api/v1",  needsUrl: false, needsApiKey: true },
            { id: "lmstudio",   name: "LM Studio",   url: "http://localhost:1234/v1",       needsUrl: true,  needsApiKey: false },
            { id: "modal",      name: "Modal",        url: "",                                needsUrl: true,  needsApiKey: true },
            { id: "other",      name: "Other",        url: "",                                needsUrl: true,  needsApiKey: true }
        ]

        property var presetNames: {
            var names = [];
            for (var i = 0; i < presets.length; i++) names.push(presets[i].name);
            return names;
        }

        ListModel { id: providerListModel }

        Timer {
            interval: 200
            running: true
            repeat: false
            onTriggered: openaiProviderSection.loadFromSetting()
        }

        function loadFromSetting() {
            providerListModel.clear();
            var json = openaiProvidersData.currentValue || openaiProvidersData.defaultValue || "[]";
            try {
                var arr = JSON.parse(json);
                for (var i = 0; i < arr.length; i++) {
                    // Restore needsUrl/needsApiKey from preset
                    var entry = arr[i];
                    var preset = findPreset(entry.id);
                    entry.needsUrl = preset ? preset.needsUrl : true;
                    entry.needsApiKey = preset ? preset.needsApiKey : true;
                    providerListModel.append(entry);
                }
            } catch (e) {
                console.error("Failed to parse openaiProviders:", e);
            }
        }

        function saveToSetting() {
            var arr = [];
            for (var i = 0; i < providerListModel.count; i++) {
                var item = providerListModel.get(i);
                var entry = { id: item.id };
                if (item.apiKey) entry.apiKey = item.apiKey;
                if (item.url) entry.url = item.url;
                if (item.name) entry.name = item.name;
                arr.push(entry);
            }
            openaiProvidersData.currentValue = JSON.stringify(arr);
        }

        function findPreset(id) {
            for (var i = 0; i < presets.length; i++) {
                if (presets[i].id === id) return presets[i];
            }
            return null;
        }

        function isProviderAdded(id) {
            for (var i = 0; i < providerListModel.count; i++) {
                if (providerListModel.get(i).id === id) return true;
            }
            return false;
        }

        function addProvider(presetIndex) {
            var preset = presets[presetIndex];
            if (!preset) return;

            var providerId = preset.id;
            if (providerId === "other") {
                providerId = "custom_" + Date.now() + "_" + Math.floor(Math.random() * 1000);
            } else if (isProviderAdded(providerId)) {
                return;
            }

            providerListModel.append({
                id: providerId,
                name: preset.name === "Other" ? "Custom" : preset.name,
                url: preset.url,
                apiKey: "",
                needsUrl: preset.needsUrl,
                needsApiKey: preset.needsApiKey
            });
            saveToSetting();
        }

        function removeProvider(index) {
            providerListModel.remove(index);
            saveToSetting();
        }

        Column {
            id: openaiSectionCol
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                text: "OpenAI-Compatible Providers"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
                width: parent.width
            }

            StyledText {
                text: "Add cloud or local providers that use the OpenAI API format (e.g. Groq, OpenRouter, LM Studio)."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                opacity: 0.7
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS
                height: 40

                ComboBox {
                    id: addProviderCombo
                    width: parent.width * 0.65
                    height: 40
                    model: openaiProviderSection.presetNames
                    displayText: "Select a provider..."
                    currentIndex: -1

                    background: Rectangle {
                        color: Theme.surfaceContainerHigh
                        radius: Theme.cornerRadius
                        border.color: addProviderCombo.popup.visible ? Theme.primary : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: addProviderCombo.displayText
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Theme.spacingM
                    }

                    delegate: ItemDelegate {
                        width: ListView.view ? ListView.view.width : 100
                        contentItem: Text {
                            text: modelData
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                        }
                        highlighted: addProviderCombo.highlightedIndex === index
                        background: Rectangle {
                            color: parent.highlighted ? Theme.surfaceContainerHigh : "transparent"
                            radius: Theme.cornerRadius
                        }
                    }

                    popup: Popup {
                        y: addProviderCombo.height + Theme.spacingXS
                        width: addProviderCombo.width
                        padding: 4

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: addProviderCombo.popup.visible ? addProviderCombo.delegateModel : null
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            color: Theme.surfaceContainer
                            border.color: Theme.primary
                            border.width: 1
                            radius: Theme.cornerRadius
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.3
                    height: 40
                    radius: Theme.cornerRadius
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "Add"
                        color: Theme.onPrimary
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (addProviderCombo.currentIndex >= 0) {
                                openaiProviderSection.addProvider(addProviderCombo.currentIndex);
                                addProviderCombo.currentIndex = -1;
                                addProviderCombo.displayText = "Select a provider...";
                            }
                        }
                    }
                }
            }

            Repeater {
                model: providerListModel

                delegate: Rectangle {
                    width: openaiSectionCol.width
                    height: providerRowCol.height + Theme.spacingM
                    color: Theme.surfaceContainerHigh
                    radius: Theme.cornerRadius

                    Column {
                        id: providerRowCol
                        width: parent.width - Theme.spacingM * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Text {
                                text: model.name || model.id
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                                width: parent.width - removeBtnRect.width - Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                id: removeBtnRect
                                width: 24
                                height: 24
                                radius: 12
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: Theme.error
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: openaiProviderSection.removeProvider(index)
                                }
                            }
                        }

                        TextField {
                            visible: model.needsUrl
                            width: parent.width
                            height: 36
                            placeholderText: "Endpoint URL (e.g. http://localhost:1234/v1)"
                            text: model.url || ""
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall

                            background: Rectangle {
                                color: Theme.surfaceContainer
                                radius: Theme.cornerRadius
                                border.color: parent.activeFocus ? Theme.primary : "transparent"
                                border.width: 1
                            }

                            onEditingFinished: {
                                providerListModel.setProperty(index, "url", text);
                                openaiProviderSection.saveToSetting();
                            }
                        }

                        TextField {
                            visible: model.needsApiKey
                            width: parent.width
                            height: 36
                            placeholderText: "API Key"
                            text: model.apiKey || ""
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            echoMode: TextInput.Password

                            background: Rectangle {
                                color: Theme.surfaceContainer
                                radius: Theme.cornerRadius
                                border.color: parent.activeFocus ? Theme.primary : "transparent"
                                border.width: 1
                            }

                            onEditingFinished: {
                                providerListModel.setProperty(index, "apiKey", text);
                                openaiProviderSection.saveToSetting();
                            }
                        }
                    }
                }
            }
        }
    }

    // Hidden backing store for the OpenAI-compatible providers JSON
    StringSetting {
        id: openaiProvidersData
        settingKey: "openaiProviders"
        label: "OpenAI Providers (JSON)"
        description: "Managed by the section above. Edit directly only if needed."
        placeholder: "[]"
        defaultValue: "[]"
        visible: false
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

    ToggleSetting {
        settingKey: "persistChatHistory"
        label: "Persist Chat History across Sessions"
        description: "Enable or disable persistence of chat history across sessions."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showMessageAlerts"
        label: "Show Message Alerts"
        description: "Enable or disable message alerts when the chat popout is hidden."
        defaultValue: false
    }
}