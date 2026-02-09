import os
import re
import datetime
import traceback
import time
import io
import json
import requests
from PIL import Image
from fastapi import FastAPI, File, UploadFile, Form, Query
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

# New Architecture Imports
from ai_providers.ai_router import AIRouter
from firebase_config import save_scan_to_firebase

# ================= LOAD ENVIRONMENT =================
# This looks for the .env file in the current directory (backend/api)
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

# Initialize Router with keys from .env
ai_router = AIRouter(GEMINI_API_KEY, OPENROUTER_API_KEY)

# 🔥 AI IMAGE PROMPT
prompt = """
Analyze this food image. If there are multiple dishes then calorie is above, detect all of them and include their information in the same JSON structure.  

Return a STRICT JSON object in this exact format:

{
    "Food": "Name of the dish",
    "Classification": "Veg" or "Non-Veg",
    "Ingredients": {
        "Raw Material": ["List of main ingredients"],
        "Spices": ["List of spices"],
        "Oils": ["List of oils used"],
        "Flavour Enhancers": ["List if any"],
        "Colors": ["List if any"]
    },
    "Allergies": ["List of potential allergens"],
    "Nutrients": {
        "Calories": "Total kcal per 100g",
        "Protein": "g per 100g",
        "Carbohydrates": "g per 100g",
        "Fat": "g per 100g",
        "Fiber": "g per 100g",
        "Sugar": "g per 100g"
    }
}

**Rules:**
1. If there are multiple dishes, combine their information in this single JSON by separating each dish’s values clearly.
2. Ensure accuracy. If any information is unknown, use "Unknown".
3. Only return JSON. DO NOT include any extra text.
"""

# ================= FASTAPI APP =================
app = FastAPI(title="Unified Food & Barcode AI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok", "message": "Backend is reachable"}

# ================= HELPERS =================
def clean_val(val):
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        match = re.search(r"(\d+(\.\d+)?)", val)
        return float(match.group(1)) if match else 0.0
    return 0.0

def extract_macros_and_calories(nutrients):
    cals = clean_val(nutrients.get("Calories", 0))
    return {
        "calories": cals,
        "protein": clean_val(nutrients.get("Protein", 0)),
        "carbs": clean_val(nutrients.get("Carbohydrates", 0)),
        "fat": clean_val(nutrients.get("Fat", 0))
    }

# ================= API ENDPOINTS =================
@app.post("/analyze-food")
async def analyze_food(image: UploadFile = File(...), login_id: str = Form(...)):
    try:
        image_bytes = await image.read()
        res_data, provider, model = ai_router.analyze_food(prompt, image_bytes)
        
        if not res_data:
            return {"status": "failure", "message": "AI fallback exhausted."}

        nutrients = res_data.get("Nutrients", res_data)
        nutrition_info = extract_macros_and_calories(nutrients)

        save_scan_to_firebase(
            login_id=login_id,
            scan_type="meal_scan",
            food_name=res_data.get("Food", "Unknown Meal"),
            calories=nutrition_info["calories"],
            protein=nutrition_info["protein"],
            fat=nutrition_info["fat"],
            carbs=nutrition_info["carbs"],
            ai_provider=f"{provider}:{model}",
            raw_response=res_data
        )

        cals = nutrition_info["calories"]
        legacy_compat_data = {
            "food_name": res_data.get("Food", "Unknown Meal"),
            "classification": res_data.get("Classification", "Unknown"),
            "nutrition_per_100g": {
                "calories_range_per_100g": {"min": max(0, cals-20), "max": cals+20},
                "protein_g_per_100g": nutrition_info["protein"],
                "carbs_g_per_100g": nutrition_info["carbs"],
                "fat_g_per_100g": nutrition_info["fat"],
                "fiber_g_per_100g": clean_val(nutrients.get("Fiber", 0)),
                "sugar_g_per_100g": clean_val(nutrients.get("Sugar", 0))
            },
            "ingredients": {
                "raw_material": res_data.get("Ingredients", {}).get("Raw Material", []),
                "spices": res_data.get("Ingredients", {}).get("Spices", []),
                "oils": res_data.get("Ingredients", {}).get("Oils", []),
                "flavour_enhancers": res_data.get("Ingredients", {}).get("Flavour Enhancers", []),
                "colors": res_data.get("Ingredients", {}).get("Colors", [])
            },
            "allergies": res_data.get("Allergies", [])
        }

        return {
            "status": "success",
            "scan_type": "meal_scan",
            "food_name": legacy_compat_data["food_name"],
            "nutrition": nutrition_info,
            "ai_provider": provider,
            "created_at": datetime.datetime.now().isoformat(),
            "full_data": legacy_compat_data
        }
    except Exception as e:
        traceback.print_exc()
        return {"status": "error", "message": str(e)}

@app.get("/scan/{barcode}")
def scan_barcode(barcode: str, login_id: str = Query("anonymous_user")):
    url = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
    try:
        response = requests.get(url, timeout=5)
        product = response.json().get("product", {})
        if not product: return {"status": "failure", "message": "Not found"}

        nutriments = product.get("nutriments", {})
        nutrition_info = {
            "calories": float(nutriments.get("energy-kcal_100g", 0)),
            "protein": float(nutriments.get("proteins_100g", 0)),
            "fat": float(nutriments.get("fat_100g", 0)),
            "carbs": float(nutriments.get("carbohydrates_100g", 0))
        }

        save_scan_to_firebase(
            login_id=login_id,
            scan_type="barcode_scan",
            food_name=product.get("product_name", "Unknown Product"),
            calories=nutrition_info["calories"],
            protein=nutrition_info["protein"],
            fat=nutrition_info["fat"],
            carbs=nutrition_info["carbs"],
            ai_provider="open_food_facts",
            raw_response=product
        )

        return {
            "status": "success",
            "product_name": product.get("product_name", "Unknown Product"),
            "nutrition": nutrition_info,
            "created_at": datetime.datetime.now().isoformat()
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/")
def root():
    return {"status": "running", "provider": "Unified Nutrition AI"}