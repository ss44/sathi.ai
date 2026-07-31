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
    return "enc:v1:" + Qt.btoa(result);
}

function decodeKey(encodedText) {
    if (!encodedText) return "";
    
    // Check if it has our security envelope
    var hasPrefix = encodedText.startsWith("enc:v1:");
    var targetText = hasPrefix ? encodedText.substring(7) : encodedText;
    
    try {
        var text = Qt.atob(targetText);
        var xorKey = "sathi_ai_secret_key_123";
        var result = "";
        for (var i = 0; i < text.length; i++) {
            result += String.fromCharCode(text.charCodeAt(i) ^ xorKey.charCodeAt(i % xorKey.length));
        }
        
        // If it successfully decodes but looks like gibberish and didn't have a prefix,
        // it might have just been a plain text key that accidentally decoded as base64.
        // But if it had the prefix, we absolutely trust the decoded result.
        return result;
    } catch (e) {
        // If it fails to decode, it was definitely an unencrypted legacy key
        return targetText;
    }
}
