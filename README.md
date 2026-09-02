# Holo

A dating-safety application that scores a conversation for signs of disengagement.

| Path | Component | Deploys as |
|---|---|---|
| `backend/` | FastAPI + Celery analysis API | Choreo **Service**, port 8000 |
| `frontend/` | Flutter client | Choreo **Web Application**, port 8080 |

## The model

`backend/chat_ghosting_model.pkl` scores a transcript from three signals, none of
which depend on how much of the conversation was supplied:

- whether the other party's replies are shorter than the user's
- how often they ask a question back
- whether their reply speed is consistent

Held-out ROC-AUC 0.9154. Message count is deliberately excluded: in the training
data a faded conversation averaged 10 messages against 34 for one that continued,
so a model using it reads every pasted excerpt as high risk.

Scores are reported as bands rather than percentages. The largest calibration gap
measured was 0.05, which is wider than a printed figure would imply.

## Deployment

Both components build from their own Dockerfile. Deploy the backend first: the
frontend needs its URL as a build argument.

**Backend** — runtime environment variables

| Variable | Purpose |
|---|---|
| `SUPABASE_URL`, `SUPABASE_KEY` | Database, service_role key |
| `OPENROUTER_API_KEY` | Coaching model |
| `REDIS_URL` | Celery broker |

**Frontend** — build arguments, not runtime variables. Flutter compiles `.env`
into the bundle, so values supplied at runtime arrive too late.

| Variable | Purpose |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Database, publishable key |
| `BACKEND_URL` | The deployed backend endpoint |

The anon key is public by design and is protected by row-level security rather
than by being hidden. The service_role key bypasses those policies and must never
reach a frontend build.

## Database

Apply the migrations in `backend/` in order, then confirm row-level security is
enabled on `analysis_logs`, `notifications`, `user_profiles` and `storage.objects`.
