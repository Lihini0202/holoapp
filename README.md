# Holo

A dating-safety application that reads a conversation and reports whether the other
person is showing signs of disengaging.

A user pastes a chat or uploads a screenshot. The backend separates who said what,
measures three properties of the other person's messages, and returns a risk band.
Two weeks later the app asks what actually happened, and that answer is what allows
the prediction to be checked against reality.

**Live**

| | |
|---|---|
| Web client | https://15b0f731-363d-4b49-a74d-05969b52439e.e1-us-east-azure.choreoapps.dev |

---

## What the application does

| Screen | Purpose |
|---|---|
| **Analyze** | Paste a chat or upload a screenshot; returns a risk band and the signals behind it |
| **Search** | Look up a name others have reported, graded by how much of the identity matched |
| **Coach** | Rewrite a draft message that is unlikely to get a reply |
| **Insights** | How the user's own conversations are distributed across risk bands |
| **Validate Predictions** | Confirm what happened to a past conversation |
| **Profile** | Account details and photo |

---

## The model

`backend/chat_ghosting_model.pkl` — logistic regression, three inputs, **held-out
ROC-AUC 0.9154**.

| Signal | Read from the transcript as |
|---|---|
| `Rel_Length_Ord` | their mean message length relative to the user's |
| `Return_Questions_Ord` | share of their messages containing a question |
| `Reply_Speed_Ord` | consistency of reply intervals, where timestamps exist |

### Why message count is excluded

The obvious predictor is how long the conversation ran. In the survey data a faded
conversation averaged 10 messages against 34 for one that continued, and message
count alone reaches 0.9243 AUC.

It is excluded anyway. A pasted excerpt is short regardless of how the conversation
is going, so a model using it reads *every* screenshot as high risk. Tested against a
healthy conversation — long replies, questions returned, a date proposed — a model
including message count scored it 0.731 (high risk). Without it: 0.013.

Dropping the feature cost 0.077 AUC and bought a model that survives contact with
real input.

### Why logistic regression rather than gradient boosting

On three low-cardinality ordinal inputs the grid has sparse corners. The combination
`Rel_Length_Ord = 0, Return_Questions_Ord = 0` holds 21 of 19,061 training
conversations, and a boosted model fit the noise there, scoring a strongly
disengaged conversation *lower* than a mildly disengaged one. A linear model in the
log-odds cannot invert. Monotonicity is asserted across all 20 grid combinations in
CI.

### Why bands rather than percentages

The model ranks reliably but its individual probabilities are not accurate enough to
print. The largest calibration gap measured was 0.05, and it remained 0.0506 after
isotonic calibration. Conversations scoring in the top band were ghosted 91.9% of the
time, not the 99% a raw score implies.

The middle band is labelled "Some warning signs" rather than "Medium", because
conversations falling in it were ghosted 62.7% of the time — much closer to the high
band than the low one.

---

## Architecture

```
Flutter client ──HTTPS──> FastAPI ──> Celery worker ──> model
      │                      │             │
      │                      └─────────────┴──> Supabase (Postgres + Auth + Storage)
      └──────────────────────────────────────>  Supabase (direct, RLS-enforced)
                                          Redis (Upstash) as the Celery broker
```

Analysis is asynchronous: the API queues a task and returns an id, the client polls
`/status/{id}`. OCR and the model call are slower than a request should block for.

The client talks to Supabase directly for its own data — profiles, history,
notifications — and only to the API for analysis. Row-level security is what makes
that safe.

### API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | Health |
| `POST` | `/analyze-text` | Queue analysis of a pasted transcript |
| `POST` | `/analyze-screenshot` | Queue analysis of an uploaded image (Google Cloud Vision OCR) |
| `GET` | `/status/{task_id}` | Poll a queued task |
| `POST` | `/search-ghost` | Look up a reported partner |
| `POST` | `/coach-reply` | Rewrite a draft message |
| `POST` | `/admin/request-outcomes` | Trigger the outcome follow-up manually |

### Background tasks

| Task | Trigger |
|---|---|
| `analyze_text_task` | On request |
| `analyze_screenshot_task` | On request |
| `request_outcomes_task` | Daily, 10:00 UTC |

---

## How the model gets checked

Every analysis is stored with `actual_outcome` unset. Two weeks later
`request_outcomes_task` sends a notification asking what happened; the user answers
Yes, No, or **Not sure** on the Validate Predictions screen.

"Not sure" records nothing and stops asking. An uncertain guess entered as a label is
worse than a missing one, because it teaches the model something false.

Both the model's score and the previous heuristic's are stored on every analysis, so
once enough outcomes exist the two can be compared on real conversations rather than
survey responses.

The band thresholds in the model metadata are calibration choices, not fitted values:
the survey asked respondents to *judge* relative length, whereas the application must
*measure* it. They should be re-fitted once real outcomes are collected.

---

## Repository layout

```
holoapp/
├── .github/workflows/ci.yml
├── backend/                  FastAPI + Celery, Choreo Service, port 8000
│   ├── main.py               HTTP endpoints
│   ├── tasks.py              Celery tasks, scoring, transcript parsing
│   ├── celery_config.py      Broker and beat schedule
│   ├── chat_ghosting_model.pkl
│   ├── migrations_*.sql
│   └── Dockerfile
└── frontend/                 Flutter, Choreo Web Application, port 8080
    ├── lib/screens/          13 screens
    ├── nginx.conf
    └── Dockerfile
```

---

## Running locally

**Backend**

```bash
cd backend
cp .env.example .env          # then fill in
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
python -m celery -A tasks worker --pool=solo --loglevel=info
```

The worker is a separate process. Without it the API accepts requests and queues
tasks that are never executed.

**Frontend**

```bash
cd frontend
cp .env.example .env          # BACKEND_URL=http://127.0.0.1:8000
flutter pub get
flutter run -d chrome
```

---

## Configuration

Nothing is committed. Both `.env` files are git-ignored and supplied by the platform.

**Backend** — runtime environment variables

| Variable | |
|---|---|
| `SUPABASE_URL` | |
| `SUPABASE_KEY` | service_role — bypasses RLS, backend only |
| `OPENROUTER_API_KEY` | Coaching model |
| `REDIS_URL` | Celery broker |
| `GOOGLE_APPLICATION_CREDENTIALS` | Cloud Vision service account |

**Frontend** — **build arguments**, not runtime variables

| Variable | |
|---|---|
| `SUPABASE_URL` | |
| `SUPABASE_ANON_KEY` | publishable, restricted by RLS |
| `BACKEND_URL` | no trailing slash |

Flutter compiles `.env` into the JavaScript bundle during `flutter build web`.
Supplied at runtime they arrive too late: the build succeeds and ships an app with
empty configuration, which fails on every request with no obvious cause.

---

## Security

### Row-level security

| Table | Policy |
|---|---|
| `user_profiles` | own row only |
| `analysis_logs` | own rows, keyed on `auth_user_id` |
| `notifications` | own rows |
| `profiles` | publicly readable — the shared reported-partner ledger |
| `storage.objects` | own folder only, `avatars/<auth-uid>/` |

RLS on `analysis_logs` and `notifications` was initially absent. With the anon key
alone — which ships inside the client bundle — any visitor could read every user's
conversation history and delete the table. Both are now enforced and verified: an
unauthenticated request reads zero rows and is refused on write.

### On the anon key

The publishable key is embedded in the shipped bundle and cannot be hidden. It is
protected by the policies above rather than by secrecy. The `service_role` key
bypasses every policy and must never reach a frontend build.

### Separation of profiles

`profiles` is the ledger of reported partners and is publicly readable, because
search depends on it. `user_profiles` holds account holders and is private. These
were originally one table keyed on the same column with two incompatible meanings —
saving a profile would have made the user searchable as a reported partner.

---

## Build and deployment

```
push to main
   ├── GitHub Actions ── lint, model check, container build, flutter analyze
   └── Choreo ────────── build image, scan, deploy
```

**Continuous integration** runs in GitHub Actions. Each job checks whether its own
directory changed, so a frontend commit does not rebuild the backend container.

The backend job asserts the model discriminates — a disengaged conversation must
score above 0.9 and an engaged one below 0.1. Loading the model alone would still
pass if its features were saved reordered or inverted.

**Continuous deployment** is handled by Choreo, triggered by commits to `main`
through the Choreo GitHub App. GitHub Actions never deploys; Choreo owns the
registry and runtime.

The two run in parallel, not in sequence: Choreo does not wait for CI. Branch
protection requiring the checks to pass would close that gap at the cost of working
through pull requests.

The Choreo GitHub App requests read and write on code and pull requests, and read on
issues and metadata. It does not request the Deployments permission, so GitHub's
Deployments tab stays empty — the deployment record lives in the Choreo console.

### Runtime pinning

`requirements.txt` pins scikit-learn, numpy, scipy and joblib to the versions the
model was trained with. Loading a model under a different scikit-learn build is
unsupported: it may fail on the compiled extensions, or load and behave differently.
scikit-learn 1.9 requires Python 3.11 and numpy 2.x requires 3.12, so the container
base is `python:3.12-slim`.

### Container constraints

Choreo runs containers as a non-root user with a UID between 10000 and 20000, on a
read-only root filesystem. nginx creates its temp directories at startup regardless
of whether a static site uses them, and refuses to start when it cannot, so
`frontend/nginx.conf` replaces the stock configuration and points every writable
path at `/tmp`.

---

## Database setup

Apply in order, then confirm RLS is enabled on every user-scoped table:

```
backend/migrations_user_profiles.sql
backend/migrations_avatars.sql
backend/check_policies.sql          verification, not a migration
```

Storage policies are created through the Supabase dashboard rather than SQL; the SQL
editor cannot create policies on `storage.objects` in every project.

