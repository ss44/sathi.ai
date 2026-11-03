import QtTest

import "../chatHistory.js" as ChatHistory
import "../providers/context.js" as Context

TestCase {
    id: root
    name: "SmartContext"

    property var saved: ({
        sendRawCalls: [],
        legacyCalls: [],
        script: [],
        pending: null,
        savedData: {}
    })

    function mockPluginService() {
        return {
            savePluginData: function(pluginId, key, value) {
                if (value === null) {
                    delete saved.savedData[key];
                } else {
                    saved.savedData[key] = value;
                }
            },
            loadPluginData: function(pluginId, key) {
                return saved.savedData[key] || null;
            }
        };
    }

    function mockSendRaw(messages, modelRef, cb) {
        saved.sendRawCalls.push({ messages: messages, modelRef: modelRef });
        var step = saved.script.length > 0 ? saved.script.shift() : { response: "ok" };
        if (step.defer) {
            saved.pending = function() { cb(step.response, step.error, step.meta); };
            return null;
        }
        cb(step.response, step.error, step.meta);
        return null;
    }

    function mockLegacy(text, cb) {
        saved.legacyCalls.push(text);
        ChatHistory.addMessage("user", text);
        ChatHistory.addMessage("model", "legacy-answer");
        cb("legacy-answer", null, { promptTokens: 10, completionTokens: 4, totalTokens: 14 });
        return null;
    }

    function init() {
        ChatHistory.clearChatHistory();
        ChatHistory.setMaxHistory(20);
        ChatHistory.setPluginId("");
        ChatHistory.setPluginService(null);
        Context.init({
            sendRaw: mockSendRaw,
            calculateCost: function(name, p, c) { return 0.001; },
            getSystemPrompt: function() { return "SYS"; },
            getMainModelName: function() { return "test-main"; },
            sendLegacy: mockLegacy
        });
        Context.setFastModel("fast|model");
        Context.setEnabled(false);
        saved.sendRawCalls = [];
        saved.legacyCalls = [];
        saved.script = [];
        saved.pending = null;
        saved.savedData = {};
    }

    function seedRoutingState() {
        for (var i = 0; i < 6; i++) {
            ChatHistory.addMessage(i % 2 === 0 ? "user" : "model", "msg" + i);
        }
        var block = ChatHistory.createBlock("seed topic");
        var history = ChatHistory.getHistory();
        ChatHistory.assignMessages(block.id, [history[0].id, history[1].id]);
        Context.setEnabled(true);
        return block;
    }

    // ---------- chatHistory.js ----------

    function test_add_message_returns_stable_ids() {
        var a = ChatHistory.addMessage("user", "one");
        var b = ChatHistory.addMessage("model", "two");
        verify(a.id, "message id assigned");
        verify(b.id, "message id assigned");
        verify(a.id !== b.id, "ids unique");
        compare(ChatHistory.getMessage(a.id).content, "one");
    }

function test_legacy_history_migrates_with_backfilled_ids() {
        ChatHistory.setPluginId("test");
        ChatHistory.setPluginService(mockPluginService());
        ChatHistory.setPersistChatHistory(true);
        saved.savedData["chatHistory"] = JSON.stringify([
            { role: "user", content: "old question" },
            { role: "model", content: "old answer" }
        ]);
        var history = ChatHistory.loadChatHistory();
        compare(history.length, 2);
        verify(history[0].id, "legacy messages get ids");
        compare(ChatHistory.getBlocks().length, 0);
    }

    function test_v2_round_trip_persists_blocks() {
        ChatHistory.setPluginId("test");
        ChatHistory.setPluginService(mockPluginService());
        ChatHistory.setPersistChatHistory(true);
        var a = ChatHistory.addMessage("user", "question");
        var b = ChatHistory.addMessage("model", "answer");
        var block = ChatHistory.createBlock("topic one");
        ChatHistory.assignMessages(block.id, [a.id, b.id]);

        var payloadStr = saved.savedData["chatHistory"];
        verify(payloadStr, "payload saved");
        var payload = JSON.parse(payloadStr);
        compare(payload.v, 2);
        compare(payload.history.length, 2);
        compare(payload.blocks.length, 1);

        // Simulate reload from scratch: clear in-memory state, restore persisted store
        ChatHistory.clearChatHistory();
        saved.savedData["chatHistory"] = payloadStr;
        var history = ChatHistory.loadChatHistory();
        compare(history.length, 2);
        compare(ChatHistory.getBlocks().length, 1);
        var restored = ChatHistory.getBlocks()[0];
        compare(restored.summary, "topic one");
        compare(restored.messageIds.length, 2);
        verify(ChatHistory.lastUsedBlock() !== null, "lastUsedBlockId restored");
    }

function test_load_drops_dangling_block_refs_but_keeps_summary() {
        ChatHistory.setPluginId("test");
        ChatHistory.setPluginService(mockPluginService());
        ChatHistory.setPersistChatHistory(true);
        saved.savedData["chatHistory"] = JSON.stringify({
            v: 2,
            history: [{ id: "m1", role: "user", content: "a" }],
            blocks: [
                { id: "b1", summary: "keep me", messageIds: ["m1", "ghost"], lastSummaryCount: 2 },
                { id: "b2", summary: "", messageIds: [] }
            ]
        });
        ChatHistory.loadChatHistory();
        var blocks = ChatHistory.getBlocks();
        compare(blocks.length, 2);
        compare(blocks[0].messageIds.length, 1);
        compare(blocks[0].messageIds[0], "m1");
        compare(blocks[0].summary, "keep me");
    }

function test_load_corrupt_payload_falls_back_to_empty() {
        ChatHistory.setPluginId("test");
        ChatHistory.setPluginService(mockPluginService());
        ChatHistory.setPersistChatHistory(true);
        saved.savedData["chatHistory"] = "not json at all {";
        var history = ChatHistory.loadChatHistory();
        compare(history.length, 0);
        compare(ChatHistory.getBlocks().length, 0);
    }

    function test_prune_evicts_dead_block_refs_keeps_summary_block() {
        ChatHistory.setMaxHistory(4);
        for (var i = 0; i < 3; i++) {
            ChatHistory.addMessage(i % 2 === 0 ? "user" : "model", "msg" + i);
        }
        var doomed = ChatHistory.getHistory()[1].id;
        var block = ChatHistory.createBlock("evicted topic");
        ChatHistory.assignMessages(block.id, [doomed]);

        // Push past the 4-message window; m1 gets evicted, block refs must drop
        for (var j = 3; j < 6; j++) {
            ChatHistory.addMessage(j % 2 === 0 ? "user" : "model", "msg" + j);
        }
        compare(ChatHistory.getHistory().length, 4);
        compare(block.messageIds.length, 0);
        compare(block.summary, "evicted topic");
        verify(ChatHistory.findBlock(block.id) !== null, "summary-only block survives pruning");
    }

    function test_set_history_resets_blocks() {
        ChatHistory.addMessage("user", "a");
        ChatHistory.createBlock("topic");
        ChatHistory.setHistory([]);
        compare(ChatHistory.getBlocks().length, 0);
    }

    function test_clear_chat_history_resets_blocks() {
        ChatHistory.addMessage("user", "a");
        ChatHistory.createBlock("topic");
        ChatHistory.clearChatHistory();
        compare(ChatHistory.getBlocks().length, 0);
        compare(ChatHistory.lastUsedBlock(), null);
    }

    // ---------- context.js: parsing ----------

    function test_parse_leg1_plain_answer() {
        var parsed = Context.parseLeg1("Here is your answer.");
        compare(parsed.type, "answer");
        compare(parsed.text, "Here is your answer.");
    }

    function test_parse_leg1_marker_with_ids() {
        var b1 = ChatHistory.createBlock("topic a").id;
        var b2 = ChatHistory.createBlock("topic b").id;
        var parsed = Context.parseLeg1("Hmm [[NEED_CONTEXT: " + b1 + ", " + b2 + "]]");
        compare(parsed.type, "need");
        compare(parsed.ids.length, 2);
        compare(parsed.ids[0], b1);
    }

    function test_parse_leg1_new_topic() {
        var parsed = Context.parseLeg1("Fresh answer [[NEED_CONTEXT: new]]");
        compare(parsed.type, "answer");
        compare(parsed.requestedNew, true);
        compare(parsed.text, "Fresh answer");
    }

    function test_parse_leg1_none_means_direct_answer() {
        var parsed = Context.parseLeg1("Direct answer [[NEED_CONTEXT: none]]");
        compare(parsed.type, "answer");
        compare(parsed.requestedNew, false);
        compare(parsed.text, "Direct answer");
    }

    function test_parse_leg1_unknown_ids_resolved_away() {
        var parsed = Context.parseLeg1("Answer [[NEED_CONTEXT: b404, b405]]");
        compare(parsed.type, "answer");
        compare(parsed.requestedNew, false);
    }

    function test_parse_leg1_strips_mid_text_markers() {
        var parsed = Context.parseLeg1("Part [[NEED_CONTEXT: none]] of the answer");
        compare(parsed.text, "Part of the answer");
    }

    // ---------- context.js: manifest ----------

    function test_build_manifest_lists_ids_and_summaries() {
        ChatHistory.createBlock("first topic");
        ChatHistory.createBlock("second topic");
        var manifest = Context.buildManifest();
        verify(manifest.indexOf("[b") !== -1, "contains block id");
        verify(manifest.indexOf("first topic") !== -1);
        verify(manifest.indexOf("second topic") !== -1);
    }

    // ---------- context.js: engagement ----------

    function test_should_engage_requires_blocks_and_history() {
        Context.setEnabled(false);
        verify(!Context.shouldEngage(), "disabled");
        Context.setEnabled(true);
        verify(!Context.shouldEngage(), "no blocks");
        ChatHistory.createBlock("topic");
        verify(!Context.shouldEngage(), "history too short");
        for (var i = 0; i < 6; i++) {
            ChatHistory.addMessage("user", "filler" + i);
        }
        verify(Context.shouldEngage(), "engaged with blocks + history");
    }

    // ---------- context.js: orchestration ----------

    function test_orchestrate_direct_answer_sticks_to_last_block() {
        var seed = seedRoutingState();
        saved.script = [{ response: "Hi there [[NEED_CONTEXT: none]]", meta: { promptTokens: 5, completionTokens: 2, totalTokens: 7 } }];
        var result = { called: false };
        Context.orchestrate("hello", function(response, error, metadata) {
            result.called = true;
            result.response = response;
            result.metadata = metadata;
        });

        verify(result.called);
        compare(result.response, "Hi there");
        compare(result.metadata.smartContext, true);
        compare(result.metadata.routing.length, 1);
        compare(result.metadata.routing[0], "direct");
        compare(result.metadata.promptTokens, 5);
        verify(result.metadata.estimatedCost > 0, "cost merged from leg");

        // leg 1 + background summarizer (block crossed the 4-message threshold)
        compare(saved.sendRawCalls.length, 2);
        var leg = saved.sendRawCalls[0];
        compare(leg.modelRef, null, "leg 1 uses main model");
        compare(leg.messages.length, 4, "system + 2 tail + user");
        compare(leg.messages[0].role, "system");
        verify(leg.messages[0].content.indexOf("CONTEXT ROUTING PROTOCOL") !== -1);
        verify(leg.messages[0].content.indexOf("SYS") === 0, "user system prompt preserved");
        verify(leg.messages[0].content.indexOf("seed topic") !== -1, "manifest included");
        compare(leg.messages[3].content, "hello");
        compare(saved.sendRawCalls[1].modelRef, "fast|model", "summarizer used the fast model");

        compare(ChatHistory.getHistory().length, 8, "only final exchange persisted");
        compare(ChatHistory.getBlocks().length, 1, "sticky assignment into existing block");
        compare(ChatHistory.lastUsedBlock().id, seed.id);
        compare(ChatHistory.findBlock(seed.id).messageIds.length, 4);
    }

    function test_orchestrate_direct_answer_without_last_block_creates_block() {
        for (var i = 0; i < 6; i++) {
            ChatHistory.addMessage(i % 2 === 0 ? "user" : "model", "msg" + i);
        }
        ChatHistory.createBlock("seed topic"); // never assigned, so no last-used block
        Context.setEnabled(true);
        saved.script = [{ response: "Hi there [[NEED_CONTEXT: none]]" }];
        var result = { called: false };
        Context.orchestrate("hello", function(response) {
            result.called = true;
            result.response = response;
        });

        verify(result.called);
        compare(result.response, "Hi there");
        compare(saved.sendRawCalls.length, 1, "no summarizer: fresh block below threshold");
        compare(ChatHistory.getBlocks().length, 2, "new block created for direct answer");
        compare(ChatHistory.lastUsedBlock().summary, "hello");
    }

    function test_orchestrate_fetches_requested_buckets() {
        var block = seedRoutingState();
        saved.script = [
            { response: "Let me check... [[NEED_CONTEXT: " + block.id + "]]", meta: { promptTokens: 10, completionTokens: 5, totalTokens: 15 } },
            { response: "Final answer with context", meta: { promptTokens: 20, completionTokens: 8, totalTokens: 28 } }
        ];
        var result = { called: false };
        Context.orchestrate("follow up question", function(response, error, metadata) {
            result.called = true;
            result.response = response;
            result.metadata = metadata;
        });

        verify(result.called);
        compare(result.response, "Final answer with context");
        // leg 1 + leg 2 + background summarizer (block crossed 4-message threshold)
        compare(saved.sendRawCalls.length, 3);

        var leg2 = saved.sendRawCalls[1];
        verify(leg2.messages[0].content.indexOf("seed topic") !== -1, "bucket content shipped");
        verify(leg2.messages[0].content.indexOf("Answer the user's message now") !== -1, "forced answer instruction");
        compare(leg2.messages[1].content, "follow up question");
        compare(saved.sendRawCalls[2].modelRef, "fast|model", "summarizer used the fast model");

        compare(result.metadata.promptTokens, 30, "tokens merged across legs");
        compare(result.metadata.routing[0], block.id);
        compare(ChatHistory.getHistory().length, 8, "negotiation legs ephemeral");

        var refreshed = ChatHistory.findBlock(block.id);
        compare(refreshed.messageIds.length, 4, "2 seeded + 2 new exchange messages");
    }

    function test_orchestrate_falls_back_on_provider_error() {
        seedRoutingState();
        saved.script = [{ error: "boom" }];
        var result = { called: false };
        Context.orchestrate("hello", function(response, error, metadata) {
            result.called = true;
            result.response = response;
            result.metadata = metadata;
        });

        verify(result.called);
        compare(result.response, "legacy-answer");
        compare(saved.legacyCalls.length, 1);
        compare(result.metadata.routing[0], "fallback");
        compare(ChatHistory.getHistory().length, 8, "legacy added the exchange");
    }

    function test_orchestrate_abort_swallows_everything() {
        seedRoutingState();
        saved.script = [{ defer: true, response: "late answer" }];
        var result = { called: false };
        var handle = Context.orchestrate("hello", function() {
            result.called = true;
        });

        handle.abort();
        saved.pending();
        verify(!result.called, "callback suppressed after abort");
        compare(ChatHistory.getHistory().length, 6, "no history writes after abort");
    }

    function test_orchestrate_requests_new_block_for_new_topic() {
        seedRoutingState();
        var blockCountBefore = ChatHistory.getBlocks().length;
        saved.script = [{ response: "Brand new topic answer [[NEED_CONTEXT: new]]" }];
        var result = { called: false };
        Context.orchestrate("completely new question", function(response) {
            result.called = true;
            result.response = response;
        });

        verify(result.called);
        compare(result.response, "Brand new topic answer");
        compare(saved.sendRawCalls.length, 1, "no leg 2 for new topic");
        compare(ChatHistory.getBlocks().length, blockCountBefore + 1, "new block spawned");
        compare(ChatHistory.lastUsedBlock().summary, "completely new question");
    }

    // ---------- context.js: summarizer ----------

    function test_summarizer_updates_block_via_fast_model() {
        var block = ChatHistory.createBlock("stale summary");
        var ids = [];
        for (var i = 0; i < 4; i++) {
            ids.push(ChatHistory.addMessage(i % 2 === 0 ? "user" : "model", "line " + i).id);
        }
        ChatHistory.assignMessages(block.id, ids);

        saved.script = [{ response: "  \"A sharp summary of the talk.\"  " }];
        Context.maybeSummarize(block.id);

        compare(saved.sendRawCalls.length, 1);
        compare(saved.sendRawCalls[0].modelRef, "fast|model", "summarizer uses fast model");
        var sys = saved.sendRawCalls[0].messages[0];
        compare(sys.role, "system");
        verify(sys.content.indexOf("summar") !== -1);

        var refreshed = ChatHistory.findBlock(block.id);
        compare(refreshed.summary, "A sharp summary of the talk.");
        compare(refreshed.lastSummaryCount, 4);
    }

    function test_summarizer_skips_small_or_fresh_blocks() {
        var block = ChatHistory.createBlock("tiny");
        var ids = [];
        for (var i = 0; i < 3; i++) {
            ids.push(ChatHistory.addMessage("user", "line " + i).id);
        }
        ChatHistory.assignMessages(block.id, ids);
        Context.maybeSummarize(block.id);
        compare(saved.sendRawCalls.length, 0, "below min size, no summarizer call");

        // Simulate a recent summary, then a single new message: below threshold
        ChatHistory.updateBlockSummary(block.id, "fresh summary", 3);
        var fourth = ChatHistory.addMessage("model", "line 3").id;
        ChatHistory.assignMessages(block.id, [fourth]);
        Context.maybeSummarize(block.id);
        compare(saved.sendRawCalls.length, 0, "only 1 new message since summary, no call");

        // Second new message crosses the threshold
        var fifth = ChatHistory.addMessage("user", "line 4").id;
        ChatHistory.assignMessages(block.id, [fifth]);
        Context.maybeSummarize(block.id);
        compare(saved.sendRawCalls.length, 1, "2 new messages since summary triggers summarizer");
    }
}