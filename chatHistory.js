.pragma library

var masterHistory = []; 
var maxHistory = 20;
var persistChatHistory = false;
var pluginId = "";
var pluginService = null;

function setMaxHistory(max) {
    console.log("Setting max history to: " + max);
    maxHistory = max;
}

function setPersistChatHistory(enabled) {
    console.log("Setting persistChatHistory to: " + enabled);
    persistChatHistory = enabled;
    enabled ? saveChatHistory() : clearSavedChatHistory();
}

function clearSavedChatHistory() {
    if (!pluginService || !pluginId) {
        return;
    }
    console.log("Clearing saved chat history.");
    pluginService.savePluginData(pluginId, "chatHistory", null);
}

function clearChatHistory() {
    console.debug("Clearing in-memory chat history.");
    masterHistory = [];
    clearSavedChatHistory();
}

function pruneHistory() {
    if (masterHistory.length > maxHistory) {
         var first = masterHistory[0];
         var recent = masterHistory.slice(-(maxHistory - 1));
         masterHistory = [first].concat(recent);
         console.log("History pruned. New length: " + masterHistory.length);
    }
}

function saveChatHistory() {
    if (!persistChatHistory || !pluginService || !pluginId) {
        return;
    }
    console.log("Saving chat history. Length: " + masterHistory.length);
    var chatHistory = JSON.stringify(masterHistory);
    pluginService.savePluginData(pluginId, "chatHistory", chatHistory);
}

function loadChatHistory() {
    console.debug("Attempting to load chat history.");
    if (!persistChatHistory || !pluginService || !pluginId) {
        return [];
    }

    if (masterHistory.length > 0) {
        console.warn("Chat history already loaded, skipping reload.");
        return masterHistory;
    }

    var chatHistory = pluginService.loadPluginData(pluginId, "chatHistory");
    
    if (chatHistory) {
        try {
            masterHistory = JSON.parse(chatHistory);
            console.debug("Chat history loaded. Length: " + masterHistory.length);
        } catch (e) {
            console.error("Error parsing chat history: " + e);
            masterHistory = [];
        }
    }

    return masterHistory;
}

function setPluginId(id) {
    pluginId = id;
}

function setPluginService(service) {
    pluginService = service;
}

function addMessage(role, content, metadata) {
    masterHistory.push({ role: role, content: content, metadata: metadata || {} });
    pruneHistory();
    saveChatHistory();
}

function setHistory(history) {
    masterHistory = history;
}

function getHistory() {
    return masterHistory;
}
