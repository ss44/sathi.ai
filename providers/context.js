.pragma library
.import "../chatHistory.js" as ChatHistory

// Smart context routing (issue #72): instead of sending the entire linear history,
// messages are grouped into summarized context buckets. Each user message negotiates
// with the main model over a compact manifest; the model either answers directly or
// requests buckets via a [[NEED_CONTEXT: ...]] marker and receives them in a second
// ephemeral turn. Negotiation legs are never persisted.

// Injected dependencies (avoids circular imports with providers.js):
// { sendRaw, calculateCost, getSystemPrompt, sendLegacy }
var deps = null;

var smartContextEnabled = false;
var fastModelRef = "";

// Engagement tuning
var minHistoryEngage = 6;      // masterHistory messages required before routing engages
var recentTailCount = 2;       // recent messages always included regardless of buckets
var bucketTailCount = 4;       // per-bucket recent messages shipped on leg 2
var summarizeMinMessages = 4;  // bucket size before summaries start
var summarizeNewThreshold = 2; // new messages required to re-summarize

var MARKER_RE = /\[\[NEED_CONTEXT:\s*([^\]]*?)\s*\]\]/;

var PROTOCOL_HEADER = "\n\n---\n" +
    "CONTEXT ROUTING PROTOCOL (internal instructions, never mention buckets or markers to the user):\n" +
    "Older conversations are stored in labeled context buckets listed in the manifest below.\n" +
    "- If you can answer the user's message well without older context, answer normally and end your response with: [[NEED_CONTEXT: none]]\n" +
    "- If context from specific buckets would improve your answer, END your response with exactly: [[NEED_CONTEXT: b1, b2]]\n" +
    "  listing the bucket ids you need (comma separated). The requested buckets will be provided and you will answer in the next turn.\n" +
    "- If this starts a new topic unrelated to the manifest, answer normally and end with: [[NEED_CONTEXT: new]]\n" +
    "The marker MUST be the last thing in your response and must appear exactly once.\n\n" +
    "CONTEXT MANIFEST:\n";

var FETCHED_HEADER = "\n\n---\n" +
    "The following context buckets were fetched based on your request. Use them if relevant.\n" +
    "Answer the user's message now. Do not output any marker again.\n\n";

var SUMMARIZER_SYSTEM = "You compress conversation segments into ultra-short context summaries used for routing. " +
    "Output only the summary, maximum 25 words, no quotes, no preamble.";

function init(dependencies) {
    deps = dependencies;
}

function setEnabled(enabled) {
    console.info("[Context] Smart context " + (enabled ? "enabled" : "disabled"));
    smartContextEnabled = enabled === true;
}

function isEnabled() {
    return smartContextEnabled;
}

function setFastModel(modelRef) {
    fastModelRef = modelRef || "";
    console.info("[Context] Fast model set to: " + (fastModelRef || "<main model>"));
}

function getFastModel() {
    return fastModelRef;
}

function shouldEngage() {
    return smartContextEnabled &&
           ChatHistory.getBlocks().length > 0 &&
           ChatHistory.getHistory().length >= minHistoryEngage;
}

function maybeSummarize(blockId) {
    var block = ChatHistory.findBlock(blockId);
    if (!block) {
        return;
    }
    var count = block.messageIds.length;
    if (count < summarizeMinMessages || count - block.lastSummaryCount < summarizeNewThreshold) {
        return;
    }
    summarizeBlock(blockId);
}

// Fire-and-forget background summarization of a context block using the fast model.
function summarizeBlock(blockId) {
    var block = ChatHistory.findBlock(blockId);
    if (!block || !deps || !deps.sendRaw) {
        return;
    }
    var transcript = [];
    var start = Math.max(0, block.messageIds.length - 12);
    for (var i = start; i < block.messageIds.length; i++) {
        var msg = ChatHistory.getMessage(block.messageIds[i]);
        if (msg) {
            var content = msg.content;
            if (content.length > 500) {
                content = content.substring(0, 500) + "…";
            }
            transcript.push((msg.role === "model" ? "assistant" : "user") + ": " + content);
        }
    }
    if (transcript.length === 0) {
        return;
    }

    var messages = [
        { role: "system", content: SUMMARIZER_SYSTEM },
        { role: "user", content: transcript.join("\n") }
    ];

    console.info("[Context] Summarizing block " + blockId + " (" + block.messageIds.length + " msgs)");
    deps.sendRaw(messages, fastModelRef || null, function(response, error) {
        if (error || !response) {
            if (error) {
                console.warn("[Context] Summarizer failed for " + blockId + ": " + error);
            }
            return;
        }
        var summary = String(response).trim().replace(/^["']+|["']+$/g, "").substring(0, 160);
        if (summary) {
            ChatHistory.updateBlockSummary(blockId, summary, block.messageIds.length);
            console.info("[Context] Block " + blockId + " summary updated: " + summary);
        }
    });
}

function buildManifest() {
    var blocks = ChatHistory.getBlocks();
    var lines = [];
    for (var i = 0; i < blocks.length; i++) {
        var b = blocks[i];
        var count = b.messageIds.length;
        var summary = b.summary || "(no summary yet)";
        lines.push("[" + b.id + "] (" + count + (count === 0 ? " earlier, summary only" : " msgs") + ") " + summary);
    }
    return lines.join("\n");
}

function buildBucketContent(block) {
    var parts = ["[" + block.id + "] " + (block.summary || "(no summary yet)")];
    var start = Math.max(0, block.messageIds.length - bucketTailCount);
    for (var i = start; i < block.messageIds.length; i++) {
        var msg = ChatHistory.getMessage(block.messageIds[i]);
        if (msg) {
            parts.push((msg.role === "model" ? "assistant" : "user") + ": " + msg.content);
        }
    }
    return parts.join("\n");
}

function stripMarkers(text) {
    return text.replace(/\s*\[\[NEED_CONTEXT:[^\]]*\]\]/g, "").trim();
}

function parseMarkerIds(markerValue) {
    var raw = markerValue.toLowerCase();
    var ids = raw.split(/[\s,]+/);
    var clean = [];
    for (var i = 0; i < ids.length; i++) {
        var id = ids[i].trim();
        if (id === "new") {
            clean.push("new");
        } else if (id !== "" && id !== "none") {
            clean.push(id);
        }
    }
    return clean;
}

function parseLeg1(text) {
    var match = MARKER_RE.exec(text);
    if (!match) {
        return { type: "answer", text: stripMarkers(text) };
    }
    var requested = parseMarkerIds(match[1]);
    var resolvable = [];
    for (var i = 0; i < requested.length; i++) {
        if (requested[i] !== "new" && ChatHistory.findBlock(requested[i])) {
            resolvable.push(requested[i]);
        }
    }
    if (resolvable.length === 0) {
        // "new" or unresolvable/none: no fetch needed, answer stands.
        return { type: "answer", text: stripMarkers(text), requestedNew: requested.indexOf("new") !== -1 };
    }
    return { type: "need", ids: resolvable, text: stripMarkers(text) };
}

function legMessages(systemContent, tail, userText) {
    var messages = [{ role: "system", content: systemContent }];
    var history = ChatHistory.getHistory();
    var start = Math.max(0, history.length - tail);
    for (var i = start; i < history.length; i++) {
        messages.push({ role: history[i].role, content: history[i].content });
    }
    messages.push({ role: "user", content: userText });
    return messages;
}

function orchestrate(text, callback) {
    var aborted = false;
    var activeReq = null;

    var handle = {
        abort: function() {
            aborted = true;
            var req = activeReq;
            activeReq = null;
            if (req && typeof req.abort === "function") {
                try {
                    req.abort();
                } catch (e) {
                    console.error("[Context] Error aborting request: " + e);
                }
            }
        }
    };

    var acc = { promptTokens: 0, completionTokens: 0, totalTokens: 0, cost: 0 };

    function absorbMeta(meta, legModelName) {
        if (!meta) {
            return;
        }
        acc.promptTokens += meta.promptTokens || 0;
        acc.completionTokens += meta.completionTokens || 0;
        acc.totalTokens += meta.totalTokens || 0;
        if (deps && deps.calculateCost) {
            acc.cost += deps.calculateCost(legModelName || "", meta.promptTokens, meta.completionTokens);
        }
    }

    function mergedMetadata(routing) {
        var meta = {
            promptTokens: acc.promptTokens,
            completionTokens: acc.completionTokens,
            totalTokens: acc.totalTokens,
            smartContext: true,
            routing: routing || []
        };
        if (acc.cost > 0) {
            meta.estimatedCost = acc.cost;
        }
        return meta;
    }

    function sendRawSafe(messages, modelRef, cb) {
        var legModel = modelRef || (deps && deps.getMainModelName ? deps.getMainModelName() : "");
        console.info("[Context] Leg request via " + (modelRef || "main model"));
        activeReq = deps.sendRaw(messages, modelRef, function(response, error, meta) {
            activeReq = null;
            absorbMeta(meta, legModel);
            cb(response, error);
        });
    }

    function fallback(reason) {
        console.warn("[Context] Falling back to legacy history send. Reason: " + reason);
        if (!deps || !deps.sendLegacy) {
            callback(null, "Smart context routing failed");
            return;
        }
        activeReq = deps.sendLegacy(text, function(response, error, metadata) {
            activeReq = null;
            if (!aborted) {
                if (response && metadata) {
                    metadata.smartContext = true;
                    metadata.routing = ["fallback"];
                }
                callback(response, error, metadata);
            }
        });
    }

    function finish(answer, routing, forceNew) {
        var meta = mergedMetadata(routing.length > 0 ? routing : ["direct"]);
        var userMsg = ChatHistory.addMessage("user", text);
        var modelMsg = ChatHistory.addMessage("model", answer, meta);
        assignExchange(userMsg, modelMsg, routing, forceNew);
        callback(answer, null, meta);
    }

    function assignExchange(userMsg, modelMsg, routing, forceNew) {
        var blockId = null;
        if (routing.length > 0 && ChatHistory.findBlock(routing[0])) {
            blockId = routing[0];
        } else if (!forceNew) {
            var last = ChatHistory.lastUsedBlock();
            blockId = last ? last.id : null;
        }
        if (!blockId) {
            var summary = userMsg.content.substring(0, 80);
            blockId = ChatHistory.createBlock(summary).id;
            console.info("[Context] Created new context block " + blockId);
        }
        ChatHistory.assignMessages(blockId, [userMsg.id, modelMsg.id]);
        console.info("[Context] Exchange assigned to block " + blockId);
        maybeSummarize(blockId);
    }

    function leg2(routing) {
        if (aborted) {
            return;
        }
        var sections = [];
        for (var i = 0; i < routing.length; i++) {
            var block = ChatHistory.findBlock(routing[i]);
            if (block) {
                sections.push(buildBucketContent(block));
            }
        }
        var systemContent = (deps.getSystemPrompt ? deps.getSystemPrompt() : "") + FETCHED_HEADER + sections.join("\n\n");
        var messages = [{ role: "system", content: systemContent }, { role: "user", content: text }];

        sendRawSafe(messages, null, function(response, error) {
            if (aborted) {
                return;
            }
            if (error || !response) {
                fallback(error || "Empty leg 2 response");
                return;
            }
            // One round max: any second marker is ignored.
            finish(stripMarkers(String(response)), routing);
        });
    }

    function leg1() {
        if (aborted) {
            return;
        }
        var systemContent = (deps.getSystemPrompt ? deps.getSystemPrompt() : "") + PROTOCOL_HEADER + buildManifest();
        var messages = legMessages(systemContent, recentTailCount, text);

        sendRawSafe(messages, null, function(response, error) {
            if (aborted) {
                return;
            }
            if (error || !response) {
                fallback(error || "Empty leg 1 response");
                return;
            }
            var parsed = parseLeg1(String(response));
            console.info("[Context] Leg 1 result: " + parsed.type + (parsed.ids ? " -> " + parsed.ids.join(",") : ""));
            if (parsed.type === "need") {
                leg2(parsed.ids);
            } else {
                finish(parsed.text, [], parsed.requestedNew === true);
            }
        });
    }

    if (!deps || !deps.sendRaw) {
        fallback("Smart context not initialized");
        return handle;
    }

    leg1();
    return handle;
}