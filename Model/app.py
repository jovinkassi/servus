
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import torch
from sentence_transformers import SentenceTransformer, util
import os
import json
import hashlib
from datetime import datetime
import google.generativeai as genai
import firebase_admin
from firebase_admin import credentials, firestore
from web3 import Web3

# -------------------------------
# Global state (loaded at startup)
# -------------------------------
data = None
model = None
gemini_model = None
db = None
w3 = None
blockchain_account = None
WALLET_ADDRESS = None

def _init_all():
    """Initialize all heavy services - called after server binds port."""
    global data, model, gemini_model, db, w3, blockchain_account, WALLET_ADDRESS

    # Load dataset
    data = pd.read_csv("service_intents.csv")
    data['text'] = data['text'].str.lower()

    # Load Sentence Transformer
    print("⚡ Loading ML model...")
    model_name = "all-mpnet-base-v2"
    model = SentenceTransformer(model_name)

    print("⚡ Generating embeddings for dataset...")
    data['embeddings'] = list(model.encode(data['text'], convert_to_tensor=True))
    print("✅ Embeddings ready!")

    # Gemini
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    gemini_model = genai.GenerativeModel("models/gemini-2.5-flash")

    # Firebase
    if not firebase_admin._apps:
        service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json")

        if service_account_json:
            cred = credentials.Certificate(json.loads(service_account_json))
            firebase_admin.initialize_app(cred)
            print("✅ Firebase initialized with service account from env var")
        elif os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase initialized with service account file")
        else:
            firebase_admin.initialize_app()
            print("⚠️ Firebase initialized without service account")

    db = firestore.client()
    print("✅ Firestore client ready!")

    # Blockchain
    AMOY_RPC_URL = os.getenv("AMOY_RPC_URL", "https://rpc-amoy.polygon.technology")
    BLOCKCHAIN_PRIVATE_KEY = os.getenv("BLOCKCHAIN_PRIVATE_KEY", "")

    w3 = Web3(Web3.HTTPProvider(AMOY_RPC_URL))
    if BLOCKCHAIN_PRIVATE_KEY:
        blockchain_account = w3.eth.account.from_key(BLOCKCHAIN_PRIVATE_KEY)
        WALLET_ADDRESS = blockchain_account.address
        print(f"✅ Blockchain wallet loaded: {WALLET_ADDRESS}")
    else:
        blockchain_account = None
        WALLET_ADDRESS = None
        print("⚠️ No blockchain private key configured")

_ready = False

def _init_in_background():
    """Run heavy init in a background thread so the port binds immediately."""
    global _ready
    _init_all()
    _ready = True
    print("✅ All services ready!")

import threading
threading.Thread(target=_init_in_background, daemon=True).start()

# -------------------------------
# Verhoeff Checksum Algorithm (Aadhaar validation)
# -------------------------------
VERHOEFF_D = [
    [0,1,2,3,4,5,6,7,8,9],
    [1,2,3,4,0,6,7,8,9,5],
    [2,3,4,0,1,7,8,9,5,6],
    [3,4,0,1,2,8,9,5,6,7],
    [4,0,1,2,3,9,5,6,7,8],
    [5,9,8,7,6,0,4,3,2,1],
    [6,5,9,8,7,1,0,4,3,2],
    [7,6,5,9,8,2,1,0,4,3],
    [8,7,6,5,9,3,2,1,0,4],
    [9,8,7,6,5,4,3,2,1,0],
]

VERHOEFF_P = [
    [0,1,2,3,4,5,6,7,8,9],
    [1,5,7,6,2,8,3,0,9,4],
    [5,8,0,3,7,9,6,1,4,2],
    [8,9,1,6,0,4,3,5,2,7],
    [9,4,5,3,1,2,6,8,7,0],
    [4,2,8,6,5,7,3,9,0,1],
    [2,7,9,3,8,0,6,4,1,5],
    [7,0,4,6,9,1,3,2,5,8],
]

VERHOEFF_INV = [0,4,3,2,1,5,6,7,8,9]

def verhoeff_validate(number: str) -> bool:
    """Validate a number using Verhoeff checksum (used for Aadhaar)"""
    try:
        c = 0
        digits = [int(d) for d in reversed(number)]
        for i, digit in enumerate(digits):
            c = VERHOEFF_D[c][VERHOEFF_P[i % 8][digit]]
        return c == 0
    except (ValueError, IndexError):
        return False

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

@app.get("/health")
def health_check():
    return {"status": "ok", "ready": _ready}

# Input model
class ProblemInput(BaseModel):
    problem: str

# Fallback workers data (used if Firestore is empty or unavailable)
workers_db_fallback = {
    "plumber": [{"name": "Ramesh", "location": "Mumbai", "rating": 4.7, "hourly_rate": 45, "experience": "8 years exp."}],
    "electrician": [{"name": "Suresh", "location": "Delhi", "rating": 4.5, "hourly_rate": 50, "experience": "6 years exp."}],
    "ac_technician": [{"name": "Amit", "location": "Bangalore", "rating": 4.6, "hourly_rate": 55, "experience": "5 years exp."}],
    "carpenter": [{"name": "Vikram", "location": "Chennai", "rating": 4.8, "hourly_rate": 40, "experience": "12 years exp."}],
    "appliance_repair": [{"name": "Sunil", "location": "Pune", "rating": 4.4, "hourly_rate": 35, "experience": "4 years exp."}],
    "glazier": [{"name": "Anil", "location": "Hyderabad", "rating": 4.7, "hourly_rate": 42, "experience": "7 years exp."}],
    "cleaning": [{"name": "Meena", "location": "Kolkata", "rating": 4.5, "hourly_rate": 25, "experience": "3 years exp."}],
    "computer_repair": [{"name": "Rohit", "location": "Bangalore", "rating": 4.6, "hourly_rate": 60, "experience": "5 years exp."}],
    "general_contractor": [{"name": "Deepak", "location": "Delhi", "rating": 4.6, "hourly_rate": 55, "experience": "10 years exp."}],
    "mobile_repair": [{"name": "Aakash", "location": "Mumbai", "rating": 4.5, "hourly_rate": 30, "experience": "4 years exp."}],
    "pest_control": [{"name": "Kiran", "location": "Chennai", "rating": 4.7, "hourly_rate": 45, "experience": "6 years exp."}],
    "home_automation": [{"name": "Ananya", "location": "Bangalore", "rating": 4.6, "hourly_rate": 70, "experience": "5 years exp."}],
    "solar_technician": [{"name": "Rajat", "location": "Pune", "rating": 4.8, "hourly_rate": 65, "experience": "7 years exp."}],
    "specialized_services": [{"name": "Sneha", "location": "Delhi", "rating": 4.6, "hourly_rate": 50, "experience": "8 years exp."}],
    "gas_technician": [{"name": "Manish", "location": "Chennai", "rating": 4.5, "hourly_rate": 48, "experience": "6 years exp."}],
    "automobile_mechanic": [{"name": "Ajay", "location": "Mumbai", "rating": 4.6, "hourly_rate": 55, "experience": "9 years exp."}],
    "locksmith": [{"name": "Vikas", "location": "Delhi", "rating": 4.5, "hourly_rate": 35, "experience": "5 years exp."}],
    "welder": [{"name": "Ravi", "location": "Bangalore", "rating": 4.7, "hourly_rate": 50, "experience": "8 years exp."}]
}

# Function to get workers from Firestore
def get_workers_from_firestore(category: str) -> list:
    """Fetch workers from Firestore by category, fallback to hardcoded data if empty"""
    try:
        workers_ref = db.collection('workers').where('category', '==', category)
        docs = workers_ref.stream()

        workers = []
        for doc in docs:
            worker_data = doc.to_dict()
            worker_data['id'] = doc.id
            workers.append(worker_data)

        # If Firestore has workers, return them
        if workers:
            print(f"✅ Found {len(workers)} workers in Firestore for category: {category}")
            return workers

        # Fallback to hardcoded data
        print(f"⚠️ No workers in Firestore for {category}, using fallback data")
        return workers_db_fallback.get(category, [])

    except Exception as e:
        print(f"❌ Error fetching from Firestore: {e}")
        return workers_db_fallback.get(category, [])



def generate_quick_fix(problem: str, category: str) -> str:
    """Generate quick fix suggestions using Gemini"""
    # Hardcoded quick fix to save API calls
    return "• Turn off the main supply and keep the area dry until the professional arrives.\n• Check for visible damage and take photos for reference.\n• Keep children and pets away from the affected area."

    # --- GEMINI API CODE (commented out to save API calls) ---
    # print("🧠 Gemini quick fix called:", problem, category)
    #
    # prompt = f"""
    # You are a home service expert.
    #
    # User problem:
    # {problem}
    #
    # Detected service category:
    # {category}
    #
    # Give 2–3 short, safe, temporary quick-fix suggestions.
    #
    # Rules:
    # - Do NOT suggest professional repairs
    # - Do NOT mention complex tools
    # - Keep advice safe and simple
    # - Use bullet points
    # - Keep response under 100 words
    # """
    #
    # try:
    #     response = gemini_model.generate_content(prompt)
    #     return response.text.strip()
    # except Exception as e:
    #     print("❌ Gemini Error:", e)
    #     return "Turn off the main supply and keep the area dry until the professional arrives."


def get_worker_reviews(worker_id: str) -> list:
    """Fetch completed booking reviews for a worker from Firestore"""
    try:
        reviews_ref = db.collection('bookings').where('workerId', '==', worker_id).where('status', '==', 'completed')
        docs = reviews_ref.stream()

        reviews = []
        for doc in docs:
            booking_data = doc.to_dict()
            if booking_data.get('rating') and booking_data.get('rating') > 0:
                reviews.append({
                    'rating': booking_data.get('rating', 0),
                    'review': booking_data.get('review', ''),
                    'customerQuery': booking_data.get('customerQuery', '')
                })

        return reviews
    except Exception as e:
        print(f"❌ Error fetching reviews: {e}")
        return []


def generate_review_summary(worker_name: str, reviews: list) -> str:
    """Generate AI summary of worker reviews using Gemini"""
    if not reviews:
        return ""

    # Hardcoded review summary to save API calls
    avg_rating = sum(r.get('rating', 0) for r in reviews) / len(reviews)
    return f"Customers consistently praise {worker_name} for professional service and quality work. With an average rating of {avg_rating:.1f}/5, clients appreciate the punctuality and attention to detail."

    # --- GEMINI API CODE (commented out to save API calls) ---
    # # Build review text for Gemini
    # review_texts = []
    # for r in reviews:
    #     if r.get('review'):
    #         review_texts.append(f"Rating: {r['rating']}/5 - \"{r['review']}\"")
    #     else:
    #         review_texts.append(f"Rating: {r['rating']}/5")
    #
    # if not review_texts:
    #     return ""
    #
    # reviews_combined = "\n".join(review_texts[:10])  # Limit to 10 reviews
    #
    # prompt = f"""
    # Summarize these customer reviews for {worker_name} in 1-2 sentences.
    # Focus on key strengths, work quality, and customer satisfaction.
    # Be concise and professional. Do not use bullet points.
    #
    # Reviews:
    # {reviews_combined}
    #
    # Summary:
    # """
    #
    # try:
    #     response = gemini_model.generate_content(prompt)
    #     return response.text.strip()
    # except Exception as e:
    #     print(f"❌ Gemini review summary error: {e}")
    #     return ""


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

    available_workers = get_workers_from_firestore(best_category)
    quick_fix = generate_quick_fix(problem_input.problem, best_category)

    # Add AI review summaries for each worker
    for worker in available_workers:
        worker_id = worker.get('id', '')
        if worker_id:
            reviews = get_worker_reviews(worker_id)
            if reviews:
                worker['review_count'] = len(reviews)
                worker['ai_review_summary'] = generate_review_summary(worker.get('name', 'Worker'), reviews)
            else:
                worker['review_count'] = 0
                worker['ai_review_summary'] = ''
        else:
            worker['review_count'] = 0
            worker['ai_review_summary'] = ''

    return {
        "detected_category": best_category,
        "available_workers": available_workers,
        "quick_fix": quick_fix
    }

# -------------------------------
# Seed workers endpoint (run once to populate Firestore)
# -------------------------------
@app.post("/seed-workers")
async def seed_workers():
    """Seed initial workers data to Firestore"""
    try:
        # Check if workers collection already has data
        existing = db.collection('workers').limit(1).get()
        if len(existing) > 0:
            return {"message": "Workers collection already has data", "seeded": False}

        # Seed all workers from fallback data
        count = 0
        for category, workers in workers_db_fallback.items():
            for worker in workers:
                worker_data = {**worker, "category": category, "verified": True}
                db.collection('workers').add(worker_data)
                count += 1

        return {"message": f"Successfully seeded {count} workers to Firestore", "seeded": True}
    except Exception as e:
        return {"error": str(e), "seeded": False}

# -------------------------------
# Worker Endpoints
# -------------------------------

class WorkerRegistrationInput(BaseModel):
    name: str
    phone: str
    location: str
    latitude: float = None
    longitude: float = None
    category: str
    experience: str
    hourly_rate: float

class JobActionInput(BaseModel):
    job_id: str
    action: str  # 'accept' or 'reject'
    reason: str = ""

class AadhaarVerificationInput(BaseModel):
    aadhaar_number: str


# -------------------------------
# Notification Functions (Firestore-based for web compatibility)
# -------------------------------
def create_notification(user_id: str, user_type: str, title: str, body: str, notification_type: str, job_id: str = None):
    """Create a notification in Firestore"""
    try:
        collection = 'worker_notifications' if user_type == 'worker' else 'customer_notifications'

        notification_data = {
            'title': title,
            'body': body,
            'type': notification_type,
            'jobId': job_id,
            'read': False,
            'createdAt': firestore.SERVER_TIMESTAMP
        }

        # Add to user's notifications subcollection
        db.collection(collection).document(user_id).collection('notifications').add(notification_data)
        print(f"✅ Notification created for {user_type}: {user_id}")
        return True
    except Exception as e:
        print(f"❌ Error creating notification: {e}")
        return False


def notify_worker_new_booking(worker_id: str, booking_data: dict):
    """Notify worker about a new booking"""
    try:
        customer_query = booking_data.get('customerQuery', 'New service request')
        body = f"{customer_query[:100]}..." if len(customer_query) > 100 else customer_query

        return create_notification(
            user_id=worker_id,
            user_type='worker',
            title="New Job Request! 🔔",
            body=body,
            notification_type='new_booking',
            job_id=booking_data.get('id', '')
        )
    except Exception as e:
        print(f"❌ Error notifying worker: {e}")
        return False


def notify_customer_job_status(booking_id: str, status: str, worker_name: str = "Worker"):
    """Notify customer about job status change"""
    try:
        # Get booking to find customer info
        booking_doc = db.collection('bookings').document(booking_id).get()
        if not booking_doc.exists:
            print(f"⚠️ Booking not found: {booking_id}")
            return False

        booking = booking_doc.to_dict()
        customer_id = booking.get('customerId')

        if not customer_id:
            print(f"⚠️ No customer ID for booking {booking_id}")
            return False

        # Determine notification content based on status
        if status == 'accepted':
            title = "Job Accepted! ✅"
            body = f"{worker_name} has accepted your service request and will arrive as scheduled."
        elif status == 'rejected':
            title = "Job Declined"
            body = f"Unfortunately, {worker_name} is unable to take your job. Please book another provider."
        elif status == 'in_progress':
            title = "Work Started! 🔧"
            body = f"{worker_name} has started working on your service request."
        elif status == 'completed':
            title = "Job Completed! 🎉"
            body = f"{worker_name} has completed the job. Please rate your experience."
        else:
            return False

        return create_notification(
            user_id=customer_id,
            user_type='customer',
            title=title,
            body=body,
            notification_type='job_status_update',
            job_id=booking_id
        )
    except Exception as e:
        print(f"❌ Error notifying customer: {e}")
        return False

@app.post("/worker/register")
async def register_worker(worker_input: WorkerRegistrationInput):
    """Register a new worker"""
    try:
        # Check if phone number already exists
        existing = db.collection('workers').where('phone', '==', worker_input.phone).limit(1).get()
        if len(existing) > 0:
            return {"success": False, "error": "Phone number already registered"}

        # Create worker document
        worker_data = {
            "name": worker_input.name,
            "phone": worker_input.phone,
            "location": worker_input.location,
            "latitude": worker_input.latitude,
            "longitude": worker_input.longitude,
            "category": worker_input.category,
            "experience": worker_input.experience,
            "hourly_rate": worker_input.hourly_rate,
            "rating": 0,
            "verified": False,
            "createdAt": firestore.SERVER_TIMESTAMP
        }

        # Add to Firestore
        doc_ref = db.collection('workers').add(worker_data)
        worker_id = doc_ref[1].id

        print(f"✅ New worker registered: {worker_input.name} ({worker_id})")

        return {
            "success": True,
            "worker_id": worker_id,
            "message": "Worker registered successfully"
        }
    except Exception as e:
        print(f"❌ Error registering worker: {e}")
        return {"success": False, "error": str(e)}


@app.post("/worker/login")
async def login_worker(phone: str):
    """Login worker by phone number"""
    try:
        workers = db.collection('workers').where('phone', '==', phone).limit(1).get()

        if len(workers) == 0:
            return {"success": False, "error": "Worker not found", "registered": False}

        worker_doc = workers[0]
        worker_data = worker_doc.to_dict()
        worker_data['id'] = worker_doc.id

        return {
            "success": True,
            "registered": True,
            "worker_id": worker_doc.id,
            "worker": worker_data
        }
    except Exception as e:
        print(f"❌ Error logging in worker: {e}")
        return {"success": False, "error": str(e)}

@app.get("/worker/{worker_id}/profile")
async def get_worker_profile(worker_id: str):
    """Get worker profile and stats from Firestore"""
    try:
        # Get worker document
        worker_doc = db.collection('workers').document(worker_id).get()

        if not worker_doc.exists:
            return {"success": False, "error": "Worker not found"}

        worker_data = worker_doc.to_dict()
        worker_data['id'] = worker_id

        # Get worker's bookings to calculate stats
        bookings_ref = db.collection('bookings').where('workerId', '==', worker_id)
        bookings = list(bookings_ref.stream())

        # Calculate stats
        total_jobs = len(bookings)
        completed_jobs = len([b for b in bookings if b.to_dict().get('status') == 'completed'])
        pending_jobs = len([b for b in bookings if b.to_dict().get('status') == 'pending'])
        active_jobs = len([b for b in bookings if b.to_dict().get('status') in ['accepted', 'in_progress']])

        # Calculate total earnings from completed jobs
        total_earnings = sum(
            b.to_dict().get('totalPrice', 0)
            for b in bookings
            if b.to_dict().get('status') == 'completed'
        )

        # Calculate average rating from completed bookings with ratings
        ratings = [b.to_dict().get('rating', 0) for b in bookings if b.to_dict().get('rating', 0) > 0]
        avg_rating = sum(ratings) / len(ratings) if ratings else worker_data.get('rating', 0)

        return {
            "success": True,
            "worker": worker_data,
            "stats": {
                "total_jobs": total_jobs,
                "completed_jobs": completed_jobs,
                "pending_jobs": pending_jobs,
                "active_jobs": active_jobs,
                "total_earnings": total_earnings,
                "rating": round(avg_rating, 1)
            }
        }
    except Exception as e:
        print(f"❌ Error fetching worker profile: {e}")
        return {"success": False, "error": str(e)}


@app.get("/worker/{worker_id}/jobs")
async def get_worker_jobs(worker_id: str, status: str = None):
    """Get jobs/bookings for a worker, optionally filtered by status"""
    try:
        # Query bookings for this worker
        bookings_ref = db.collection('bookings').where('workerId', '==', worker_id)

        bookings = []
        for doc in bookings_ref.stream():
            booking_data = doc.to_dict()
            booking_data['id'] = doc.id

            # Filter by status if provided
            if status:
                if booking_data.get('status') == status:
                    bookings.append(booking_data)
            else:
                bookings.append(booking_data)

        # Sort by createdAt (most recent first)
        bookings.sort(key=lambda x: x.get('createdAt', ''), reverse=True)

        return {
            "success": True,
            "jobs": bookings,
            "count": len(bookings)
        }
    except Exception as e:
        print(f"❌ Error fetching worker jobs: {e}")
        return {"success": False, "error": str(e), "jobs": []}


@app.post("/worker/{worker_id}/job-action")
async def worker_job_action(worker_id: str, action_input: JobActionInput):
    """Accept or reject a job"""
    try:
        job_id = action_input.job_id
        action = action_input.action

        # Get the booking document
        booking_ref = db.collection('bookings').document(job_id)
        booking_doc = booking_ref.get()

        if not booking_doc.exists:
            return {"success": False, "error": "Booking not found"}

        booking_data = booking_doc.to_dict()

        # Verify this booking belongs to this worker
        if booking_data.get('workerId') != worker_id:
            return {"success": False, "error": "Unauthorized - booking belongs to different worker"}

        # Get worker name for notifications
        worker_doc = db.collection('workers').document(worker_id).get()
        worker_name = worker_doc.to_dict().get('name', 'Worker') if worker_doc.exists else 'Worker'

        if action == 'accept':
            booking_ref.update({
                'status': 'accepted',
                'acceptedAt': firestore.SERVER_TIMESTAMP
            })
            # Notify customer
            notify_customer_job_status(job_id, 'accepted', worker_name)
            return {"success": True, "message": "Job accepted successfully"}

        elif action == 'reject':
            booking_ref.update({
                'status': 'rejected',
                'rejectedAt': firestore.SERVER_TIMESTAMP,
                'rejectionReason': action_input.reason
            })
            # Notify customer
            notify_customer_job_status(job_id, 'rejected', worker_name)
            return {"success": True, "message": "Job rejected"}

        elif action == 'complete':
            booking_ref.update({
                'status': 'awaiting_confirmation',
                'workCompletedAt': firestore.SERVER_TIMESTAMP
            })
            # Notify customer
            notify_customer_job_status(job_id, 'awaiting_confirmation', worker_name)
            return {"success": True, "message": "Job marked as completed, awaiting customer confirmation"}

        elif action == 'start':
            booking_ref.update({
                'status': 'in_progress',
                'startedAt': firestore.SERVER_TIMESTAMP
            })
            # Notify customer
            notify_customer_job_status(job_id, 'in_progress', worker_name)
            return {"success": True, "message": "Job started"}

        else:
            return {"success": False, "error": f"Unknown action: {action}"}

    except Exception as e:
        print(f"❌ Error processing job action: {e}")
        return {"success": False, "error": str(e)}


@app.get("/workers/category/{category}")
async def get_workers_by_category(category: str):
    """Get all workers in a specific category"""
    try:
        workers = get_workers_from_firestore(category)
        return {
            "success": True,
            "workers": workers,
            "count": len(workers)
        }
    except Exception as e:
        return {"success": False, "error": str(e), "workers": []}


# -------------------------------
# Booking Notification Endpoint
# -------------------------------
class BookingNotificationInput(BaseModel):
    booking_id: str
    worker_id: str

@app.post("/notify/new-booking")
async def notify_new_booking(input: BookingNotificationInput):
    """Notify worker about a new booking - called after booking is created"""
    try:
        # Get booking data
        booking_doc = db.collection('bookings').document(input.booking_id).get()
        if not booking_doc.exists:
            return {"success": False, "error": "Booking not found"}

        booking_data = booking_doc.to_dict()
        booking_data['id'] = input.booking_id

        # Send notification to worker
        result = notify_worker_new_booking(input.worker_id, booking_data)

        return {
            "success": result,
            "message": "Notification sent" if result else "Failed to send notification"
        }
    except Exception as e:
        print(f"❌ Error in notify_new_booking: {e}")
        return {"success": False, "error": str(e)}


# -------------------------------
# Nearby Workers Endpoint
# -------------------------------
import math

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two coordinates using Haversine formula (returns km)"""
    R = 6371  # Earth's radius in km

    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)

    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    return R * c

@app.get("/workers/nearby")
async def get_nearby_workers(lat: float = None, lng: float = None, radius: float = 50, category: str = None):
    """Get all workers with location data, optionally filtered by distance and category"""
    try:
        # Build query
        if category:
            workers_ref = db.collection('workers').where('category', '==', category)
        else:
            workers_ref = db.collection('workers')

        docs = workers_ref.stream()

        workers = []
        for doc in docs:
            worker_data = doc.to_dict()
            worker_data['id'] = doc.id

            # Calculate distance if user location provided
            if lat is not None and lng is not None:
                worker_lat = worker_data.get('latitude')
                worker_lng = worker_data.get('longitude')

                if worker_lat is not None and worker_lng is not None:
                    distance = calculate_distance(lat, lng, worker_lat, worker_lng)
                    worker_data['distance'] = f"{distance:.1f} km"
                    worker_data['distance_km'] = distance

                    # Only include workers within radius
                    if distance > radius:
                        continue
                else:
                    # Worker has no location, include with unknown distance
                    worker_data['distance'] = "Unknown"
                    worker_data['distance_km'] = 999
            else:
                # No user location provided, include all workers
                worker_data['distance'] = "N/A"
                worker_data['distance_km'] = 0

            workers.append(worker_data)

        # Sort by distance
        workers.sort(key=lambda x: x.get('distance_km', 999))

        print(f"✅ Found {len(workers)} nearby workers")
        return {
            "success": True,
            "workers": workers,
            "count": len(workers)
        }
    except Exception as e:
        print(f"❌ Error fetching nearby workers: {e}")
        return {"success": False, "error": str(e), "workers": []}


# -------------------------------
# Aadhaar Blockchain Verification Endpoint
# -------------------------------
@app.post("/worker/{worker_id}/verify-aadhaar")
async def verify_aadhaar(worker_id: str, input: AadhaarVerificationInput):
    """Verify worker's Aadhaar number and record hash on Polygon Amoy blockchain"""
    try:
        aadhaar = input.aadhaar_number.strip().replace(" ", "")

        # Validate format: must be exactly 12 digits
        if not aadhaar.isdigit() or len(aadhaar) != 12:
            return {"success": False, "error": "Aadhaar number must be exactly 12 digits"}

        # Verhoeff checksum validation
        if not verhoeff_validate(aadhaar):
            return {"success": False, "error": "Invalid Aadhaar number (checksum failed)"}

        # Check worker exists
        worker_doc = db.collection('workers').document(worker_id).get()
        if not worker_doc.exists:
            return {"success": False, "error": "Worker not found"}

        worker_data = worker_doc.to_dict()
        if worker_data.get('verified') == True:
            return {"success": False, "error": "Worker is already verified"}

        # Check blockchain wallet is configured
        if not blockchain_account or not WALLET_ADDRESS:
            return {"success": False, "error": "Blockchain verification is not configured on server"}

        # Create verification hash: SHA-256(workerId:aadhaar:timestamp)
        timestamp = datetime.utcnow().isoformat()
        raw_string = f"{worker_id}:{aadhaar}:{timestamp}"
        verification_hash = hashlib.sha256(raw_string.encode()).hexdigest()

        # Send 0-value self-transaction on Polygon Amoy with hash in data field
        try:
            nonce = w3.eth.get_transaction_count(WALLET_ADDRESS)
            tx = {
                'nonce': nonce,
                'to': WALLET_ADDRESS,  # self-transaction
                'value': 0,
                'gas': 25000,
                'gasPrice': w3.to_wei('30', 'gwei'),
                'chainId': 80002,  # Polygon Amoy
                'data': w3.to_bytes(text=verification_hash),
            }

            signed_tx = w3.eth.account.sign_transaction(tx, BLOCKCHAIN_PRIVATE_KEY)
            tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            tx_hash_hex = tx_hash.hex()

            print(f"✅ Blockchain tx sent: {tx_hash_hex}")

        except Exception as e:
            print(f"❌ Blockchain transaction failed: {e}")
            return {"success": False, "error": f"Blockchain transaction failed: {str(e)}"}

        # Update worker document in Firestore
        db.collection('workers').document(worker_id).update({
            'verified': True,
            'blockchainTxHash': tx_hash_hex,
            'blockchainNetwork': 'Polygon Amoy Testnet',
            'verificationHash': verification_hash,
            'verifiedAt': timestamp,
        })

        print(f"✅ Worker {worker_id} verified on blockchain: {tx_hash_hex}")

        return {
            "success": True,
            "message": "Aadhaar verified and recorded on blockchain",
            "tx_hash": tx_hash_hex,
            "verification_hash": verification_hash,
            "network": "Polygon Amoy Testnet",
            "explorer_url": f"https://amoy.polygonscan.com/tx/0x{tx_hash_hex}",
        }

    except Exception as e:
        print(f"❌ Verification error: {e}")
        return {"success": False, "error": str(e)}


# -------------------------------
# Config Endpoint (for Flutter app to get API keys)
# -------------------------------
@app.get("/config/maps-api-key")
def get_maps_api_key():
    """Return Google Maps API key for Flutter app"""
    api_key = os.getenv("GOOGLE_MAPS_API_KEY", "")
    return {"api_key": api_key}

# -------------------------------
# Root
# -------------------------------
@app.get("/")
def root():
    return {"message": "AI Service Marketplace API is running."}
print("🚀 FastAPI app ready! Run using: uvicorn app:app --reload")