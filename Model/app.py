from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import torch
from sentence_transformers import SentenceTransformer, util
import os
import google.generativeai as genai


# -------------------------------
# Load dataset
# -------------------------------
data = pd.read_csv("service_intents.csv")
data['text'] = data['text'].str.lower()  # lowercase preprocessing

# -------------------------------
# Load Sentence Transformer
# -------------------------------
model_name = "all-mpnet-base-v2"  # more accurate than MiniLM
model = SentenceTransformer(model_name)

# Compute embeddings for all dataset texts
print("⚡ Generating embeddings for dataset...")
data['embeddings'] = list(model.encode(data['text'], convert_to_tensor=True))
print("✅ Embeddings ready!")



genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
gemini_model = genai.GenerativeModel("models/gemini-2.5-flash")

models = genai.list_models()
for m in models:
    print(m)
# -------------------------------
# FastAPI app
# -------------------------------
app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Input model
class ProblemInput(BaseModel):
    problem: str

# Dummy workers data
workers_db = {
    "plumber": [{"name": "Ramesh", "location": "Mumbai", "rating": 4.7}],
    "electrician": [{"name": "Suresh", "location": "Delhi", "rating": 4.5}],
    "ac_technician": [{"name": "Amit", "location": "Bangalore", "rating": 4.6}],
    "carpenter": [{"name": "Vikram", "location": "Chennai", "rating": 4.8}],
    "appliance_repair": [{"name": "Sunil", "location": "Pune", "rating": 4.4}],
    "glazier": [{"name": "Anil", "location": "Hyderabad", "rating": 4.7}],
    "cleaning": [{"name": "Meena", "location": "Kolkata", "rating": 4.5}],
    "computer_repair": [{"name": "Rohit", "location": "Bangalore", "rating": 4.6}],
    "general_contractor": [{"name": "Deepak", "location": "Delhi", "rating": 4.6}],
    "mobile_repair": [{"name": "Aakash", "location": "Mumbai", "rating": 4.5}],
    "pest_control": [{"name": "Kiran", "location": "Chennai", "rating": 4.7}],
    "home_automation": [{"name": "Ananya", "location": "Bangalore", "rating": 4.6}],
    "solar_technician": [{"name": "Rajat", "location": "Pune", "rating": 4.8}],
    "specialized_services": [{"name": "Sneha", "location": "Delhi", "rating": 4.6}],
    "gas_technician": [{"name": "Manish", "location": "Chennai", "rating": 4.5}],
    "automobile_mechanic": [{"name": "Ajay", "location": "Mumbai", "rating": 4.6}],
    "locksmith": [{"name": "Vikas", "location": "Delhi", "rating": 4.5}],
    "welder": [{"name": "Ravi", "location": "Bangalore", "rating": 4.7}]
}



def generate_quick_fix(problem: str, category: str) -> str:
    print("🧠 Gemini prompt called:", problem, category)
    
    prompt = f"""
You are a home service expert.

User problem:
{problem}

Detected service category:
{category}

Give 2–3 short, safe, temporary quick-fix suggestions.

Rules:
- Do NOT suggest professional repairs
- Do NOT mention complex tools
- Keep advice safe and simple
- Use bullet points
"""

    try:
        response = gemini_model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print("❌ Gemini Error:", e)
        return "Please take basic safety precautions until a professional arrives."


# -------------------------------
# API Endpoint
# -------------------------------
@app.post("/analyze")
async def analyze(problem_input: ProblemInput):
    query = problem_input.problem.lower().strip()
    
    # Embed query
    query_emb = model.encode(query, convert_to_tensor=True)
    
    # Compute cosine similarity
    cos_scores = util.cos_sim(query_emb, torch.stack(data['embeddings'].to_list()))[0]
    
    # Get top-k results
    top_k = 5
    threshold = 0.55
    top_results = torch.topk(cos_scores, k=top_k)
    
    best_category = None
    for score, idx in zip(top_results.values, top_results.indices):
        idx = idx.item()  # convert tensor to integer
        if score >= threshold:
            best_category = data.iloc[idx]['category']
            break
    
    if best_category is None:
        best_category = "general_contractor"
    
    available_workers = workers_db.get(best_category, [])
    quick_fix = generate_quick_fix(problem_input.problem, best_category)


    return {
        "detected_category": best_category,
        "available_workers": available_workers,
        "quick_fix": quick_fix
    }

# -------------------------------
# Root
# -------------------------------
@app.get("/")
def root():
    return {"message": "AI Service Marketplace API is running."}
print("🚀 FastAPI app ready! Run using: uvicorn app:app --reload")