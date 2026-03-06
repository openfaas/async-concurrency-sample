#!/usr/bin/env bash
set -euo pipefail

GATEWAY_URL="${OPENFAAS_URL:-${GATEWAY_URL:-}}"
OPENFAAS_USERNAME="${OPENFAAS_USERNAME:-}"
OPENFAAS_PASSWORD="${OPENFAAS_PASSWORD:-}"
FUNCTION_NAME="${FUNCTION_NAME:-customer-processor-capacity}"
REQUESTS="${REQUESTS:-10}"
PROCESSING_TIME="${PROCESSING_TIME:-5}"
PROCESSING_TIME_MIN="${PROCESSING_TIME_MIN:-60}"
PROCESSING_TIME_MAX="${PROCESSING_TIME_MAX:-180}"
PROCESSING_TIME_MODE="${PROCESSING_TIME_MODE:-fixed}" # fixed or random-range
MODE="${MODE:-sync}" # sync or async
CUSTOMER_PREFIX="${CUSTOMER_PREFIX:-customer}"

if [[ -z "${GATEWAY_URL}" ]]; then
  echo "Set OPENFAAS_URL (or GATEWAY_URL) to your gateway URL." >&2
  exit 1
fi

if [[ "$MODE" == "async" ]]; then
  ENDPOINT="${GATEWAY_URL}/async-function/${FUNCTION_NAME}"
else
  ENDPOINT="${GATEWAY_URL}/function/${FUNCTION_NAME}"
fi

echo "Sending ${REQUESTS} ${MODE} requests to ${ENDPOINT} with processing_time=${PROCESSING_TIME}s"

AUTH_ARGS=()
if [[ -n "${OPENFAAS_USERNAME}" || -n "${OPENFAAS_PASSWORD}" ]]; then
  AUTH_ARGS=(-u "${OPENFAAS_USERNAME}:${OPENFAAS_PASSWORD}")
fi

for i in $(seq 1 "$REQUESTS"); do
  time_for_request="$PROCESSING_TIME"
  if [[ "$PROCESSING_TIME_MODE" == "random-range" ]]; then
    if command -v shuf >/dev/null 2>&1; then
      time_for_request="$(shuf -i "${PROCESSING_TIME_MIN}-${PROCESSING_TIME_MAX}" -n 1)"
    else
      time_for_request="$(( PROCESSING_TIME_MIN + (RANDOM % (PROCESSING_TIME_MAX - PROCESSING_TIME_MIN + 1)) ))"
    fi
  fi

  payload=$(printf '{"customer_name":"%s-%02d","processing_time":%s}' "$CUSTOMER_PREFIX" "$i" "$time_for_request")

  (
    code=$(curl -sS -o "/tmp/${FUNCTION_NAME}-${i}.out" -w "%{http_code}" \
      -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      "${AUTH_ARGS[@]}" \
      --data "$payload")

    echo "request=${i} processing_time=${time_for_request}s status=${code} body_file=/tmp/${FUNCTION_NAME}-${i}.out"
  ) &
done

wait
echo "Done"
