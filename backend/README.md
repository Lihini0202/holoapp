# Holo — Backend

FastAPI service and Celery worker behind Holo, a dating-safety application. It scores
a conversation for signs of disengagement and maintains a shared record of reported
partners.

## Model

`chat_ghosting_model.pkl` is a logistic regression over three conversation signals,
held-out ROC-AUC 0.9154:

| Signal | Meaning |
|---|---|
| `Rel_Length_Ord` | the other party's reply length relative to the user's |
| `Return_Questions_Ord` | how often they ask a question back |
| `Reply_Speed_Ord` | whether their reply speed stays consistent |

Message count is excluded by design. In the source data a faded conversation averaged
10 messages against 34 for one that continued, so a model using it scores any short
excerpt as failing — and application input is always an excerpt.

Scores are reported as bands rather than percentages: the largest calibration gap
measured was 0.05, which is wider than a printed figure would imply.

## Running locally

```bash
cp .env.example .env    # then fill in the values
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
python -m celery -A tasks worker --pool=solo --loglevel=info
```

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/analyze-text` | Queue analysis of a pasted transcript |
| `POST` | `/analyze-screenshot` | Queue analysis of a screenshot via OCR |
| `GET` | `/status/{task_id}` | Poll a queued analysis |
| `POST` | `/search-ghost` | Look up a partner by name, age and location |
| `POST` | `/coach-reply` | Rewrite a draft message |
| `POST` | `/admin/request-outcomes` | Run the outcome follow-up manually |

## Database

Apply `migrations_user_profiles.sql` and `migrations_avatars.sql` to a new Supabase
project. Both create row-level security policies; storage policies must be added
through the Supabase dashboard, as the SQL editor cannot alter `storage.objects`.

## Deployment

Choreo builds the `Dockerfile` and runs `start.sh`, which starts uvicorn and, when
`REDIS_URL` is present, a Celery worker in the same container. `.choreo/component.yaml`
exposes port 8000.

The Flutter client is deployed separately.
