import os
import ssl
from celery import Celery

# Broker URL, supplied by the deployment environment.

redis_url = os.getenv("REDIS_URL")

# Rediss URL
if not redis_url:
    print("WARNING: REDIS_URL not found in environment! Defaulting to localhost (Will fail in cloud)")
    redis_url = "redis://localhost:6379/0"

# Upstash requires TLS; certificate verification is relaxed for the managed endpoint.
# We force SSL to be "permissive" so it doesn't block the connection
ssl_conf = {
    'ssl_cert_reqs': ssl.CERT_NONE
}

# Application instance.
celery_app = Celery(
    "holo_worker",
    broker=redis_url,
    backend=redis_url,
)

# Runtime settings.
celery_app.conf.update(
    broker_use_ssl=ssl_conf,
    redis_backend_use_ssl=ssl_conf,
    result_expires=3600,
    broker_connection_retry_on_startup=True
)

# Scheduled tasks.
# The outcome follow-up asks users what happened to conversations analysed two weeks
# earlier. Those answers are the only ground truth available, and without them
# scorer performance cannot be measured.
from celery.schedules import crontab

celery_app.conf.beat_schedule = {
    "request-outcomes-daily": {
        "task": "request_outcomes_task",
        "schedule": crontab(hour=10, minute=0),
    },
}
celery_app.conf.timezone = "UTC"
