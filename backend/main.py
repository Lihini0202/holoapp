from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client
from openai import OpenAI
from dotenv import load_dotenv
from celery.result import AsyncResult
import os
import json
import hashlib
import ssl  

# Celery tasks
from tasks import celery_app, analyze_screenshot_task, analyze_text_task

# --- Configuration -----------------------------------------------------------

load_dotenv()


# Redis URL from environment
redis_url = os.getenv("REDIS_URL")

ssl_conf = {
    'ssl_cert_reqs': ssl.CERT_NONE
}

celery_app.conf.update(
    broker_url=redis_url,          # Force the correct URL
    result_backend=redis_url,      # Force the correct URL
    broker_use_ssl=ssl_conf,       # Force SSL
    redis_backend_use_ssl=ssl_conf,
    broker_connection_retry_on_startup=True,
    worker_concurrency=4
)
# -------------------------------------------------------------

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

app = FastAPI()

# --- Health check ------------------------------------------------------------
@app.get("/")
def home():
    return {
        "status": "Online",
        "message": "Holo Backend is Running!",
        "docs_url": "/docs"
    }

supabase: Client = None
ai_client = None

try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Database Configured (API Side)!")
    else:
        print("Supabase Keys Missing in .env")

    if OPENROUTER_API_KEY:
        ai_client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=OPENROUTER_API_KEY,
        )
        print("AI Coach Configured!")
    else:
        print("OpenRouter Key Missing in .env")

except Exception as e:
    print(f"Config Error: {e}")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Helpers -----------------------------------------------------------------

def get_user_hash(name: str, age: str = "0", location: str = "unknown"):
    unique_string = f"{name.lower().strip()}|{age.strip()}|{location.lower().strip()}"
    return hashlib.sha256(unique_string.encode()).hexdigest()

# --- Asynchronous analysis endpoints ------------------------------------------

class TextSubmission(BaseModel):
    partner_name: str
    chat_text: str
    age: str = "0"
    location: str = "unknown"
    user_id: str         


@app.post("/analyze-screenshot")
async def analyze_screenshot(
    file: UploadFile = File(...),
    partner_name: str = Form(...),
    age: str = Form("0"),
    location: str = Form("unknown"),
    user_id: str = Form(...)
):
    """
    Sends screenshot + user_id to Celery worker.
    """
    try:
        content = await file.read()

        task = analyze_screenshot_task.delay(
            content,
            partner_name,
            age,
            location,
            user_id  
        )

        return {
            "status": "Processing",
            "task_id": task.id,
            "message": "Analysis started."
        }
    except Exception as e:
        return {"error": str(e)}


@app.post("/analyze-text")
def analyze_text_endpoint(submission: TextSubmission):
    """
    Sends chat text + user_id to Celery worker.
    """
    try:
        task = analyze_text_task.delay(
            submission.chat_text,
            submission.partner_name,
            submission.age,
            submission.location,
            submission.user_id 
        )

        return {
            "status": "Processing",
            "task_id": task.id
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/status/{task_id}")
def get_task_status(task_id: str):
    task_result = AsyncResult(task_id, app=celery_app)

    if task_result.ready():
        if task_result.successful():
            return {
                "status": "Completed",
                "result": task_result.result
            }
        else:
            return {
                "status": "Failed",
                "error": str(task_result.result)
            }
    else:
        return {"status": "Processing"}

# --- Synchronous endpoints ----------------------------------------------------

@app.post("/search-ghost")
def search_ghost(
    name: str = Form(...),
    age: str = Form("0"),
    location: str = Form("unknown")
):
    if not supabase:
        return {"status": "Error", "error": "Database offline"}

    try:
        user_hash = get_user_hash(name, age, location)
        response = supabase.table("profiles").select("*").eq("user_hash", user_hash).execute()

        def describe(p):
            """Human-readable identity line. Only fields that exist are included."""
            bits = []
            if p.get('age'):
                bits.append(f"age {p['age']}")
            if p.get('country') and p['country'] != 'unknown':
                bits.append(p['country'])
            return f"{p.get('first_name', 'Unknown')}" + (f" ({', '.join(bits)})" if bits else "")

        def confidence(n):
            """A risk figure built on a handful of reports is not evidence of much."""
            if n >= 10:
                return "high"
            return "moderate" if n >= 5 else "low"

        if response.data:
            profile = response.data[0]
            n = profile['total_reports']
            return {
                "status": "Found",
                "reports": n,
                "risk_score": profile['avg_risk_score'],
                "match_type": "Exact",
                "confidence": confidence(n),
                "note": (f"Exact match on name, age and location. Based on {n} "
                         f"{'report' if n == 1 else 'reports'}."
                         + ("" if n >= 5 else " Too few reports to be reliable."))
            }

        # The exact hash requires name, age and location to agree. Where it does not,
        # the individual fields still carry information and are used to rank candidates:
        # agreement on name, age and location is far stronger evidence of identity than
        # agreement on name alone.
        clean_name = name.strip()
        candidates = (supabase.table("profiles").select("*")
                      .ilike("first_name", clean_name).execute().data)

        if candidates:
            try:
                want_age = int(age)
            except (TypeError, ValueError):
                want_age = None
            want_loc = (location or "").strip().lower()

            def grade(p):
                """Score a candidate by which identifying fields agree."""
                pts, matched = 0, ["name"]
                p_age = p.get('age')
                if want_age and p_age and abs(int(p_age) - want_age) <= 2:
                    pts += 2
                    matched.append("age")
                p_loc = (p.get('country') or "").strip().lower()
                if want_loc and want_loc not in ("", "unknown") and p_loc == want_loc:
                    pts += 2
                    matched.append("location")
                return pts, matched

            graded = [(grade(p)[0], grade(p)[1], p) for p in candidates]
            graded.sort(key=lambda t: (t[0], t[2].get('total_reports', 0)), reverse=True)
            pts, matched, best_match = graded[0]

            n = best_match['total_reports']
            others = len(candidates) - 1
            same_grade = sum(1 for g, _, _ in graded if g == pts) - 1

            # Confidence reflects both how much of the identity agreed and how many
            # reports sit behind the score.
            if pts >= 4 and n >= 5:
                conf = "high"
            elif pts >= 4 or (pts >= 2 and n >= 5):
                conf = "moderate"
            else:
                conf = "low"

            caveat = {
                "high": "",
                "moderate": " This is a probable match, though not confirmed.",
                "low": " This may not be the same person.",
            }[conf]

            return {
                "status": "Found (Partial Match)",
                "reports": n,
                "risk_score": best_match['avg_risk_score'],
                "match_type": "+".join(matched),
                "confidence": conf,
                "note": (
                    f"Matched on {' and '.join(matched)}. Showing {describe(best_match)}, "
                    f"based on {n} {'report' if n == 1 else 'reports'}."
                    + (f" {same_grade} other profile{'s' if same_grade != 1 else ''} "
                       f"match{'' if same_grade != 1 else 'es'} equally well."
                       if same_grade else "")
                    + (f" {others} other profile{'s' if others != 1 else ''} "
                       f"{'share' if others != 1 else 'shares'} this name."
                       if others and not same_grade else "")
                    + caveat
                )
            }

        # "Clean" implied this person had been checked and found safe. Nothing of the
        # sort has happened: no other user has reported them. Most people will never
        # appear here, so absence of a record carries almost no information and must
        # not be presented as reassurance.
        return {
            "status": "No Records Found",
            "reports": 0,
            "risk_score": None,
            "confidence": "none",
            "note": ("Nobody has analysed a conversation with this person. That is the "
                     "normal result for most searches and does not mean they are safe - "
                     "it means we have no information either way."),
        }

    except Exception as e:
        return {"status": "Error", "error": str(e)}


@app.post("/coach-reply")
async def coach_reply(draft: str = Form(...)):
    """Rewrite a draft message to be less likely to end a conversation.

    The advice is grounded in the same signals the ghosting model uses: whether the
    message gives the other person something to reply to, and whether it matches their
    level of investment rather than overshooting it.
    """
    if ai_client is None:
        return {
            "risk_increase": None,
            "risk_band": "unknown",
            "advice": ["Coaching is unavailable - the AI service is not configured."],
            "improved_draft": draft,
        }

    system_prompt = """You are a dating communication coach. You rewrite a single draft
message so it is more likely to get a reply, and explain briefly why.

What raises the risk of no reply:
- No question, so there is nothing to respond to
- Much longer or much more emotionally intense than the stage of the conversation
- Pressure, guilt, or repeated follow-ups
- Generic openers that could be sent to anyone

What lowers it:
- One specific, easy question
- Matching their length and tone
- Referring to something they actually said
- Warmth without pressure

Return JSON only, in exactly this shape:
{"risk_score": <0.0-1.0>, "advice": ["<tip>", "<tip>"], "improved_draft": "<rewrite>"}

Rules:
- risk_score is the chance this draft gets no reply. 0.1 is a safe message, 0.9 is very risky.
- advice: one or two short sentences, second person, concrete. No preamble.
- improved_draft: keep the sender's voice and language. Similar length. Do not invent
  facts about either person. If the draft is already good, return it close to unchanged.

Example
Draft: "hey"
{"risk_score": 0.7, "advice": ["A bare greeting gives them nothing to answer.",
"Ask about something specific from their profile or your last chat."],
"improved_draft": "Hey! How did that hike you mentioned end up going?"}

Example
Draft: "I have been thinking about you all week and I really think we have something special"
{"risk_score": 0.8, "advice": ["This is a lot of intensity for an early conversation and can feel like pressure.",
"Say something warm but lighter, and leave them room to reply."],
"improved_draft": "Been thinking about our chat this week - it stuck with me. How has your week been?"}"""

    try:
        completion = ai_client.chat.completions.create(
            model="google/gemini-2.5-flash-lite",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Draft: {draft}"},
            ],
            response_format={"type": "json_object"},
            temperature=0.4,
            max_tokens=400,
        )
        data = json.loads(completion.choices[0].message.content)

        # The model is instructed to return a number, but nothing guarantees it does.
        try:
            score = float(data.get("risk_score", 0.5))
        except (TypeError, ValueError):
            score = 0.5
        score = min(max(score, 0.0), 1.0)

        advice = data.get("advice", [])
        if isinstance(advice, str):
            advice = [advice]
        advice = [str(a).strip() for a in advice if str(a).strip()][:3]

        improved = str(data.get("improved_draft") or draft).strip()

        return {
            "risk_increase": round(score, 2),
            "risk_band": "HIGH" if score >= 0.66 else ("MEDIUM" if score >= 0.33 else "LOW"),
            "advice": advice or ["Add one specific question they can answer."],
            "improved_draft": improved,
        }

    except Exception as e:
        # The user should never see a stack trace or a provider error code.
        print(f"Coach error: {e}")
        return {
            "risk_increase": None,
            "risk_band": "unknown",
            "advice": ["Coaching is temporarily unavailable. Your draft is unchanged."],
            "improved_draft": draft,
        }


@app.post("/admin/request-outcomes")
def trigger_outcome_requests(limit: int = 200):
    """Manually run the outcome follow-up.

    Useful for testing and for deployments without a Celery beat process running.
    """
    from tasks import request_outcomes_task
    task = request_outcomes_task.delay(limit)
    return {"status": "Queued", "task_id": task.id}
