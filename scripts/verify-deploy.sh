#!/usr/bin/env bash

set -euo pipefail

TARGET="${TARGET:?TARGET must be set (host or IP of target node)}"
TARGET_HTTP_PORT="${TARGET_HTTP_PORT:-80}"
BASE="http://${TARGET}"
[[ "$TARGET_HTTP_PORT" != "80" ]] && BASE="http://${TARGET}:${TARGET_HTTP_PORT}"

pass=0
fail=0

check_code() {
    local label="$1" expected="$2" url="$3"
    shift 3
    local actual
    actual="$(curl -sS -o /dev/null --max-time 10 -w '%{http_code}' "$@" "$url" || echo "000")"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS  ${label}  (${actual})"
        pass=$((pass + 1))
    else
        echo "FAIL  ${label}  expected=${expected} actual=${actual}"
        fail=$((fail + 1))
    fi
}

echo "== verify-deploy.sh: ${BASE} =="

check_code "items JSON 200"     200 "${BASE}/items"  -H 'Accept: application/json'
check_code "items HTML 200"     200 "${BASE}/items"  -H 'Accept: text/html'
check_code "root HTML 200"      200 "${BASE}/"       -H 'Accept: text/html'

check_code "admin 200"          200 "${BASE}/admin"
check_code "dotfile 404"        404 "${BASE}/.env"
check_code "health blocked"     404 "${BASE}/health/alive"

# POST + GET roundtrip
NAME="verify-$(date +%s)"
CREATED="$(curl -sS --max-time 10 \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "{\"name\":\"${NAME}\",\"quantity\":1}" \
    "${BASE}/items" || echo '')"

NEW_ID="$(echo "$CREATED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null || echo '')"

if [[ -n "$NEW_ID" ]]; then
    echo "PASS  POST created id=${NEW_ID}"
    pass=$((pass + 1))
    check_code "GET created 200" 200 "${BASE}/items/${NEW_ID}" -H 'Accept: application/json'
else
    echo "FAIL  POST returned no id (body: ${CREATED:0:100})"
    fail=$((fail + 1))
fi

echo ""
echo "summary: ${pass} passed, ${fail} failed"
exit "$fail"