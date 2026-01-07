import sys
import json
import os
from google import genai

# Simple buffering for stdin to ensure we get complete lines
def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    chat = None
    client = None

    if api_key:
        try:
            client = genai.Client(api_key=api_key)
            # bumped to 3-flash-preview
            chat = client.chats.create(model='gemini-3-flash-preview')
        except Exception as e:
            print(json.dumps({"error": f"Init failed: {str(e)}"}), flush=True)
    else:
        print(json.dumps({"error": "GEMINI_API_KEY not found"}), flush=True)

    # Read lines from stdin
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
            
        try:
            # We assume the input is just the raw text prompt strings for now
            # In a real app, successful JSON parsing is safer
            user_text = line
            
            if not chat:
                print(json.dumps({"error": "Backend not initialized (Check API Key)"}), flush=True)
                continue

            response = chat.send_message(user_text)
            
            # Output structured JSON response
            output = {
                "text": response.text,
                "role": "model"
            }
            print(json.dumps(output), flush=True)
            
        except Exception as e:
            error_out = {"error": str(e)}
            print(json.dumps(error_out), flush=True)

if __name__ == "__main__":
    main()
