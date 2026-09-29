#!/bin/sh
set -eu

VERSION="${1:-v2}"
TIMEOUT="${2:-120s}"

case "$VERSION" in
  v1)
    kubectl set env deployment/dummy-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false
    ;;
  v2)
    kubectl set env deployment/dummy-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
    ;;
  v3-broken)
    kubectl set env deployment/dummy-service APP_VERSION=v3-broken READY_DELAY_SECONDS=0 NEVER_READY=true
    ;;
  *)
    echo "Usage: $0 {v1|v2|v3-broken} [timeout]" >&2
    exit 2
    ;;
esac

echo "Waiting for rollout: $VERSION"
if kubectl rollout status deployment/dummy-service --timeout="$TIMEOUT"; then
  echo "ROLLOUT SUCCESS: $VERSION"
  exit 0
else
  echo "ROLLOUT FAILED/TIMED OUT: $VERSION"
  kubectl get deployment,pod 2>/dev/null || true
  kubectl get pods -l app=dummy-service -o wide || true
  kubectl describe deployment dummy-service | tail -80 || true
  exit 1
fi
