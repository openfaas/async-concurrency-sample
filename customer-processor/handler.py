import asyncio
import json
import threading
from datetime import datetime, timezone

_inflight = 0
_inflight_lock = threading.Lock()

def handle(event, context):
    if event.path in ("/ready", "/_/ready"):
        return {
            "statusCode": 200,
            "body": {"ready": True, "hostname": context.hostname},
            "headers": {"Content-Type": "application/json"},
        }

    if event.path in ("/healthz", "/_/healthz"):
        return {
            "statusCode": 200,
            "body": {"healthy": True, "hostname": context.hostname},
            "headers": {"Content-Type": "application/json"},
        }

    payload, parse_error = _parse_payload(event)
    if parse_error:
        return {
            "statusCode": 400,
            "body": {"error": parse_error},
            "headers": {"Content-Type": "application/json"},
        }

    customer_name = payload.get("customer_name")
    if not customer_name:
        return {
            "statusCode": 400,
            "body": {"error": "customer_name is required"},
            "headers": {"Content-Type": "application/json"},
        }

    processing_time, time_error = _validate_processing_time(payload.get("processing_time", 0))
    if time_error:
        return {
            "statusCode": 400,
            "body": {"error": time_error},
            "headers": {"Content-Type": "application/json"},
        }

    global _inflight

    with _inflight_lock:
        _inflight += 1
        concurrent = _inflight

    started_at = datetime.now(timezone.utc).isoformat()
    print(
        f"START customer={customer_name} processing_time={processing_time}s "
        f"hostname={context.hostname} started_at={started_at} inflight={concurrent}",
        flush=True,
    )

    asyncio.run(asyncio.sleep(processing_time))

    with _inflight_lock:
        _inflight -= 1
        concurrent = _inflight

    completed_at = datetime.now(timezone.utc).isoformat()
    print(
        f"END customer={customer_name} processing_time={processing_time}s "
        f"hostname={context.hostname} completed_at={completed_at} inflight={concurrent}",
        flush=True,
    )

    return {
        "statusCode": 200,
        "body": {
            "message": "processed",
            "customer_name": customer_name,
            "processing_time": processing_time,
            "hostname": context.hostname,
        },
        "headers": {"Content-Type": "application/json"},
    }


def _parse_payload(event):
    raw = event.body

    if raw is None:
        return {}, None

    if isinstance(raw, bytes):
        raw = raw.decode("utf-8", errors="replace")

    if isinstance(raw, str):
        try:
            payload = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError as e:
            return None, f"invalid JSON body: {str(e)}"
    elif isinstance(raw, dict):
        payload = raw
    else:
        return None, "unsupported body type"

    if not isinstance(payload, dict):
        return None, "JSON body must be an object"

    return payload, None


def _validate_processing_time(value):
    try:
        processing_time = float(value)
    except (TypeError, ValueError):
        return None, "processing_time must be a number"

    if processing_time < 0:
        return None, "processing_time must be >= 0"

    return processing_time, None
