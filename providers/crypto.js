.pragma library

// Simple obfuscation for API keys to avoid plain text storage
// This is not cryptographically secure but prevents casual snooping in the config file

function encodeKey(text) {
    if (!text) return "";
    var xorKey = "sathi_ai_secret_key_123";
    var result = "";
    for (var i = 0; i < text.length; i++) {
        result += String.fromCharCode(text.charCodeAt(i) ^ xorKey.charCodeAt(i % xorKey.length));
    }
    return Qt.btoa(result);
}

function decodeKey(encodedText) {
    if (!encodedText) return "";
    try {
        var text = Qt.atob(encodedText);
        var xorKey = "sathi_ai_secret_key_123";
        var result = "";
        for (var i = 0; i < text.length; i++) {
            result += String.fromCharCode(text.charCodeAt(i) ^ xorKey.charCodeAt(i % xorKey.length));
        }
        return result;
    } catch (e) {
        // If it fails, it might be an unencrypted legacy key
        return encodedText;
    }
}
