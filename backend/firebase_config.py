import firebase_admin
from firebase_admin import credentials, firestore
import json
import datetime
import os

# 🔹 Path to your Firebase service account JSON
# Generate this from Firebase Console: Project Settings -> Service Accounts -> Generate new private key
SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")

db = None

try:
    if not firebase_admin._apps:
        if os.path.exists(SERVICE_ACCOUNT_PATH):
            cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
            firebase_admin.initialize_app(cred)
            print("Firebase initialized successfully with service account.")
        else:
            firebase_admin.initialize_app()
            print("Firebase initialized with default credentials.")
    
    db = firestore.client()
except Exception as e:
    print(f"Firebase initialization failed: {e}")
    print("Please place 'serviceAccountKey.json' in the backend folder to enable database features.")

def save_scan_to_firebase(
    login_id,
    scan_type,
    food_name,
    calories,
    protein,
    fat,
    carbs,
    ai_provider,
    raw_response
):
    if db is None:
        print("Firestore not available. Scan not saved.")
        return False
    
    try:
        # 1. References
        user_ref = db.collection("users").document(login_id)
        scan_ref = user_ref.collection("scans").document() # Auto-ID
        
        # 2. Update Nutrition Summary (Atomic)
        summary_ref = user_ref.get()
        if not summary_ref.exists:
            user_ref.set({
                "nutrition_summary": {
                    "totalCalories": calories,
                    "totalProtein": protein,
                    "totalCarbs": carbs,
                    "totalFat": fat,
                    "lastUpdated": datetime.datetime.now()
                }
            }, merge=True)
        else:
            user_ref.update({
                "nutrition_summary.totalCalories": firestore.Increment(calories),
                "nutrition_summary.totalProtein": firestore.Increment(protein),
                "nutrition_summary.totalCarbs": firestore.Increment(carbs),
                "nutrition_summary.totalFat": firestore.Increment(fat),
                "nutrition_summary.lastUpdated": datetime.datetime.now()
            })

        # 3. Save to User-Specific History (for Frontend)
        scan_data = {
            "scanId": scan_ref.id,
            "userId": login_id,
            "scanType": scan_type,
            "foodName": food_name,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "aiProvider": ai_provider,
            "rawApiResponse": raw_response if isinstance(raw_response, dict) else {"raw": str(raw_response)},
            "createdAt": datetime.datetime.now()
        }
        scan_ref.set(scan_data)

        # 4. Save to GLOBAL History (for you to see easily in DB)
        db.collection("history").document(scan_ref.id).set(scan_data)

        # 5. NEW: Scan Logs Table (High-speed flat list)
        db.collection("scan_logs").add({
            "timestamp": datetime.datetime.now(),
            "userId": login_id,
            "meal": food_name,
            "kcal": calories,
            "source": ai_provider
        })

        # 6. NEW: Daily App Metrics Table (Aggregates across ALL users)
        today_str = datetime.datetime.now().strftime("%Y-%m-%d")
        metrics_ref = db.collection("daily_app_metrics").document(today_str)
        metrics_ref.set({
            "total_kcal": firestore.Increment(calories),
            "total_scans": firestore.Increment(1),
            "last_active": datetime.datetime.now()
        }, merge=True)
        
        print(f"✅ Data synced to HISTORY, SCAN_LOGS, and DAILY_METRICS for: {login_id}")
        return True
    except Exception as e:
        print(f"❌ Error saving to Firebase: {e}")
        return False

