# NutriVision

NutriVision is a comprehensive health, fitness, and nutrition tracking application. It features a Flutter-based mobile frontend and a scalable, unified FastAPI Python backend. The application integrates advanced AI capabilities for food image recognition, barcode scanning, personalized AI chatbot assistance, and fitness tracking via Strava.

## Architecture Overview

### Frontend (Flutter)

- **Framework:** Flutter (`sdk: ^3.7.2`)
- **State Management & Networking:** `provider`, `http`
- **Authentication:** Firebase Auth, Google Sign-In
- **Database:** Firebase Cloud Firestore
- **AI & ML:** Google ML Kit Image Labeling, Custom TFLite Model (`1.tflite`) for Food Detection
- **UI & Animations:** Glassmorphism, Google Fonts, FL Chart, Animator, Staggered Animations
- **Hardware Integration:** Image Picker, Mobile Scanner (Barcode), Speech to Text, Flutter TTS

### Backend (FastAPI)

A unified backend (`unified_backend.py`) running on port `8500` that consolidates multiple services:

- **AI Chatbot Service:** Powered by OpenRouter (Claude 3.5 Sonnet) to provide personalized diet and fitness advice  
- **Meal Scan Service:** Analyzes food images using Google's Gemini API to estimate nutritional value (Calories, Protein, Fat, Carbs) and logs data directly to Firebase  
- **Barcode Scanner:** Fetches product nutrition information using the OpenFoodFacts API  
- **Strava Integration:** OAuth2 flow to connect users' Strava accounts and retrieve activity data  

---

## Setup and Execution Guide

### Prerequisites

- **Flutter SDK:** Ensure you have Flutter installed and configured  
- **Python:** Python 3.8+ installed  

**API Keys Required:**
- Gemini API Key  
- OpenRouter API Key  
- Strava Client ID & Secret  

**Firebase:**
- A configured Firebase project with Authentication and Firestore enabled  

---

## 1. Backend Setup & Execution

### Step 1: Navigate to Backend
```bash
cd d:\SBMP-SPECTRUM\NutriVision\backend
```

### Step 2: Install Dependencies
```bash
pip install fastapi uvicorn requests python-dotenv pydantic pillow
```

### Step 3: Configure Environment Variables

Create a `.env` file:

```env
GEMINI_API_KEY=your_gemini_api_key
OPENROUTER_API_KEY=your_openrouter_api_key
STRAVA_CLIENT_SECRET=your_strava_client_secret
```

### Step 4: Update IP Address

In `unified_backend.py`:

```python
CURRENT_IP = "192.168.x.x"
```

### Step 5: Run Backend
```bash
python unified_backend.py
```

Backend runs on:
```
http://0.0.0.0:8500
```

---

## 2. Frontend Setup & Execution

### Step 1: Navigate to Frontend
```bash
cd d:\SBMP-SPECTRUM\NutriVision\frontend
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Configure Firebase

- Ensure `firebase_options.dart` is updated with your Firebase project settings  
- Add `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)  

### Step 4: Update API Endpoint

Set base URL in Flutter code:
```
http://192.168.x.x:8500
```

### Step 5: Run Application
```bash
flutter run
```

---

## Key Features

- **Unified AI Engine:** Routes between Gemini (meal analysis) and Claude 3.5 Sonnet (text-based advice)  
- **Custom Scanner Models:** TFLite integration for local food detection  
- **User Progression:** Firebase authentication with data syncing  
- **Health Tracking Integration:** Strava activity sync into dashboard  
