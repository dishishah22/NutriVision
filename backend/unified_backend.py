import os
import time
import requests
import traceback
import json
import re
import datetime
import io
from PIL import Image
from fastapi import FastAPI, File, UploadFile, Form, Query, HTTPException, Request
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# New Architecture Imports
from ai_providers.ai_router import AIRouter
from firebase_config import save_scan_to_firebase

# ==========================================
# ⚙️ CONFIG & ENV
# ==========================================
load_dotenv()
CURRENT_IP = "10.110.3.21" # AUTO-DETECTED
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "AIzaSyBsgZ1YAz_NZfuDzLhtLQFTNZQC0_FDwD4")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "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")
STRAVA_CLIENT_ID = "200807"
STRAVA_CLIENT_SECRET = os.getenv("STRAVA_CLIENT_SECRET", "bf73a378afc9679cf48e86f6161488e04800e1d1")
STRAVA_REDIRECT_URI = f"http://{CURRENT_IP}:8500/callback"

ai_router = AIRouter(GEMINI_API_KEY, OPENROUTER_API_KEY)

# ==========================================
# 🚀 FASTAPI INIT
# ==========================================
app = FastAPI(title="NutriVision Unified API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 🤖 AI CHATBOT CONFIG
# ==========================================
class ChatRequest(BaseModel):
    user_id: str
    message: str

SYSTEM_PROMPT = """
You are a professional AI nutrition and fitness assistant.
Rules:
- Only answer questions related to diet, fitness, exercise, weight loss, muscle gain, or healthy lifestyle.
- If unrelated, respond exactly: "I can only assist with diet and fitness related questions."
- Keep answers structured and practical.
"""

last_chat_time = {}

def chat_rate_limit(user_id: str, cooldown: int = 2):
    now = time.time()
    last = last_chat_time.get(user_id, 0)
    if now - last < cooldown:
        raise HTTPException(status_code=429, detail="Too many requests.")
    last_chat_time[user_id] = now

# ==========================================
# 🍎 MEAL SCAN CONFIG
# ==========================================
FOOD_PROMPT = """
Analyze this food image. Return a STRICT JSON object:
{
    "Food": "Name",
    "Classification": "Veg/Non-Veg",
    "Ingredients": {"Raw Material": [], "Spices": [], "Oils": []},
    "Nutrients": {"Calories": 0, "Protein": 0, "Carbohydrates": 0, "Fat": 0}
}
"""

def clean_val(val):
    if isinstance(val, (int, float)): return float(val)
    if isinstance(val, str):
        match = re.search(r"(\d+(\.\d+)?)", val)
        return float(match.group(1)) if match else 0.0
    return 0.0

# ==========================================
# 🎯 ENDPOINTS - AI ASSISTANT
# ==========================================
@app.post("/chat")
async def chat(request: ChatRequest):
    print(f"[{time.ctime()}] Chat message from {request.user_id}")
    chat_rate_limit(request.user_id)
    
    try:
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {OPENROUTER_API_KEY}"},
            json={
                "model": "anthropic/claude-3.5-sonnet",
                "messages": [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": request.message}],
                "temperature": 0.4,
                "max_tokens": 150
            },
            timeout=25
        )
        
        if response.status_code == 402:
            raise HTTPException(status_code=402, detail="AI usage limit reached.")
        
        data = response.json()
        reply = data["choices"][0]["message"]["content"]
        return {"success": True, "reply": reply.strip()}
    except Exception as e:
        if isinstance(e, HTTPException): raise e
        print(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# 📸 ENDPOINTS - MEAL SCAN
# ==========================================
@app.post("/analyze-food")
async def analyze_food(image: UploadFile = File(...), login_id: str = Form(...)):
    print(f"Scan request from {login_id}")
    try:
        image_bytes = await image.read()
        res_data, provider, model = ai_router.analyze_food(FOOD_PROMPT, image_bytes)
        
        if not res_data:
            return {"status": "failure", "message": "AI failed"}

        nutrients = res_data.get("Nutrients", {})
        cals = clean_val(nutrients.get("Calories", 0))
        prot = clean_val(nutrients.get("Protein", 0))
        fat = clean_val(nutrients.get("Fat", 0))
        carb = clean_val(nutrients.get("Carbohydrates", 0))

        save_scan_to_firebase(login_id, "meal_scan", res_data.get("Food", "Meal"), cals, prot, fat, carb, f"{provider}:{model}", res_data)

        return {
            "status": "success",
            "food_name": res_data.get("Food", "Meal"),
            "nutrition": {"calories": cals, "protein": prot, "fat": fat, "carbs": carb},
            "full_data": res_data
        }
    except Exception as e:
        print(f"Analyze Error: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/scan/{barcode}")
async def scan_barcode(barcode: str, login_id: str = Query("anonymous")):
    print(f"Barcode: {barcode}")
    url = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
    try:
        r = requests.get(url, timeout=10)
        product = r.json().get("product", {})
        if not product: return {"status": "failure"}
        
        nutri = product.get("nutriments", {})
        cals = float(nutri.get("energy-kcal_100g", 0))
        
        save_scan_to_firebase(login_id, "barcode_scan", product.get("product_name", "Product"), cals, 0, 0, 0, "open_food_facts", product)
        
        return {"status": "success", "food_name": product.get("product_name"), "nutrition": {"calories": cals}}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==========================================
# 🚴 ENDPOINTS - STRAVA
# ==========================================
@app.get("/api/strava/login")
async def strava_login():
    auth_url = (f"https://www.strava.com/oauth/authorize?client_id={STRAVA_CLIENT_ID}"
                f"&response_type=code&redirect_uri={STRAVA_REDIRECT_URI}&scope=read,activity:read_all")
    return RedirectResponse(url=auth_url)

@app.get("/callback")
async def callback(code: str):
    res = requests.post("https://www.strava.com/oauth/token", data={
        "client_id": STRAVA_CLIENT_ID, "client_secret": STRAVA_CLIENT_SECRET,
        "code": code, "grant_type": "authorization_code"
    })
    access_token = res.json().get("access_token")
    return RedirectResponse(url=f"nutrivision://callback?token={access_token}")

@app.get("/api/strava/activities")
async def get_activities(request: Request):
    token = request.headers.get("Authorization")
    if not token: return {"error": "Unauthorized"}, 401
    r = requests.get("https://www.strava.com/api/v3/athlete/activities", headers={"Authorization": f"Bearer {token}"})
    return r.json()

# ==========================================
# 🏥 HEALTH & RUN
# ==========================================
@app.get("/health")
@app.get("/api/health")
async def health():
    return {"status": "ok", "message": "Unified Backend is Live", "ip": CURRENT_IP}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8500)
