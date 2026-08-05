import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Common
import "../providers/crypto.js" as Crypto

// Using duck typing for findSettings since we can't easily import QmlUtils from here
// Alternatively we could just walk the tree locally
Column {
    id: root
    width: parent.width
    spacing: Theme.spacingM
    
    property var providers: []
    property bool loaded: false
    
    ConfirmModal {
        id: confirmModal
    }
    
    function findSettings(item) {
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }
    
    Component.onCompleted: {
        // Wait a tiny bit for parent settings object to be ready
        Qt.callLater(loadValue);
    }
    
    function loadValue() {
        const settings = findSettings(root.parent);
        if (settings) {
            var rawProviders = settings.loadValue("customProviders", []);
            
            // Normalize old types to "openai" compatible and ensure IDs exist
            for (let i = 0; i < rawProviders.length; i++) {
                if (!rawProviders[i].id) {
                    rawProviders[i].id = "prov_" + Date.now() + "_" + Math.floor(Math.random() * 1000) + "_" + i;
                }
                if (rawProviders[i].type === "ollama") {
                    rawProviders[i].type = "openai";
                    if (!rawProviders[i].url) {
                        rawProviders[i].url = Crypto.decodeKey(rawProviders[i].credential);
                        rawProviders[i].credential = "";
                    }
                } else if (rawProviders[i].type === "lmstudio") {
                    rawProviders[i].type = "openai";
                    if (!rawProviders[i].url) {
                        rawProviders[i].url = Crypto.decodeKey(rawProviders[i].credential);
                        rawProviders[i].credential = "";
                    }
                } else if (rawProviders[i].type === "openai" && !rawProviders[i].url) {
                    rawProviders[i].url = "https://api.openai.com";
                }
            }
            providers = rawProviders;
            
            // Migration logic
            var migrated = false;
            
            var gemini = settings.loadValue("geminiApiKey", "");
            if (gemini !== "") {
                providers.push({ id: "legacy_gemini", type: "gemini", name: "Gemini", credential: Crypto.encodeKey(gemini), useGrounding: true });
                settings.saveValue("geminiApiKey", "");
                migrated = true;
            }
            var openai = settings.loadValue("openaiApiKey", "");
            if (openai !== "") {
                providers.push({ id: "legacy_openai", type: "openai", name: "OpenAI", url: "https://api.openai.com", credential: Crypto.encodeKey(openai) });
                settings.saveValue("openaiApiKey", "");
                migrated = true;
            }
            var anthropic = settings.loadValue("anthropicApiKey", "");
            if (anthropic !== "") {
                providers.push({ id: "legacy_anthropic", type: "anthropic", name: "Anthropic", credential: Crypto.encodeKey(anthropic) });
                settings.saveValue("anthropicApiKey", "");
                migrated = true;
            }
            var ollama = settings.loadValue("ollamaUrl", "");
            if (ollama !== "") {
                providers.push({ id: "legacy_ollama", type: "openai", name: "Ollama", url: ollama, credential: "" });
                settings.saveValue("ollamaUrl", "");
                migrated = true;
            }
            var lmstudio = settings.loadValue("lmstudioUrl", "");
            if (lmstudio !== "") {
                providers.push({ id: "legacy_lmstudio", type: "openai", name: "LM Studio", url: lmstudio, credential: "" });
                settings.saveValue("lmstudioUrl", "");
                migrated = true;
            }
            
            if (migrated) {
                settings.saveValue("customProviders", providers);
            }
            
            loaded = true;
        }
    }
    
    function saveProviders() {
        if (!loaded) return;
        const settings = findSettings(root.parent);
        if (settings) {
            settings.saveValue("customProviders", providers);
        }
    }
    
    function addProvider(type) {
        var newProviders = providers.slice();
        var defaultName = type.charAt(0).toUpperCase() + type.slice(1);
        if (type === "openai") defaultName = "OpenAI Compatible";
        
        var newProv = {
            id: "prov_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
            type: type,
            name: "New " + defaultName,
            credential: ""
        };
        
        if (type === "gemini") {
            newProv.useGrounding = false;
        } else if (type === "openai") {
            newProv.url = "https://api.openai.com";
        }
        
        newProviders.push(newProv);
        providers = newProviders;
        saveProviders();
        
        Qt.callLater(() => {
            if (providerRepeater.count > 0) {
                var newItem = providerRepeater.itemAt(providerRepeater.count - 1);
                const settings = findSettings(root.parent);
                if (settings && settings.ensureItemVisible && newItem) {
                    settings.ensureItemVisible(newItem);
                }
            }
        });
    }
    
    function updateProvider(index, key, value) {
        providers[index][key] = value;
        saveProviders();
    }
    
    function removeProvider(index) {
        var newProviders = providers.slice();
        newProviders.splice(index, 1);
        providers = newProviders;
        saveProviders();
    }

    StyledText {
        text: "AI Providers"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        text: "Add multiple instances of supported AI providers. Keys are encrypted to prevent casual snooping."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    // Add Provider Section
    Row {
        width: parent.width
        spacing: Theme.spacingS
        
        property string selectedType: "openai"

        DankDropdown {
            width: parent.width - btnAdd.width - Theme.spacingS
            text: "Provider Type"
            currentValue: {
                if (parent.selectedType === "gemini") return "Google Gemini";
                if (parent.selectedType === "anthropic") return "Anthropic Claude";
                return "OpenAI Compatible";
            }
            options: ["Google Gemini", "Anthropic Claude", "OpenAI Compatible"]
            onValueChanged: newValue => {
                if (newValue === "Google Gemini") parent.selectedType = "gemini";
                else if (newValue === "Anthropic Claude") parent.selectedType = "anthropic";
                else parent.selectedType = "openai";
            }
        }

        DankButton {
            id: btnAdd
            width: 150
            height: 36
            anchors.verticalCenter: parent.verticalCenter
            text: "Add Provider"
            onClicked: {
                root.addProvider(parent.selectedType);
            }
        }
    }
    
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // List of existing providers as editable forms
    Column {
        width: parent.width
        spacing: Theme.spacingL
        
        Repeater {
            id: providerRepeater
            model: root.providers
            
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                Row {
                    width: parent.width
                    
                    StyledText {
                        text: (modelData.type === "openai" ? "OPENAI COMPATIBLE" : modelData.type.toUpperCase()) + " CONFIGURATION"
                        color: Theme.primary
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        width: parent.width - removeBtn.width
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    DankActionButton {
                        id: removeBtn
                        iconName: "delete"
                        buttonSize: 32
                        iconSize: 18
                        iconColor: Theme.error
                        backgroundColor: "transparent"
                        
                        onClicked: {
                            confirmModal.showWithOptions({
                                title: "Remove Provider",
                                message: "Are you sure you want to remove the '" + modelData.name + "' provider configuration? This action cannot be undone.",
                                confirmText: "Remove",
                                confirmColor: Theme.error,
                                onConfirm: () => {
                                    root.removeProvider(index);
                                }
                            });
                        }
                    }
                }
                
                DankTextField {
                    width: parent.width
                    placeholderText: "Provider Display Name"
                    text: modelData.name
                    onTextChanged: {
                        if (root.loaded && text !== modelData.name) {
                            root.updateProvider(index, "name", text);
                        }
                    }
                }
                
                DankTextField {
                    width: parent.width
                    visible: modelData.type === "openai"
                    placeholderText: "Base URL (e.g. https://api.openai.com or http://localhost:11434)"
                    text: modelData.url || ""
                    onTextChanged: {
                        if (root.loaded && text !== (modelData.url || "")) {
                            root.updateProvider(index, "url", text);
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    
                    property bool showKey: false
                    property bool isPassword: true
                    
                    DankTextField {
                        width: parent.width - (parent.isPassword ? btnReveal.width + Theme.spacingS : 0)
                        placeholderText: "API Key (leave blank for local unenforced models)"
                        text: Crypto.decodeKey(modelData.credential)
                        echoMode: (!parent.isPassword || parent.showKey) ? TextInput.Normal : TextInput.Password
                        
                        onTextChanged: {
                            if (root.loaded) {
                                var decoded = Crypto.decodeKey(modelData.credential);
                                if (text !== decoded) {
                                    root.updateProvider(index, "credential", Crypto.encodeKey(text));
                                }
                            }
                        }
                    }
                    
                    DankActionButton {
                        id: btnReveal
                        iconName: parent.showKey ? "visibility_off" : "visibility"
                        visible: parent.isPassword
                        buttonSize: 36
                        iconSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                        
                        onClicked: {
                            parent.showKey = !parent.showKey;
                        }
                    }
                }
                
                DankTextField {
                    width: parent.width
                    placeholderText: "Model Filter (comma separated words, e.g. Flash, Latest, Lite)"
                    text: modelData.modelFilter || ""
                    onTextChanged: {
                        if (root.loaded && text !== (modelData.modelFilter || "")) {
                            root.updateProvider(index, "modelFilter", text);
                        }
                    }
                }
                
                // Ground with Search checkbox specifically for Gemini
                DankToggle {
                    width: parent.width
                    visible: modelData.type === "gemini"
                    text: "Ground with Google Search"
                    checked: modelData.useGrounding || false
                    onToggled: isChecked => {
                        if (root.loaded) {
                            root.updateProvider(index, "useGrounding", isChecked);
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.1
                    visible: index < root.providers.length - 1
                    anchors.topMargin: Theme.spacingM
                }
            }
        }
    }
}
