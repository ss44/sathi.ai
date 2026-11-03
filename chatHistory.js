.pragma library

var masterHistory = [];
var maxHistory = 20;
var persistChatHistory = false;
var pluginId = "";
var pluginService = null;

// Context buckets: parallel index over masterHistory used by smart context routing.
// Each block references messages by stable id so pruning never invalidates them.
var contextBlocks = [];
var lastUsedBlockId = null;

var messageIdSeq = 0;
var blockIdSeq = 0;

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
    contextBlocks = [];
    lastUsedBlockId = null;
    clearSavedChatHistory();
}

function pruneHistory() {
    if (masterHistory.length > maxHistory) {
         var first = masterHistory[0];
         var recent = masterHistory.slice(-(maxHistory - 1));
         masterHistory = [first].concat(recent);
         pruneBlocks();
         console.log("History pruned. New length: " + masterHistory.length);
    }
}

function saveChatHistory() {
    if (!persistChatHistory || !pluginService || !pluginId) {
        return;
    }
    console.log("Saving chat history. Length: " + masterHistory.length + ", blocks: " + contextBlocks.length);
    var payload = JSON.stringify({
        v: 2,
        history: masterHistory,
        blocks: contextBlocks,
        lastUsedBlockId: lastUsedBlockId
    });
    pluginService.savePluginData(pluginId, "chatHistory", payload);
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
            var parsed = JSON.parse(chatHistory);
            if (Array.isArray(parsed)) {
                // Legacy v1 format: plain array of messages, no blocks.
                console.debug("Legacy chat history format detected, migrating.");
                masterHistory = parsed;
                contextBlocks = [];
                lastUsedBlockId = null;
            } else if (parsed && Array.isArray(parsed.history)) {
                masterHistory = parsed.history;
                contextBlocks = Array.isArray(parsed.blocks) ? parsed.blocks : [];
                lastUsedBlockId = parsed.lastUsedBlockId || null;
            } else {
                masterHistory = [];
                contextBlocks = [];
            }
            sanitizeHistory();
            console.debug("Chat history loaded. Length: " + masterHistory.length + ", blocks: " + contextBlocks.length);
        } catch (e) {
            console.error("Error parsing chat history: " + e);
            masterHistory = [];
            contextBlocks = [];
        }
    }

    return masterHistory;
}

function sanitizeHistory() {
    var byId = {};
    for (var i = 0; i < masterHistory.length; i++) {
        var msg = masterHistory[i];
        if (!msg) {
            masterHistory.splice(i, 1);
            i--;
            continue;
        }
        if (!msg.id) {
            msg.id = generateMessageId();
        }
        byId[msg.id] = msg;
    }

    // Drop block references to messages that no longer exist (pruned or corrupt data).
    // Blocks keep their summary so they remain usable as summary-only context.
    for (var b = 0; b < contextBlocks.length; b++) {
        var block = contextBlocks[b];
        if (!block || !block.id) {
            contextBlocks.splice(b, 1);
            b--;
            continue;
        }
        var kept = [];
        var ids = Array.isArray(block.messageIds) ? block.messageIds : [];
        for (var m = 0; m < ids.length; m++) {
            if (byId[ids[m]]) {
                kept.push(ids[m]);
            }
        }
        block.messageIds = kept;
        if (!block.summary) {
            block.summary = "";
        }
        if (typeof block.lastSummaryCount !== "number") {
            block.lastSummaryCount = 0;
        }
    }

    if (lastUsedBlockId && !findBlock(lastUsedBlockId)) {
        lastUsedBlockId = null;
    }
}

function generateMessageId() {
    messageIdSeq++;
    return "m" + Date.now().toString(36) + "-" + messageIdSeq.toString(36);
}

function generateBlockId() {
    blockIdSeq++;
    return "b" + Date.now().toString(36) + "-" + blockIdSeq.toString(36);
}

function addMessage(role, content, metadata) {
    var msg = { id: generateMessageId(), role: role, content: content, metadata: metadata || {} };
    masterHistory.push(msg);
    pruneHistory();
    saveChatHistory();
    return msg;
}

function setHistory(history) {
    masterHistory = history;
    // History resets come from system prompt changes; buckets are no longer valid.
    contextBlocks = [];
    lastUsedBlockId = null;
}

function getHistory() {
    return masterHistory;
}

function getBlocks() {
    return contextBlocks;
}

function findBlock(blockId) {
    for (var i = 0; i < contextBlocks.length; i++) {
        if (contextBlocks[i].id === blockId) {
            return contextBlocks[i];
        }
    }
    return null;
}

function getMessage(messageId) {
    for (var i = 0; i < masterHistory.length; i++) {
        if (masterHistory[i].id === messageId) {
            return masterHistory[i];
        }
    }
    return null;
}

function createBlock(summary) {
    var block = {
        id: generateBlockId(),
        summary: summary || "",
        messageIds: [],
        lastSummaryCount: 0
    };
    contextBlocks.push(block);
    saveChatHistory();
    return block;
}

function assignMessages(blockId, messageIds) {
    var block = findBlock(blockId);
    if (!block) {
        console.warn("Cannot assign messages to unknown block: " + blockId);
        return null;
    }
    for (var i = 0; i < messageIds.length; i++) {
        if (block.messageIds.indexOf(messageIds[i]) === -1) {
            block.messageIds.push(messageIds[i]);
        }
    }
    lastUsedBlockId = blockId;
    saveChatHistory();
    return block;
}

function updateBlockSummary(blockId, summary, summarizedCount) {
    var block = findBlock(blockId);
    if (!block) {
        return null;
    }
    block.summary = summary;
    block.lastSummaryCount = typeof summarizedCount === "number" ? summarizedCount : block.messageIds.length;
    saveChatHistory();
    return block;
}

function lastUsedBlock() {
    return lastUsedBlockId ? findBlock(lastUsedBlockId) : null;
}

function pruneBlocks() {
    var byId = {};
    for (var i = 0; i < masterHistory.length; i++) {
        byId[masterHistory[i].id] = true;
    }
    for (var b = 0; b < contextBlocks.length; b++) {
        var block = contextBlocks[b];
        var kept = [];
        var ids = Array.isArray(block.messageIds) ? block.messageIds : [];
        for (var m = 0; m < ids.length; m++) {
            if (byId[ids[m]]) {
                kept.push(ids[m]);
            }
        }
        block.messageIds = kept;
    }
}

function setPluginId(id) {
    pluginId = id;
}

function setPluginService(service) {
    pluginService = service;
}