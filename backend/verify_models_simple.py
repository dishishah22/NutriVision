import google.genai as genai
import time

GOOGLE_API_KEY = "AIzaSyBsgZ1YAz_NZfuDzLhtLQFTNZQC0_FDwD4"
genai.configure(api_key=GOOGLE_API_KEY)

# Try a few models in order of preference
MODELS_TO_TRY = [
    "models/gemini-1.5-flash",
    "models/gemini-2.0-flash-lite",
    "models/gemini-1.5-flash-8b"
]

for model_name in MODELS_TO_TRY:
    print(f"Testing model: {model_name}")
    try:
        model = genai.GenerativeModel(model_name)
        response = model.generate_content("Hello, simulate a food analysis response for 'Pizza'.")
        print(f"✅ Success with {model_name}!")
        print(f"Response: {response.text[:100]}...")
        break
    except Exception as e:
        print(f"❌ Failed with {model_name}: {e}")
        time.sleep(1)
