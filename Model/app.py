from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import pickle
import json

# -------------------- APP INITIALIZATION --------------------

app = FastAPI(title="AI Service Marketplace")

# -------------------- CORS CONFIG --------------------
# Allows frontend (HTML/JS) to talk to backend

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],   # GET, POST, OPTIONS
    allow_headers=["*"],
)

# -------------------- LOAD MODEL & DATA --------------------

with open("model.pkl", "rb") as f:
    model = pickle.load(f)

with open("vectorizer.pkl", "rb") as f:
    vectorizer = pickle.load(f)

with open("workers.json", "r") as f:
    workers = json.load(f)

# -------------------- QUICK FIX DATABASE --------------------

quick_fixes = {
    "plumber": "Turn off the main water supply and avoid using the damaged pipe.",
    "electrician": "Switch off the main power immediately and avoid exposed wires.",
    "ac_technician": "Turn off the AC and clean filters if accessible.",
    "carpenter": "Avoid using damaged furniture until repaired.",
    "appliance_repair": "Unplug the appliance and stop using it.",
    "painter": "Ensure the surface is dry before repainting.",
    "cleaning": "Remove loose items before cleaning starts."
}

# -------------------- REQUEST SCHEMA --------------------

class UserQuery(BaseModel):
    problem: str

# -------------------- ROUTES --------------------

# Serve frontend HTML
@app.get("/", response_class=HTMLResponse)
def serve_homepage():
    with open("index.html", "r", encoding="utf-8") as f:
        return f.read()

# Analyze user problem using ML
@app.post("/analyze")
def analyze_problem(query: UserQuery):
    vector = vectorizer.transform([query.problem])
    category = model.predict(vector)[0]

    return {
        "detected_category": category,
        "quick_fix": quick_fixes.get(category, "No quick fix available."),
        "available_workers": workers.get(category, [])
    }
