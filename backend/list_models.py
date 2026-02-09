import google.genai as genai

GOOGLE_API_KEY = "AIzaSyBsgZ1YAz_NZfuDzLhtLQFTNZQC0_FDwD4"
genai.configure(api_key=GOOGLE_API_KEY)

print("Listing supported models:")
try:
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print(f"Model found: {m.name}")
except Exception as e:
    print(f"Error listing models: {e}")
