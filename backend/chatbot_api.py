import os
import time
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
from fastapi.middleware.cors import CORSMiddleware

# ==========================================
# LOAD ENV
# ==========================================
load_dotenv()
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

if not OPENROUTER_API_KEY:
    raise RuntimeError("OPENROUTER_API_KEY not found in .env")

# ==========================================
# FASTAPI INIT
# ==========================================
app = FastAPI(title="Fitness AI Chatbot API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# RATE LIMIT STORAGE
# ==========================================
last_request_time = {}

def rate_limit(user_id: str, cooldown: int = 3):
    now = time.time()
    last = last_request_time.get(user_id, 0)

    if now - last < cooldown:
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please wait a few seconds."
        )

    last_request_time[user_id] = now

# ==========================================
# REQUEST MODEL
# ==========================================
class ChatRequest(BaseModel):
    user_id: str
    message: str

# ==========================================
# SYSTEM PROMPT
# ==========================================
SYSTEM_PROMPT = """
You are a professional AI nutrition and fitness assistant.

Rules:
- Only answer questions related to diet, fitness, exercise, weight loss, muscle gain, or healthy lifestyle.
- If unrelated, respond exactly:
  "I can only assist with diet and fitness related questions."
- Keep answers structured and practical.
- Use bullet points when helpful.
"""

# ==========================================
# CHAT ENDPOINT
# ==========================================
@app.post("/chat")
def chat(request: ChatRequest):
    print(f"[{time.ctime()}] Received message from {request.user_id}")

    if not request.message.strip():
        print(f"[{time.ctime()}] Empty message received")
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    try:
        rate_limit(request.user_id)
    except HTTPException as e:
        print(f"[{time.ctime()}] Rate limit hit for {request.user_id}")
        raise e

    try:
        print(f"[{time.ctime()}] Sending request to OpenRouter...")
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "anthropic/claude-3.5-sonnet",
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": request.message}
                ],
                "temperature": 0.4,
                "max_tokens": 150
            },
            timeout=30
        )

        if response.status_code == 402:
            print(f"[{time.ctime()}] ❌ OpenRouter Error 402: Credits insufficient for requested tokens")
            raise HTTPException(
                status_code=402, 
                detail="AI limit reached. Please reduce your message length or try again later."
            )

        if response.status_code != 200:
            print(f"[{time.ctime()}] OpenRouter Error {response.status_code}: {response.text}")
            raise HTTPException(status_code=500, detail=f"OpenRouter Error: {response.text}")

        data = response.json()
        if "choices" not in data or not data["choices"]:
            print(f"[{time.ctime()}] Invalid response structure from OpenRouter: {data}")
            raise HTTPException(status_code=500, detail="Invalid response structure from AI")

        reply = data["choices"][0]["message"]["content"]
        print(f"[{time.ctime()}] Successfully received reply (Length: {len(reply)})")

        return {
            "success": True,
            "reply": reply.strip()
        }

    except requests.exceptions.Timeout:
        print(f"[{time.ctime()}] Request to OpenRouter timed out")
        raise HTTPException(status_code=504, detail="Request timed out")
    except HTTPException as e:
        # Re-raise HTTPException so it is not caught by the generic Exception handler
        raise e
    except Exception as e:
        print(f"[{time.ctime()}] GENERAL ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# HEALTH CHECK
# ==========================================
@app.get("/health")
def health():
    return {"status": "API running successfully"}

# ==========================================
# RUN SERVER
# ==========================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8006)
