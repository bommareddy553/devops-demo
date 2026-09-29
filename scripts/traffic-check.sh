#!/bin/sh
set -eu

DURATION="${1:-60}"
INTERVAL="${2:-1}"
OUT="${3:-traffic.log}"
END=$(( $(date +%s) + DURATION ))

echo "timestamp,status,error,version,instance" > "$OUT"

while [ "$(date +%s)" -lt "$END" ]; do
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  BODY="$(curl -sS --max-time 2 -w '\nHTTP_STATUS:%{http_code}' http://dummy-service/version 2>&1 || true)"
  STATUS="$(printf '%s\n' "$BODY" | sed -n 's/^HTTP_STATUS://p' | tail -1)"
  JSON="$(printf '%s\n' "$BODY" | sed '/^HTTP_STATUS:/d' | tail -1)"

  if [ "$STATUS" = "200" ]; then
    VERSION="$(printf '%s' "$JSON" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
    INSTANCE="$(printf '%s' "$JSON" | sed -n 's/.*"instance":"\([^"]*\)".*/\1/p')"
    echo "$TS,200,,${VERSION:-unknown},${INSTANCE:-unknown}" | tee -a "$OUT"
  else
    ERR="$(printf '%s' "$JSON" | tr ',' ';' | tr '\n' ' ' | cut -c1-120)"
    echo "$TS,${STATUS:-000},${ERR},," | tee -a "$OUT"
  fi

  sleep "$INTERVAL"
done

echo
echo "=== Summary ==="
TOTAL=$(awk 'NR>1 {n++} END {print n+0}' "$OUT")
SUCCESS=$(awk -F, 'NR>1 && $2=="200" {n++} END {print n+0}' "$OUT")
FAIL=$(awk -F, 'NR>1 && $2!="200" {n++} END {print n+0}' "$OUT")
echo "total_requests=$TOTAL"
echo "successful_requests=$SUCCESS"
echo "failed_requests=$FAIL"
echo "versions_observed:"
awk -F, 'NR>1 && $4!="" {print $4}' "$OUT" | sort | uniq -c
echo "instances_observed:"
awk -F, 'NR>1 && $5!="" {print $5}' "$OUT" | sort | uniq -c
