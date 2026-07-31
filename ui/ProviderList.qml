import QtQuick
import qs.Common
import qs.Widgets
import "../providers/crypto.js" as Crypto

// Using duck typing for findSettings since we can't easily import QmlUtils from here
// Alternatively we could just walk the tree locally
Column {
    id: root
    width: parent.width
    spacing: Theme.spacingM
    
    property var providers: []
    property bool loaded: false
    
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
            providers = settings.loadValue("customProviders", []);
            
            // Migration logic
            var migrated = false;
            
            var gemini = settings.loadValue("geminiApiKey", "");
            if (gemini !== "") {
                providers.push({ type: "gemini", name: "Gemini", credential: Crypto.encodeKey(gemini), useGrounding: true });
                settings.saveValue("geminiApiKey", "");
                migrated = true;
            }
            var openai = settings.loadValue("openaiApiKey", "");
            if (openai !== "") {
                providers.push({ type: "openai", name: "OpenAI", credential: Crypto.encodeKey(openai) });
                settings.saveValue("openaiApiKey", "");
                migrated = true;
            }
            var anthropic = settings.loadValue("anthropicApiKey", "");
            if (anthropic !== "") {
                providers.push({ type: "anthropic", name: "Anthropic", credential: Crypto.encodeKey(anthropic) });
                settings.saveValue("anthropicApiKey", "");
                migrated = true;
            }
            var ollama = settings.loadValue("ollamaUrl", "");
            if (ollama !== "") {
                providers.push({ type: "ollama", name: "Ollama", credential: Crypto.encodeKey(ollama) });
                settings.saveValue("ollamaUrl", "");
                migrated = true;
            }
            var lmstudio = settings.loadValue("lmstudioUrl", "");
            if (lmstudio !== "") {
                providers.push({ type: "lmstudio", name: "LM Studio", credential: Crypto.encodeKey(lmstudio) });
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
        
        var newProv = {
            type: type,
            name: "New " + defaultName,
            credential: ""
        };
        
        if (type === "gemini") {
            newProv.useGrounding = false;
        }
        
        newProviders.push(newProv);
        providers = newProviders;
        saveProviders();
    }
    
    function updateProvider(index, key, value) {
        var newProviders = providers.slice();
        newProviders[index][key] = value;
        providers = newProviders;
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
            currentValue: parent.selectedType
            options: ["gemini", "openai", "anthropic", "ollama", "lmstudio"]
            onValueChanged: newValue => {
                parent.selectedType = newValue;
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
            model: root.providers
            
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                Row {
                    width: parent.width
                    
                    StyledText {
                        text: modelData.type.toUpperCase() + " CONFIGURATION"
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
                            root.removeProvider(index);
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
                
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    
                    property bool showKey: false
                    property bool isPassword: modelData.type !== "ollama" && modelData.type !== "lmstudio"
                    
                    DankTextField {
                        width: parent.width - (parent.isPassword ? btnReveal.width + Theme.spacingS : 0)
                        placeholderText: parent.isPassword ? "API Key" : "Base URL (e.g. http://localhost:11434)"
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
