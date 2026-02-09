import google.genai as genai
import os

GOOGLE_API_KEY = "AIzaSyBsgZ1YAz_NZfuDzLhtLQFTNZQC0_FDwD4"
genai.configure(api_key=GOOGLE_API_KEY)

print("Checking accessible models...")
try:
    models = genai.list_models()
    for m in models:
        if 'generateContent' in m.supported_generation_methods:
            print(f"Found: {m.name}")
except Exception as e:
    print(f"Error listing: {e}")
