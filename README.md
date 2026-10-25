# Holo

A dating safety application that analyses a conversation and reports whether the other
person shows signs of disengaging.

A user pastes a chat or uploads a screenshot. The backend attributes each message to a
speaker, measures three properties of the other person's messages, and returns a risk
band. Two weeks later the application asks what actually happened, so every prediction
can be checked against the real outcome.

<table>
  <tr><td><b>Web client</b></td><td><a href="https://15b0f731-363d-4b49-a74d-05969b52439e.e1-us-east-azure.choreoapps.dev">Open the live application</a></td></tr>
  <tr><td><b>Growth engine</b></td><td><a href="https://github.com/Lihini0202/holo-growth-engine">Holo Growth Engine repository</a></td></tr>
</table>

## Growth engine

The go to market system for this application is maintained in a separate repository,
<a href="https://github.com/Lihini0202/holo-growth-engine"><b>Holo Growth Engine</b></a>. It
turns event sign ups and product usage into active users, with consent enforced at every
step.

<table>
  <tr><th align="left">Component</th><th align="left">Responsibility</th></tr>
  <tr><td>Lead pipeline</td><td>Cleans event sign up sheets, enforces consent, enriches and scores leads, and upserts them to HubSpot</td></tr>
  <tr><td>Lifecycle sync</td><td>Derives user stages from <code>analysis_logs</code> usage metadata and syncs consented users to the CRM</td></tr>
  <tr><td>Consent ledger</td><td>Append only record of opt ins and withdrawals, propagated to HubSpot email subscription status</td></tr>
  <tr><td>Website analytics</td><td>Sessions and sign ups by traffic source from GA4</td></tr>
  <tr><td>Reporting</td><td>Streamlit dashboard, weekly brief and an MCP server</td></tr>
</table>

The growth engine has read only access to this application's data and selects usage
metadata only: who ran an analysis, when, and whether an outcome was recorded.
Conversation text, risk scores and partner details never leave this application. The
marketing consent table it depends on is defined in that repository under
<code>integrations/holo/marketing_consent.sql</code>.

## Features

<table>
  <tr><th align="left">Screen</th><th align="left">Purpose</th></tr>
  <tr><td><b>Analyze</b></td><td>Paste a chat or upload a screenshot to receive a risk band and the signals behind it</td></tr>
  <tr><td><b>Search</b></td><td>Look up a name others have reported, graded by how much of the identity matched</td></tr>
  <tr><td><b>Coach</b></td><td>Rewrite a draft message that is unlikely to get a reply</td></tr>
  <tr><td><b>Insights</b></td><td>Distribution of the user's own conversations across risk bands</td></tr>
  <tr><td><b>Validate Predictions</b></td><td>Confirm what happened to a past conversation</td></tr>
  <tr><td><b>Profile</b></td><td>Account details and photo</td></tr>
</table>

## Model

<code>backend/chat_ghosting_model.pkl</code> is a logistic regression with three inputs and a
held out ROC AUC of <b>0.9154</b>.

<table>
  <tr><th align="left">Signal</th><th align="left">Measured from the transcript as</th></tr>
  <tr><td><code>Rel_Length_Ord</code></td><td>Mean message length of the other person relative to the user</td></tr>
  <tr><td><code>Return_Questions_Ord</code></td><td>Share of the other person's messages that contain a question</td></tr>
  <tr><td><code>Reply_Speed_Ord</code></td><td>Consistency of reply intervals, when timestamps are available</td></tr>
</table>

### Why message count is excluded

In the survey data, conversations that faded averaged 10 messages and conversations that
continued averaged 34. Message count alone reaches an AUC of 0.9243.

It is excluded because survey respondents report the length of a whole conversation,
while users paste an excerpt, and an excerpt is short regardless of how the conversation
is going. Including the feature raises held out AUC from 0.9154 to 0.9651 but makes the
score depend on how much text was pasted. A balanced exchange scores 0.72 under the
deployed model at any length, against 0.90 at 8 messages and 0.27 at 34 messages once
message count is included.

Rescoring the full held out set as 10 message excerpts moves 355 of the 1,233
conversations the deployed model rates as healthy up at least one band, and raises the
share in the top band from 55.6% to 67.7%.

Excluding the feature costs 0.050 AUC in exchange for scores that remain valid on real
input.

### Why logistic regression rather than gradient boosting

With three ordinal inputs of low cardinality, some input combinations are sparse:
<code>Rel_Length_Ord = 0, Return_Questions_Ord = 0</code> covers 19 of 15,209 training
conversations. A boosted model overfitted that region and scored a strongly disengaged
conversation lower than a mildly disengaged one. A model that is linear in the log odds
cannot invert that ordering. CI asserts monotonicity across all 60 cells of the input grid.

### Why bands rather than percentages

The model ranks conversations reliably, but its individual probabilities are not precise
enough to display. On the held out set the Brier score is 0.104, and the largest gap
between predicted and observed frequency across ten quantile bins is 0.130. Isotonic
recalibration did not close the gap.

<table>
  <tr><th align="left">Band</th><th align="right">Conversations</th><th align="right">Mean predicted</th><th align="right">Observed fade rate</th></tr>
  <tr><td>Looks healthy</td><td align="right">1,233</td><td align="right">0.109</td><td align="right">7.7%</td></tr>
  <tr><td>Some warning signs</td><td align="right">476</td><td align="right">0.508</td><td align="right">59.9%</td></tr>
  <tr><td>Strong signs of fading</td><td align="right">2,143</td><td align="right">0.870</td><td align="right">88.3%</td></tr>
</table>

The middle band is labelled "Some warning signs" rather than "Medium" because
conversations in it faded 59.9% of the time, which is much closer to the top band than
to the bottom one.

## Architecture

```
Flutter client ──HTTPS──> FastAPI ──> Celery worker ──> model
      │                      │             │
      │                      └─────────────┴──> Supabase (Postgres, Auth, Storage)
      └──────────────────────────────────────>  Supabase (direct access, enforced by RLS)
                                          Redis (Upstash) as the Celery broker
```

Analysis is asynchronous. The API queues a task and returns its id, and the client polls
<code>/status/{id}</code>. OCR and model inference take longer than a request should block.

The client reads and writes its own data (profiles, history and notifications) directly
in Supabase and calls the API only for analysis. Row level security is what makes direct
access safe.

### API

<table>
  <tr><th align="left">Method</th><th align="left">Path</th><th align="left">Purpose</th></tr>
  <tr><td><code>GET</code></td><td><code>/</code></td><td>Health check</td></tr>
  <tr><td><code>POST</code></td><td><code>/analyze-text</code></td><td>Queue analysis of a pasted transcript</td></tr>
  <tr><td><code>POST</code></td><td><code>/analyze-screenshot</code></td><td>Queue analysis of an uploaded image (Google Cloud Vision OCR)</td></tr>
  <tr><td><code>GET</code></td><td><code>/status/{task_id}</code></td><td>Poll a queued task</td></tr>
  <tr><td><code>POST</code></td><td><code>/search-ghost</code></td><td>Look up a reported partner</td></tr>
  <tr><td><code>POST</code></td><td><code>/coach-reply</code></td><td>Rewrite a draft message</td></tr>
  <tr><td><code>POST</code></td><td><code>/admin/request-outcomes</code></td><td>Trigger the outcome follow up manually</td></tr>
</table>

### Background tasks

<table>
  <tr><th align="left">Task</th><th align="left">Trigger</th></tr>
  <tr><td><code>analyze_text_task</code></td><td>On request</td></tr>
  <tr><td><code>analyze_screenshot_task</code></td><td>On request</td></tr>
  <tr><td><code>request_outcomes_task</code></td><td>Daily at 10:00 UTC</td></tr>
</table>

## Outcome validation

Every analysis is stored with <code>actual_outcome</code> unset. After two weeks,
<code>request_outcomes_task</code> sends a notification asking what happened, and the user
answers Yes, No or <b>Not sure</b> on the Validate Predictions screen.

Yes and No are stored in <code>actual_outcome</code>. Not sure sets
<code>outcome_skipped</code> instead: the analysis counts as answered, leaves the Validate
Predictions queue and is never requested again, and no label is recorded, so an uncertain
guess never becomes training data.

Each analysis stores both the model score and the score of the previous heuristic, so the
two can be compared on real outcomes once enough have been collected.

The band thresholds in the model metadata are calibration choices rather than fitted
values: the survey asked respondents to estimate relative length, while the application
measures it. The thresholds should be refitted once real outcomes are available.

## Repository layout

```
holoapp/
├── .github/workflows/ci.yml
├── backend/                  FastAPI and Celery, Choreo service, port 8000
│   ├── main.py               HTTP endpoints
│   ├── tasks.py              Celery tasks, scoring, transcript parsing
│   ├── celery_config.py      Broker and beat schedule
│   ├── chat_ghosting_model.pkl
│   ├── migrations_*.sql
│   └── Dockerfile
└── frontend/                 Flutter, Choreo web application, port 8080
    ├── lib/screens/          13 screens
    ├── nginx.conf
    └── Dockerfile
```

## Running locally

<b>Backend</b>

```bash
cd backend
cp .env.example .env          # then fill in the values
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
python -m celery -A tasks worker --pool=solo --loglevel=info
```

The worker runs as a separate process. Without it, the API accepts requests and queues
tasks that are never executed.

<b>Frontend</b>

```bash
cd frontend
cp .env.example .env          # BACKEND_URL=http://127.0.0.1:8000
flutter pub get
flutter run -d chrome
```

## Configuration

No secrets are committed. Both <code>.env</code> files are ignored by git and supplied by the
hosting platform.

<b>Backend</b>: runtime environment variables

<table>
  <tr><th align="left">Variable</th><th align="left">Notes</th></tr>
  <tr><td><code>SUPABASE_URL</code></td><td></td></tr>
  <tr><td><code>SUPABASE_KEY</code></td><td>Service role key. Bypasses RLS; backend only</td></tr>
  <tr><td><code>OPENROUTER_API_KEY</code></td><td>Coaching model</td></tr>
  <tr><td><code>REDIS_URL</code></td><td>Celery broker</td></tr>
  <tr><td><code>GOOGLE_APPLICATION_CREDENTIALS</code></td><td>Cloud Vision service account</td></tr>
</table>

<b>Frontend</b>: build arguments, not runtime variables

<table>
  <tr><th align="left">Variable</th><th align="left">Notes</th></tr>
  <tr><td><code>SUPABASE_URL</code></td><td></td></tr>
  <tr><td><code>SUPABASE_ANON_KEY</code></td><td>Publishable; restricted by RLS</td></tr>
  <tr><td><code>BACKEND_URL</code></td><td>No trailing slash</td></tr>
</table>

Flutter compiles <code>.env</code> into the JavaScript bundle during <code>flutter build web</code>.
Values supplied at runtime arrive too late: the build succeeds but ships with an empty
configuration, and every request fails without a clear error.

## Security

### Row level security

<table>
  <tr><th align="left">Table</th><th align="left">Policy</th></tr>
  <tr><td><code>user_profiles</code></td><td>Own row only</td></tr>
  <tr><td><code>analysis_logs</code></td><td>Own rows, keyed on <code>auth_user_id</code></td></tr>
  <tr><td><code>notifications</code></td><td>Own rows</td></tr>
  <tr><td><code>profiles</code></td><td>Publicly readable; the shared ledger of reported partners</td></tr>
  <tr><td><code>storage.objects</code></td><td>Own folder only, under <code>avatars/&lt;auth uid&gt;/</code></td></tr>
</table>

Policies on <code>analysis_logs</code> and <code>notifications</code> are enforced and verified:
an unauthenticated request reads zero rows and is refused on write. Without them, the anon
key shipped in the client bundle would allow any visitor to read every user's conversation
history and delete the tables.

### Anon key

The publishable key is embedded in the client bundle and cannot be hidden. It is protected
by the policies above, not by secrecy. The service role key bypasses every policy and must
never be included in a frontend build.

### Profile separation

<code>profiles</code> is the publicly readable ledger of reported partners, which search
depends on. <code>user_profiles</code> holds account holders and is private. They are
separate tables because a single shared table would make a user searchable as a reported
partner as soon as they saved their own profile.

## Build and deployment

```
push to main
   ├── GitHub Actions ── lint, model check, container build, flutter analyze
   └── Choreo ────────── build image, scan, deploy
```

<b>Continuous integration</b> runs in GitHub Actions. Each job runs only when its own
directory has changed, so a frontend commit does not rebuild the backend container.

The backend job verifies that the model discriminates: a disengaged conversation must
score above 0.9 and an engaged one below 0.1. A load check alone would pass even if the
features were saved in the wrong order or inverted.

<b>Continuous deployment</b> is handled by Choreo, triggered by commits to <code>main</code>
through the Choreo GitHub App. GitHub Actions does not deploy; Choreo owns the registry
and the runtime.

CI and deployment run in parallel, and Choreo does not wait for CI to pass. Branch
protection with required checks would close that gap, at the cost of working through
pull requests.

The Choreo GitHub App has read and write access to code and pull requests, and read access
to issues and metadata. It does not request the Deployments permission, so the GitHub
Deployments tab stays empty and deployment history is kept in the Choreo console.

### Runtime pinning

<code>requirements.txt</code> pins scikit learn, NumPy, SciPy and joblib to the versions used
for training. Loading the model under a different scikit learn build is unsupported: it can
fail on compiled extensions, or load and behave differently. scikit learn 1.9 requires
Python 3.11 and NumPy 2.x requires Python 3.12, so the container base image is
<code>python:3.12-slim</code>.

### Container constraints

Choreo runs containers as an unprivileged user with a UID between 10000 and 20000, on a
read only root filesystem. nginx creates its temporary directories at startup even for
static sites and refuses to start if it cannot, so <code>frontend/nginx.conf</code> replaces
the default configuration and points every writable path to <code>/tmp</code>.

## Database setup

Apply the migrations in order, then confirm RLS is enabled on every table that stores
user data:

```
backend/migrations_user_profiles.sql
backend/migrations_avatars.sql
backend/migrations_outcome_skipped.sql
backend/check_policies.sql          verification query, not a migration
```

Storage policies are created in the Supabase dashboard rather than in SQL, because the SQL
editor cannot create policies on <code>storage.objects</code> in every project.

## License

Released under the MIT License. See <a href="LICENSE">LICENSE</a>.
