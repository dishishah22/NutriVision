from google import genai
from google.genai import types
import time
import os
import io
import json
import re
from PIL import Image

class GeminiClient:
    def __init__(self, api_key):
        self.api_key = api_key
        # Initialize the NEW official SDK client
        self.client = genai.Client(api_key=self.api_key)
        
        # New SDK usually expects shorter model IDs
        self.models = [
            "gemini-1.5-flash",
            "gemini-1.5-flash-latest",
            "gemini-2.0-flash-lite-preview-02-05", 
            "gemini-2.0-flash-exp",
            "gemini-1.5-pro",
        ]

    def analyze_food(self, prompt, image_bytes):
        try:
            img = Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            print(f"❌ [Gemini] Image processing error: {e}")
            return None, None
            
        for model_name in self.models:
            print(f"🚀 [Gemini] Trying {model_name}...")
            try:
                # In the new SDK, generate_content is called on client.models
                response = self.client.models.generate_content(
                    model=model_name,
                    contents=[prompt, img]
                )
                
                if response and response.text:
                    raw_text = response.text
                    # Clean up JSON formatting if present
                    raw_text = re.sub(r"```json|```", "", raw_text).strip()
                    # Find start and end of JSON blob
                    start_idx = raw_text.find("{")
                    end_idx = raw_text.rfind("}")
                    if start_idx != -1 and end_idx != -1:
                        json_text = raw_text[start_idx : end_idx + 1]
                        return json.loads(json_text), model_name
                    else:
                        print(f"⚠️ [Gemini] No JSON found in response from {model_name}")
                        continue
                        
            except Exception as e:
                print(f"⚠️ [Gemini] {model_name} failed: {e}")
                # Check for quota or generic errors to skip to next model
                if "429" in str(e) or "quota" in str(e).lower():
                    continue 
                else:
                    # Generic error, still try fallback list
                    continue
        
        return None, None
