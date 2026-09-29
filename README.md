# DevOps Demo — Safe Kubernetes Rollout and Broken Release Recovery

## Objective

This demo builds one small HTTP service and deploys it to a local Kubernetes cluster with two replicas. It demonstrates:

- process health vs readiness
- slow-starting v2 rollout
- continuous Service-level traffic checks
- a v3-broken release that remains alive but never becomes ready
- bounded rollout failure detection
- recovery to known-good v2
- evidence from rollout status, probes, endpoints, logs and traffic

No cloud account is required.

## Prerequisites

Tested conceptually with:

- Docker 24+
- kind 0.20+
- kubectl 1.29+
- Bash or a POSIX shell
- Python 3.12 only if running the service outside Docker

On Windows, run the commands from Git Bash or WSL.

## Build

Use a versioned tag; do not use `latest`.

```bash
docker build -t devops-demo:1.0.0 .
kind create cluster --name devops-demo
kind load docker-image devops-demo:1.0.0 --name devops-demo
```

## Deploy baseline

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/client.yaml
kubectl rollout status deployment/dummy-service --timeout=60s
kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service
```

The Deployment starts with v1 because its environment is:

- APP_VERSION=v1
- READY_DELAY_SECONDS=0
- NEVER_READY=false

The image is the same for all releases; release behavior is configuration-driven.

## Direct endpoint behavior

Run through the in-cluster client:

```bash
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/health
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/ready
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/version
```

### Demonstrate v2 readiness delay

Change only the configuration:

```bash
kubectl set env deployment/dummy-service \
  APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
```

While the new pod is starting:

```bash
kubectl get pods -l app=dummy-service -w
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/health
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/ready
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/version
```

Expected: `/health` returns 200 immediately, while `/ready` and `/version` return 503 until approximately 30 seconds after that process starts. After readiness:

```bash
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/ready
kubectl exec traffic-client -- curl -i --max-time 2 http://dummy-service/version
```

## Probes and rollout choices

### Readiness

`/ready` is the traffic gate. Kubernetes removes an unready pod from Service endpoints. The probe runs every 2 seconds with a 1 second timeout.

### Liveness

`/health` answers whether the HTTP process is alive. It is deliberately independent of readiness so a slow or broken release can still prove that its process is running.



### Rolling update

```yaml
maxUnavailable: 0
maxSurge: 1
```

At least the existing ready capacity is retained while a replacement is brought up. A new pod must become Ready before it can receive Service traffic.

`minReadySeconds: 5` adds a small stability window before a ready pod counts toward availability.

`progressDeadlineSeconds: 90` gives the Deployment a bounded period to make progress. The deployment script additionally uses `kubectl rollout status --timeout=...` so the shell command itself has a finite wait and returns non-zero on failure.


Run:

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/client.yaml


kubectl get pods -l app=dummy-service -o wide


kubectl rollout status deployment/dummy-service --timeout=60 
kubectl exec traffic-client -- curl -i http://dummy-service/health
kubectl exec traffic-client -- curl -i http://dummy-service/ready
kubectl exec traffic-client -- curl -i http://dummy-service/version

kubectl get endpoints dummy-service -o wide


kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service -o wide
kubectl exec traffic-client -- curl -i http://dummy-service/health
kubectl exec traffic-client -- curl -i http://dummy-service/ready
kubectl exec traffic-client -- curl -i http://dummy-service/version

2. Start continuous traffic

.\traffic-test.ps1 -DurationSeconds 120


3. Start v2 slow rollout

kubectl set env deployment/dummy-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false


Then:

kubectl rollout status deployment/dummy-service --timeout=150s
4.

kubectl get pods -l app=dummy-service -o wide

5. Prove v2 health vs readiness

Find the v2 pod:

kubectl get pods -l app=dummy-service -o wide


kubectl get pods -l app=dummy-service -o wide
6.
kubectl rollout status deployment/dummy-service --timeout=150s

Then:

kubectl get endpoints dummy-service -o wide

Then:

kubectl exec traffic-client -- curl -i http://dummy-service/version


kubectl set env deployment/dummy-service APP_VERSION=v3-broken READY_DELAY_SECONDS=0 NEVER_READY=true

Immediately:

kubectl get pods -l app=dummy-service 



Get the v3 pod name:

kubectl get pods -l app=dummy-service -o wide

Then:

kubectl describe pod pod-name


kubectl get endpoints dummy-service -o wide

kubectl exec traffic-client -- curl -i http://dummy-service/version

1..10 | ForEach-Object {
    kubectl exec traffic-client -- curl -s http://dummy-service/version
}

12. Demonstrate bounded rollout failure

Run:

kubectl rollout status deployment/dummy-service --timeout=30s

Then:

kubectl get deployment dummy-service

And:

kubectl describe deployment dummy-service
13. Recover to v2

Now recover:

kubectl set env deployment/dummy-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false

Then:

kubectl rollout status deployment/dummy-service --timeout=150
14. Verify recovery
kubectl get pods -l app=dummy-service -o wide

Then:

kubectl get endpoints dummy-service -o wide

Then:

kubectl exec traffic-client -- curl -i http://dummy-service/version


## v2 rollout

```bash
./scripts/deploy-check.sh v2 150s
```

Run traffic while the rollout is happening. The expected behavior is:

- old ready v1 pods continue serving while v2 is unready
- v2 `/health` is 200 but `/ready` is 503 initially
- v2 becomes Ready after roughly 30 seconds from its process start
- Service traffic moves to v2 only after readiness
- rollout status completes only after the Deployment considers the rollout complete

Keep the traffic check running until v2 is fully rolled out and has served traffic for at least 30 seconds.

## Broken v3 release

Start:

```bash
./scripts/deploy-check.sh v3-broken 120s
```

This command is intentionally expected to fail.

Useful evidence:

```bash
kubectl rollout status deployment/dummy-service --timeout=20s || true
kubectl get deployment
kubectl get pods -l app=dummy-service -o wide
kubectl describe pod -l app=dummy-service
kubectl describe deployment dummy-service
kubectl get endpoints dummy-service -o wide
kubectl logs -l app=dummy-service --prefix=true --tail=50
```

What this demonstrates:

1. The v3-broken process is alive because `/health` continues returning 200.
2. `/ready` never returns 200.
3. The broken pod therefore does not become a Service endpoint.
4. Existing ready capacity remains available because `maxUnavailable=0`.
5. Customers can continue receiving successful responses from the known-good version.
6. The release itself is not successful: the Deployment cannot complete the rollout and the bounded check exits non-zero.



## Recovery

Return to known-good v2:

```bash
./scripts/deploy-check.sh v2 150s
kubectl rollout status deployment/dummy-service --timeout=150s
kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service -o wide
kubectl exec traffic-client -- curl -sS --max-time 2 http://dummy-service/version
```

Then run another traffic window:

```bash
kubectl exec traffic-client -- sh -c "sh -s -- 60 1 /tmp/traffic-recovery.log" < scripts/traffic-check.sh
kubectl cp traffic-client:/tmp/traffic-recovery.log ./traffic-recovery.log
```

## Traffic results

Fill these from the actual log output before submission:
Total requests : 21
Successful     : 21
Failed         : 0

Versions observed:

Name Count
---- -----
v2      21



Instances observed:

Name                          Count
----                          -----
dummy-service-fff58496c-t4fjs     6
dummy-service-fff58496c-h7vn6    15

