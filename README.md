# Example of async concurrency limiting patterns in OpenFaaS Standard / For Enterprises

Python `python3-http` function that processes one request at a time per replica and uses async retries for backpressure and processing isolation.

Use-cases:

* Functions that must process one request at a time per replica (e.g. due to external API rate limits or resource contention).
* Functions that must isolate requests for individual customers or tenants (i.e. SIEM or CRM integrations).
* Functions that need to handle long-running jobs with timeouts and retries (e.g. data processing or batch jobs).

The below example shows two variants of the same function with different scaling modes: `capacity` or `queue-based` scaling.

The sample function processes one customer record, and refuses concurrent work.

## Behavior

- Input body is JSON: `customer_name` and `processing_time`.
- Handler prints customer name and sleeps for `processing_time` seconds.
- Concurrency is limited with `max_inflight: "1"` (watchdog env var).
- Function timeouts are set to `300s` (`exec_timeout` and `write_timeout`) for long-running jobs.
- Autoscaling is capacity-based for 1:1 style scaling:
  - `com.openfaas.scale.type: capacity`
  - `com.openfaas.scale.target: "1"`
  - `com.openfaas.scale.target-proportion: "0.95"`
  - `com.openfaas.scale.max: "20"`
- Async retries are configured with high attempts via annotations:
  - `com.openfaas.retry.attempts: "100"`

## Env-substitution style

`stack.yml` uses OpenFaaS YAML env-substitution:

- `provider.gateway: ${OPENFAAS_URL}`
- `image: ${OPENFAAS_PREFIX:-ttl.sh/alexellis}/customer-processor:${OPENFAAS_TAG}`

Set these before deploy:

```bash
export OPENFAAS_URL="https://your-gateway.example.com"
export OPENFAAS_PREFIX="ttl.sh/alexellis"
```

## Publish and deploy

### Option A: override tag at publish/deploy time

```bash
faas-cli up -f stack.yml --tag digest
```

### Option B: image tag from env var / default in `stack.yml`

```bash
faas-cli up -f stack.yml
```

## Start attaching to the logs

The [stern](https://github.com/wercker/stern) tool can be used to tail logs from multiple pods in real-time. stern is available via direct download, or via `arkade install stern`, and may be available via `brew install stern` on macOS.

Unlike `kubectl`, if there is any scaling, `stern` will automatically attach to new pods as they are created, and detach from old pods as they are removed.

In one terminal, attach to all functions:

```
stern -n openfaas-fn 'customer-processor.*' --since 1m | grep "START\|END" 
```

During the test run, you'll see output like:

```
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:13 stdout: START customer=customer-05 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 started_at=2026-03-06T16:07:13.800711+00:00 inflight=1
customer-processor-capacity-6d99798576-qfhxp customer-processor-capacity 2026/03/06 16:07:13 stdout: START customer=customer-03 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-qfhxp started_at=2026-03-06T16:07:13.800330+00:00 inflight=1
customer-processor-capacity-6d99798576-wlqkm customer-processor-capacity 2026/03/06 16:07:13 stdout: START customer=customer-06 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-wlqkm started_at=2026-03-06T16:07:13.801923+00:00 inflight=1
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:13 stdout: START customer=customer-01 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw started_at=2026-03-06T16:07:13.800592+00:00 inflight=1
customer-processor-capacity-6d99798576-qfhxp customer-processor-capacity 2026/03/06 16:07:17 stdout: END customer=customer-03 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-qfhxp completed_at=2026-03-06T16:07:17.804758+00:00 inflight=0
customer-processor-capacity-6d99798576-wlqkm customer-processor-capacity 2026/03/06 16:07:17 stdout: END customer=customer-06 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-wlqkm completed_at=2026-03-06T16:07:17.804766+00:00 inflight=0
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:17 stdout: END customer=customer-05 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 completed_at=2026-03-06T16:07:17.805624+00:00 inflight=0
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:17 stdout: END customer=customer-01 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw completed_at=2026-03-06T16:07:17.804884+00:00 inflight=0
customer-processor-capacity-6d99798576-wlqkm customer-processor-capacity 2026/03/06 16:07:19 stdout: START customer=customer-04 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-wlqkm started_at=2026-03-06T16:07:19.812472+00:00 inflight=1
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:19 stdout: START customer=customer-07 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 started_at=2026-03-06T16:07:19.819506+00:00 inflight=1
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:19 stdout: START customer=customer-10 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw started_at=2026-03-06T16:07:19.829080+00:00 inflight=1
customer-processor-capacity-6d99798576-wlqkm customer-processor-capacity 2026/03/06 16:07:23 stdout: END customer=customer-04 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-wlqkm completed_at=2026-03-06T16:07:23.816177+00:00 inflight=0
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:23 stdout: END customer=customer-07 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 completed_at=2026-03-06T16:07:23.823894+00:00 inflight=0
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:23 stdout: END customer=customer-10 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw completed_at=2026-03-06T16:07:23.834180+00:00 inflight=0
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:27 stdout: START customer=customer-08 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw started_at=2026-03-06T16:07:27.818884+00:00 inflight=1
customer-processor-capacity-6d99798576-qfhxp customer-processor-capacity 2026/03/06 16:07:27 stdout: START customer=customer-02 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-qfhxp started_at=2026-03-06T16:07:27.826463+00:00 inflight=1
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:27 stdout: START customer=customer-09 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 started_at=2026-03-06T16:07:27.837399+00:00 inflight=1
customer-processor-capacity-6d99798576-t9rkw customer-processor-capacity 2026/03/06 16:07:31 stdout: END customer=customer-08 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-t9rkw completed_at=2026-03-06T16:07:31.823548+00:00 inflight=0
customer-processor-capacity-6d99798576-qfhxp customer-processor-capacity 2026/03/06 16:07:31 stdout: END customer=customer-02 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-qfhxp completed_at=2026-03-06T16:07:31.829448+00:00 inflight=0
customer-processor-capacity-6d99798576-rh9p9 customer-processor-capacity 2026/03/06 16:07:31 stdout: END customer=customer-09 processing_time=4.0s hostname=customer-processor-capacity-6d99798576-rh9p9 completed_at=2026-03-06T16:07:31.841823+00:00 inflight=0


```

In another, attach to the queue-worker's recent activity for all replicas:

```
stern -n openfaas queue-worker --since 10m
```

If you don't have stern, after the test you can run one of the following, however it is less reliable, since if a Pod scales down before you can run the command, you won't see its output.

```
faas-cli logs customer-processor-capacity -f stack.yml --since 10m

faas-cli logs customer-processor-queue -f stack.yml --since 10m
```

## Send 10 test requests in capacity mode

```bash
FUNCTION_NAME=customer-processor-capacity \
  MODE=async \
  REQUESTS=10 \
  PROCESSING_TIME=4 \
  ./generate-requests.sh
```

## Send 10 test requests in queue-based scaling mode

Queue based scaling mode allows for more aggressive scaling and better handling of bursts, and requires OpenFaaS for Enterprises.

This requires `jetstreamQueueWorker.mode` to be set to `function` and not `static` in the OpenFaaS helm chart, and a redeployment of the chart after the change.

```bash
FUNCTION_NAME=customer-processor-queue \
  MODE=async \
  REQUESTS=10 \
  PROCESSING_TIME=4 \
  ./generate-requests.sh
```

### Long-running random test (60-180s)

```bash
OPENFAAS_URL="https://your-gateway.example.com" \
MODE=async \
REQUESTS=10 \
PROCESSING_TIME_MODE=random-range \
PROCESSING_TIME_MIN=60 \
PROCESSING_TIME_MAX=180 \
./generate-requests.sh
```

## Pod count observed in load run

In the 10-request async run with `processing_time=4`, `stern` logs showed **3 unique `customer-processor` pods** during the run.
