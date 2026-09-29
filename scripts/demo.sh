#!/bin/sh
set -eu

echo "1) Deploy baseline"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/client.yaml
kubectl rollout status deployment/dummy-service --timeout=60s

echo "2) v1 verification"
kubectl exec traffic-client -- curl -sS --max-time 2 http://dummy-service/health
kubectl exec traffic-client -- curl -sS --max-time 2 http://dummy-service/ready
kubectl exec traffic-client -- curl -sS --max-time 2 http://dummy-service/version

echo "3) Slow v2 rollout"
./scripts/deploy-check.sh v2 150s

echo "4) Start/continue traffic for post-rollout verification"
kubectl exec traffic-client -- sh -c "rm -f /tmp/traffic.log"
kubectl exec traffic-client -- sh -c "sh -s -- 60 1 /tmp/traffic.log" < scripts/traffic-check.sh
kubectl cp traffic-client:/tmp/traffic.log ./traffic-v2.log

echo "5) Broken v3 rollout"
echo "5a) Start traffic in the background while the broken rollout is evaluated"
kubectl exec traffic-client -- sh -c "sh -s -- 150 1 /tmp/traffic-v3.log" < scripts/traffic-check.sh &
TRAFFIC_PID=$!

./scripts/deploy-check.sh v3-broken 120s || true
wait "$TRAFFIC_PID" || true
kubectl cp traffic-client:/tmp/traffic-v3.log ./traffic-v3.log

echo "6) Evidence"
kubectl get pods -l app=dummy-service -o wide
kubectl get endpoints dummy-service -o wide
kubectl describe pods -l app=dummy-service | tail -120
kubectl logs -l app=dummy-service --prefix=true --tail=30

echo "7) Recover to v2"
./scripts/deploy-check.sh v2 150s
kubectl exec traffic-client -- sh -c "sh -s -- 60 1 /tmp/traffic-recovery.log" < scripts/traffic-check.sh
kubectl cp traffic-client:/tmp/traffic-recovery.log ./traffic-recovery.log
