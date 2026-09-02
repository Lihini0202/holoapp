from celery import Celery
from google.cloud import vision
from supabase import create_client, Client
from dotenv import load_dotenv
import joblib
import pandas as pd
import re
import os
import hashlib
import ssl  

# --- Configuration -----------------------------------------------------------
load_dotenv()

# REDIS URL from environment
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")

ssl_conf = {
    'ssl_cert_reqs': ssl.CERT_NONE
}


# Initialize Celery with the CORRECT URL immediately
celery_app = Celery(
    "holo_worker",
    broker=redis_url,
    backend=redis_url
)

# Apply SSL & Worker Settings
celery_app.conf.update(
    result_expires=3600,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    broker_use_ssl=ssl_conf,        # <--- Added SSL
    redis_backend_use_ssl=ssl_conf, # <--- Added SSL
    worker_pool='solo' 
)

# Database Setup
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = None

try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ Worker DB Connected")
except Exception as e:
    print(f"⚠️ Worker DB Error: {e}")

# --- Chat ghosting model -------------------------------------------------------
# Logistic regression over three conversation signals, held-out ROC-AUC 0.9154.
# Training and evaluation are documented in Ghosting_Prediction_Complete.ipynb.
#
# The signals are independent of transcript length: whether the other party's replies
# are shorter than the user's, whether they ask questions back, and whether their reply
# speed is consistent. Message count is excluded by design. In the training data a
# faded conversation averaged 10 messages against 34 for one that continued, so a model
# using it would score any short excerpt as a dying conversation.
chat_model = None
chat_columns = None
chat_meta = None

try:
    model_dir = os.path.dirname(os.path.abspath(__file__))
    chat_path = os.path.join(model_dir, 'chat_ghosting_model.pkl')
    if os.path.exists(chat_path):
        chat_model = joblib.load(chat_path)
        chat_columns = joblib.load(os.path.join(model_dir, 'chat_model_columns.pkl'))
        chat_meta = joblib.load(os.path.join(model_dir, 'chat_model_metadata.pkl'))
        print(f"Chat model loaded OK (AUC {chat_meta.get('auc', 0):.4f})")
    else:
        print("chat_ghosting_model.pkl not found - heuristic scoring only")
except Exception as e:
    print(f"Chat model load failed, heuristic scoring only: {e}")
    chat_model = None

# --- Helpers -----------------------------------------------------------------

def get_user_hash(name: str, age: str = "0", location: str = "unknown"):
    """Creates a unique signature using Name + Age + Location."""
    unique_string = f"{name.lower().strip()}|{age.strip()}|{location.lower().strip()}"
    return hashlib.sha256(unique_string.encode()).hexdigest()

def get_risk_label(score):
    """Band the score rather than reporting it as a percentage.

    Calibration was measured at a largest-bin gap of 0.0506 against a 0.05 tolerance,
    so the ordering of scores is reliable but individual probabilities are not accurate
    enough to display as a number.

    The middle band is not called "medium": on held-out data the conversations falling
    in it were ghosted 62.7% of the time, which is far closer to the high band (91.9%)
    than to the low one (7.9%). Labelling it "medium" would understate the risk.
    """
    if score < 0.33:
        return "Looks healthy"
    elif score < 0.66:
        return "Some warning signs"
    else:
        return "Strong signs of fading"

def analyze_text_metrics(chat_text: str):
    lines = [line for line in chat_text.split('\n') if line.strip()]
    msg_count = len(lines)
    total_chars = len(chat_text) if len(chat_text) > 0 else 1
    emoji_count = sum(1 for char in chat_text if ord(char) > 10000)
    emoji_rate = emoji_count / total_chars

    avg_msg_len = total_chars / max(msg_count, 1)
    question_count = chat_text.count('?')
    short_replies = sum(1 for line in lines if len(line.strip()) < 10)
    short_reply_ratio = short_replies / max(msg_count, 1)

    return {
        'msg_count': msg_count,
        'emoji_rate': emoji_rate,
        'avg_msg_len': avg_msg_len,
        'question_count': question_count,
        'short_reply_ratio': short_reply_ratio,
    }

# --- Chat model scoring --------------------------------------------------------

# Thresholds mapping measured quantities onto the survey's ordinal scales. These are
# calibration choices rather than fitted values: the survey asked respondents to judge
# relative length, whereas the application must measure it. Refit them once the
# Validate Predictions screen has collected enough real outcomes.
LENGTH_BANDS = [(0.50, 0), (0.80, 1), (1.25, 2), (2.00, 3)]
QUESTION_BANDS = [(0.001, 0), (0.12, 1), (0.30, 2)]
SPEED_ORDER = ['No', 'Not sure', 'Yes']

_SPEAKER = re.compile(r'^\s*([A-Za-z][\w ]{0,18}):\s*(.+)$')


def split_speakers(transcript: str):
    """Split a transcript into (their messages, the user's messages).

    Handles two conventions: 'Name: message' lines, and the indentation style some OCR
    output produces, where the other party's messages are indented. The first speaker
    encountered is assumed to be the app user.
    """
    lines = [l for l in transcript.split('\n') if l.strip()]
    if not lines:
        return [], []

    labelled = [_SPEAKER.match(l) for l in lines]
    if sum(m is not None for m in labelled) >= max(2, len(lines) * 0.6):
        first = next(m.group(1).strip().lower() for m in labelled if m)
        them = [m.group(2).strip() for m in labelled
                if m and m.group(1).strip().lower() != first]
        you = [m.group(2).strip() for m in labelled
               if m and m.group(1).strip().lower() == first]
        return them, you

    them = [l.strip() for l in lines if l.startswith((' ', '\t'))]
    you = [l.strip() for l in lines if not l.startswith((' ', '\t'))]
    return them, you


def _band(value, bands, top):
    for threshold, rank in bands:
        if value < threshold:
            return rank
    return top


def score_chat_with_model(chat_text: str, reply_speed: str = 'Not sure'):
    """Score a transcript with the trained model.

    Returns None when the model is unavailable or the other party cannot be identified,
    so the caller can fall back to the heuristic rather than fail.
    """
    if chat_model is None:
        return None
    try:
        them, you = split_speakers(chat_text)
        if not them:
            return None

        their_len = sum(len(m) for m in them) / len(them)
        your_len = (sum(len(m) for m in you) / len(you)) if you else 1.0
        ratio = their_len / max(your_len, 1.0)
        question_rate = sum('?' in m for m in them) / len(them)

        row = pd.DataFrame([[
            _band(ratio, LENGTH_BANDS, 4),
            _band(question_rate, QUESTION_BANDS, 3),
            SPEED_ORDER.index(reply_speed),
        ]], columns=chat_columns)

        return {
            'score': round(float(chat_model.predict_proba(row)[0, 1]), 4),
            'their_messages': len(them),
            'length_ratio': round(ratio, 2),
            'question_rate': round(question_rate, 2),
        }
    except Exception as e:
        print(f"Chat model scoring failed, falling back to heuristic: {e}")
        return None


def get_prediction(metrics):
    """
    Transparent, engagement-based ghosting-risk score computed directly from
    the conversation.

    Why not the survey-trained model here: its strongest predictors
    (Has_Ghosting_History, Is_Serial_Ghoster, lifetime match/like counts)
    describe a person's history and cannot be observed from a single chat.
    Feeding the model fabricated stand-ins made every score come back high.
    Instead we score the conversation on signals it actually contains -
    the same chronemic / engagement cues that indicate disengagement:
      * short one-word replies ("k", "lol", "yeah")
      * not asking questions back (low investment)
      * very brief messages (low effort)
      * barely holding up their side of the conversation

    Returns a probability in [0, 1]; short snippets stay near 0.5 because
    there isn't enough conversation to judge yet.
    """
    msg_count = metrics['msg_count']
    avg_msg_len = metrics['avg_msg_len']
    question_count = metrics['question_count']
    short_reply_ratio = metrics['short_reply_ratio']

    # Nothing to judge on a single line.
    if msg_count < 2:
        return 0.5

    # Sub-signals, each normalised to [0, 1] where 1 indicates higher risk.

    # One-word replies signal disengagement.
    short_reply_signal = short_reply_ratio

    # Not asking questions back indicates low investment; roughly one question
    # per four messages reads as healthy engagement.
    expected_questions = msg_count / 4.0
    question_signal = 1.0 - min(question_count / max(expected_questions, 1.0), 1.0)

    # Very short average messages indicate low effort; around 40 characters
    # reads as engaged, and shorter trends risky.
    brevity_signal = 1.0 - min(avg_msg_len / 40.0, 1.0)

    # Very few replies indicate the conversation is barely being held up.
    engagement_signal = 1.0 - min(msg_count / 12.0, 1.0)

    # Weighted blend. Short replies and not asking questions back are the
    # strongest real-world ghosting tells.
    risk_raw = (
        0.40 * short_reply_signal +
        0.25 * question_signal +
        0.20 * brevity_signal +
        0.15 * engagement_signal
    )

    # Confidence grows with how much conversation we actually have; short
    # pastes are pulled toward a neutral 0.5 instead of an extreme score.
    confidence = min(msg_count / 12.0, 1.0)
    risk = 0.5 * (1.0 - confidence) + risk_raw * confidence

    # A chat is evidence, not certainty - keep off the hard 0/1 edges.
    risk = max(0.05, min(0.95, risk))
    return round(float(risk), 4)

def update_ledger(partner_name, risk_score, msg_count, emoji_rate, age="0", location="unknown", app_user_id=None,
                  heuristic_score=None, scorer="model"):
    if not supabase: return "Database Offline"
    try:
        # Identify the partner.
        partner_hash = get_user_hash(partner_name, age, location)
        
        # Update the shared partner record.
        existing = supabase.table("profiles").select("*").eq("user_hash", partner_hash).execute()
        
        if existing.data:
            profile = existing.data[0]
            new_count = profile['total_reports'] + 1
            new_avg = ((profile['avg_risk_score'] * profile['total_reports']) + float(risk_score)) / new_count
            
            supabase.table("profiles").update({
                "avg_risk_score": new_avg, 
                "total_reports": new_count,
                "last_seen": "now()"
            }).eq("user_hash", partner_hash).execute()
            history_msg = f"⚠️ Flagged {profile['total_reports']} times before."
        else:
            supabase.table("profiles").insert({
                "user_hash": partner_hash,
                "avg_risk_score": float(risk_score),
                "total_reports": 1,
                "last_seen": "now()",
                "first_name": partner_name, 
                "country": location,
                "age": int(age) if age.isdigit() else 0
            }).execute()
            history_msg = "First time tracked."
            
        # Record the analysis against the user who ran it.
        # Both scores are stored. risk_score is what the user was shown; the other
        # scorer's output is kept alongside it so that when the user later answers
        # "did this person ghost you?" on the Validate Predictions screen, both can be
        # graded against the same outcome. Without this the model can never be
        # compared against the heuristic on real data.
        log_row = {
            "user_hash": partner_hash,       # The Partner
            "auth_user_id": app_user_id,     # The App User (YOU)
            "message_count": msg_count,
            "emoji_count": int(emoji_rate * 100),
            "risk_score": float(risk_score),
            "actual_outcome": None
        }
        try:
            log_row["heuristic_risk_score"] = (
                float(heuristic_score) if heuristic_score is not None else None)
            log_row["scorer_version"] = scorer
            supabase.table("analysis_logs").insert(log_row).execute()
        except Exception:
            # Columns not migrated yet - fall back to the original schema so that
            # scoring never fails because of a missing column.
            log_row.pop("heuristic_risk_score", None)
            log_row.pop("scorer_version", None)
            supabase.table("analysis_logs").insert(log_row).execute()
        
        return history_msg
    except Exception as e:
        print(f"DB Update Error: {e}")
        return "History unavailable"

# --- Analysis tasks ----------------------------------------------------------

@celery_app.task(name="analyze_text_task")
def analyze_text_task(chat_text, partner_name, age="0", location="unknown", user_id=None):
    print(f"Processing Text for {partner_name}...")

    metrics = analyze_text_metrics(chat_text)
    heuristic_score = get_prediction(metrics)

    # The trained model is preferred; the heuristic remains as a fallback for
    # transcripts where the speakers cannot be separated.
    model_result = score_chat_with_model(chat_text)
    if model_result is not None:
        risk_score, scorer = model_result['score'], "chat_model_v1"
    else:
        risk_score, scorer = heuristic_score, "heuristic_v1"

    history_msg = update_ledger(partner_name, risk_score, metrics['msg_count'],
                                metrics['emoji_rate'], age, location, user_id,
                                heuristic_score=heuristic_score, scorer=scorer)

    if user_id and supabase:
        try:
            supabase.table("notifications").insert({
                "user_hash": user_id,
                "title": "Analysis Ready 📊",
                "message": f"{partner_name}: {get_risk_label(risk_score)}.",   # banded, not a percentage
                "is_read": False
            }).execute()
        except Exception as e:
            print(f"Notification Error: {e}")

    return {
        "risk_score": float(risk_score),
        "status_label": get_risk_label(risk_score),
        "history_alert": history_msg,
        "scorer": scorer,
        "extracted_data": {
            "messages": metrics['msg_count'],
            "emoji_rate": round(metrics['emoji_rate'], 2),
            "their_messages": (model_result or {}).get('their_messages'),
            "length_ratio": (model_result or {}).get('length_ratio'),
            "question_rate": (model_result or {}).get('question_rate'),
        }
    }

@celery_app.task(name="analyze_screenshot_task")
def analyze_screenshot_task(image_content, partner_name, age="0", location="unknown", user_id=None):
    print(f"Processing Screenshot for {partner_name}...")
    try:
        client = vision.ImageAnnotatorClient()
        image = vision.Image(content=image_content)
        response = client.text_detection(image=image)
        
        if not response.text_annotations:
            return {"error": "No text found in image"}
            
        full_text = response.text_annotations[0].description
        metrics = analyze_text_metrics(full_text)
        heuristic_score = get_prediction(metrics)

        model_result = score_chat_with_model(full_text)
        if model_result is not None:
            risk_score, scorer = model_result['score'], "chat_model_v1"
        else:
            risk_score, scorer = heuristic_score, "heuristic_v1"

        history_msg = update_ledger(partner_name, risk_score, metrics['msg_count'],
                                    metrics['emoji_rate'], age, location, user_id,
                                    heuristic_score=heuristic_score, scorer=scorer)

        if user_id and supabase:
            try:
                supabase.table("notifications").insert({
                    "user_hash": user_id,
                    "title": "Analysis Ready 📊",
                    "message": f"{partner_name}: {get_risk_label(risk_score)}.",   # banded, not a percentage
                    "is_read": False
                }).execute()
            except Exception as e:
                print(f"Notification Error: {e}")

        return {
            "risk_score": float(risk_score),
            "status_label": get_risk_label(risk_score),
            "history_alert": history_msg,
            "extracted_data": {"messages": metrics['msg_count'], "preview": full_text[:50]}
        }
    except Exception as e:
        return {"error": str(e)}

# --- Outcome follow-up -------------------------------------------------------

# Every analysis is stored with actual_outcome = None. Without knowing what actually
# happened, no scorer can be evaluated and no model can be retrained on real
# conversations rather than survey responses. The Validate Predictions screen already
# collects that answer; this task is what brings users back to it.

FOLLOW_UP_AFTER_DAYS = 14      # long enough for a fade to be recognisable
FOLLOW_UP_EXPIRES_DAYS = 60    # beyond this recall is unreliable, so stop asking


@celery_app.task(name="request_outcomes_task")
def request_outcomes_task(limit: int = 200):
    """Notify users about analyses that are old enough to have a known outcome.

    Runs daily. One notification per pending analysis, sent once: the presence of an
    existing notification for that analysis is what prevents repeats, so the task is
    safe to run more than once a day.
    """
    if not supabase:
        return {"status": "database offline"}

    from datetime import datetime, timedelta, timezone
    now = datetime.now(timezone.utc)
    ripe = (now - timedelta(days=FOLLOW_UP_AFTER_DAYS)).isoformat()
    stale = (now - timedelta(days=FOLLOW_UP_EXPIRES_DAYS)).isoformat()

    try:
        pending = (supabase.table("analysis_logs")
                   .select("id, auth_user_id, user_hash, risk_score, created_at")
                   .is_("actual_outcome", "null")
                   .lt("created_at", ripe)
                   .gt("created_at", stale)
                   .not_.is_("auth_user_id", "null")
                   .order("created_at", desc=False)
                   .limit(limit)
                   .execute().data)
    except Exception as e:
        print(f"Follow-up query failed: {e}")
        return {"status": "error", "error": str(e)}

    if not pending:
        return {"status": "ok", "pending": 0, "sent": 0}

    # Look up the partner names so the question can name the person.
    hashes = list({p["user_hash"] for p in pending if p.get("user_hash")})
    names = {}
    if hashes:
        try:
            for row in (supabase.table("profiles").select("user_hash, first_name")
                        .in_("user_hash", hashes).execute().data):
                names[row["user_hash"]] = row.get("first_name")
        except Exception as e:
            print(f"Profile lookup failed, using a generic prompt: {e}")

    sent, skipped = 0, 0
    for row in pending:
        uid = row["auth_user_id"]
        who = names.get(row.get("user_hash")) or "someone"
        marker = f"[log:{row['id']}]"

        try:
            already = (supabase.table("notifications").select("id")
                       .eq("user_hash", uid).ilike("message", f"%{marker}%")
                       .limit(1).execute().data)
            if already:
                skipped += 1
                continue

            supabase.table("notifications").insert({
                "user_hash": uid,
                "title": "What happened with " + str(who) + "?",
                "message": ("You analysed this conversation two weeks ago. Did they ghost "
                            "you? Answering takes a second and makes future predictions "
                            "more accurate for everyone. " + marker),
                "is_read": False,
            }).execute()
            sent += 1
        except Exception as e:
            print(f"Follow-up notification failed for {uid}: {e}")

    print(f"Outcome follow-up: {sent} sent, {skipped} already asked, "
          f"{len(pending)} pending")
    return {"status": "ok", "pending": len(pending), "sent": sent, "skipped": skipped}
