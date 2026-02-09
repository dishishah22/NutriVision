from flask import Flask, request, redirect, jsonify
from flask_cors import CORS
import requests
import os

app = Flask(__name__)
CORS(app)

@app.route("/")
def home():
    return "Backend is running successfully!"

# -------------------------------
# STRAVA CONFIG
# -------------------------------

CLIENT_ID = "200807"
CLIENT_SECRET = "bf73a378afc9679cf48e86f6161488e04800e1d1"
REDIRECT_URI = "http://10.110.80.87:8000/callback"

# -------------------------------
# 1️⃣ Health Check API
# -------------------------------

@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "Backend running"})


# -------------------------------
# 2️⃣ Start Strava Login
# -------------------------------

@app.route("/api/strava/login", methods=["GET"])
def strava_login():

    auth_url = (
        "https://www.strava.com/oauth/authorize"
        f"?client_id={CLIENT_ID}"
        "&response_type=code"
        f"&redirect_uri={REDIRECT_URI}"
        "&scope=read,activity:read_all"
    )

    return redirect(auth_url)


# -------------------------------
# 3️⃣ Strava Redirect Callback
# -------------------------------

@app.route("/callback", methods=["GET"])
def callback():

    code = request.args.get("code")

    token_url = "https://www.strava.com/oauth/token"

    payload = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "code": code,
        "grant_type": "authorization_code"
    }

    response = requests.post(token_url, data=payload)
    data = response.json()

    access_token = data.get("access_token")
    
    print(f"✅ Strava Access Token: {access_token}")

    # Send token back to Flutter
    return redirect(f"nutrivision://callback?token={access_token}")


# -------------------------------
# 4️⃣ Get Athlete Activities
# -------------------------------

@app.route("/api/strava/activities", methods=["GET"])
def get_activities():

    token = request.headers.get("Authorization")

    if not token:
        return jsonify({"error": "Missing token"}), 401

    headers = {
        "Authorization": f"Bearer {token}"
    }

    response = requests.get(
        "https://www.strava.com/api/v3/athlete/activities",
        headers=headers
    )

    return jsonify(response.json())


# -------------------------------
# MAIN
# -------------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)