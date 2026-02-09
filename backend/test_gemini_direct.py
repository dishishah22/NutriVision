from google import genai
from PIL import Image
import io

GOOGLE_API_KEY = "AIzaSyBsgZ1YAz_NZfuDzLhtLQFTNZQC0_FDwD4"
client = genai.Client(api_key=GOOGLE_API_KEY)

# Create dummy image
img = Image.new('RGB', (100, 100), color = 'red')

print("Testing Gemini directly...")
try:
    response = client.models.generate_content(
        model="gemini-2.0-flash-exp",
        contents=["Tell me what this is", img]
    )
    print("Success:", response.text)
except Exception as e:
    print(f"Error 1 (gemini-2.0-flash-exp): {e}")

try:
    response = client.models.generate_content(
        model="models/gemini-2.0-flash-exp",
        contents=["Tell me what this is", img]
    )
    print("Success:", response.text)
except Exception as e:
    print(f"Error 2 (models/gemini-2.0-flash-exp): {e}")

try:
    response = client.models.generate_content(
        model="gemini-1.5-flash",
        contents=["Tell me what this is", img]
    )
    print("Success 3 (gemini-1.5-flash):", response.text)
except Exception as e:
    print(f"Error 3 (gemini-1.5-flash): {e}")
