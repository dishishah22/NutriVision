import os
import requests
from dotenv import load_dotenv

load_dotenv()

# Get key from .env file
GROQ_API_KEY = os.getenv("OPENROUTER_API_KEY") # You are using Groq keys in the OpenRouter variable
url = "https://api.groq.com/openai/v1/models"
headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}

if not GROQ_API_KEY:
    print("❌ ERROR: API Key not found. Check your .env file at backend/api/.env")
else:
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            models = response.json().get('data', [])
            print("Successfully fetched models:")
            for m in models:
                print(f"- {m['id']}")
        else:
            print(f"Error: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Connection failed: {e}")