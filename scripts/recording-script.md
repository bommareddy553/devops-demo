# 5–10 Minute Recording Guide

## 0:00–1:00 — Service

Show `app.py`.

Say:

> "This is intentionally small. The HTTP listener starts immediately. `/health` means the process is alive. `/ready` is the traffic gate. `/version` is the customer-facing test endpoint. Readiness is based on elapsed time from process start, so a 30-second v2 delay does not block health."

Show v1 and v2/v3 configuration.

## 1:00–2:30 — Kubernetes design

Show `deployment.yaml`.

Explain:

- two replicas
- ClusterIP Service
- readiness on `/ready`
- liveness on `/health`
- no startup probe because the process listener is available immediately
- `maxUnavailable: 0`
- `maxSurge: 1`
- resource requests/limits
- bounded `progressDeadlineSeconds`

## 2:30–4:00 — v1 to v2

Show:

```bash
kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service
```

Start the in-cluster traffic check.

Roll out v2.

Point out that the new v2 pod can be alive but not ready. Existing ready pods continue to serve. Show the traffic log changing to v2 after readiness.

## 4:00–6:30 — v3-broken

Run:

```bash
./scripts/deploy-check.sh v3-broken 120s
```

While it waits, show:

```bash
kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service -o wide
kubectl describe pod <broken-pod>
kubectl describe deployment dummy-service
```

Explain:

> "The process is alive, but this release is not successful because readiness never occurs. The Service excludes the broken pod. The old ready capacity remains because maxUnavailable is zero. The rollout check eventually exits non-zero because it is bounded."

Show traffic still succeeding through the Service.

## 6:30–8:00 — Recovery

Run:

```bash
./scripts/deploy-check.sh v2 150s
```

Then show:

```bash
kubectl rollout status deployment/dummy-service --timeout=150s
kubectl get pods -l app=dummy-service
kubectl get endpoints dummy-service
kubectl exec traffic-client -- curl -sS http://dummy-service/version
```

Show the recovery traffic results.

## 8:00–9:00 — Engineering decisions

Mention one difficulty:

> "The main timing issue is that local scheduling and image startup can make exact seconds vary, so I measure readiness from each process start and use Kubernetes state rather than fixed sleeps."

Mention one production improvement:

> "In production I would combine rollout state with application error-rate and latency alerts, use deployment automation with automatic rollback where appropriate, and keep SLO-based customer impact signals separate from pod health."

End with:

> "The important distinction is process health, readiness, rollout completion, and customer impact. This demo measures each separately."
