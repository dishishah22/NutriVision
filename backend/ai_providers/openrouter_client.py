import requests
import json
import base64
import time
import re

class OpenRouterClient:
    """
    Client for OpenRouter (or Groq as fallback based on USER's provided key)
    """
    def __init__(self, api_key):
        self.api_key = api_key
        # If it's a Groq key (starts with gsk_), we use Groq URL
        if api_key.startswith("gsk_"):
            self.url = "https://api.groq.com/openai/v1/chat/completions"
            self.models = [
                "meta-llama/llama-4-scout-17b-16e-instruct",
                "meta-llama/llama-4-maverick-17b-128e-instruct",
            ]
            self.provider_name = "groq"
        else:
            self.url = "https://openrouter.ai/api/v1/chat/completions"
            self.models = [
                "google/gemini-flash-1.5", # Popular OpenRouter models
                "anthropic/claude-3-haiku",
            ]
            self.provider_name = "openrouter"

    def analyze_food(self, prompt, image_bytes):
        base64_image = base64.b64encode(image_bytes).decode('utf-8')
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        for model_name in self.models:
            print(f"🚀 [{self.provider_name.upper()}] Trying {model_name}...")
            payload = {
                "model": model_name,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt + "\n\nSTRICT JSON ONLY."},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 400
            }

            try:
                response = requests.post(self.url, headers=headers, json=payload, timeout=30)
                if response.status_code == 200:
                    response_json = response.json()
                    raw_text = response_json['choices'][0]['message']['content']
                    # Clean up
                    raw_text = re.sub(r"```json|```", "", raw_text).strip()
                    json_text = raw_text[raw_text.find("{"):raw_text.rfind("}")+1]
                    return json.loads(json_text), model_name
                else:
                    print(f"⚠️ [{self.provider_name.upper()}] {model_name} failed: {response.status_code} {response.text}")
            except Exception as e:
                print(f"❌ [{self.provider_name.upper()}] Error with {model_name}: {e}")
                
        return None, None
