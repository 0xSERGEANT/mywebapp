# shellcheck shell=bash
# Post-install smoke checks from inside the VM.

set -euo pipefail
IFS=$'\n\t'

readonly CURL_ARGS=(-s -o /dev/null --max-time 5 -w '%{http_code}')
declare -i fail=0

check() {
    local expected="$1" url="$2" label="$3"
    shift 3

    local actual
    actual="$(curl "${CURL_ARGS[@]}" "$@" "$url" 2>/dev/null || echo "000")"

    if [[ "$actual" == "$expected" ]]; then
        printf "PASS  %-25s (%s)\n" "$label" "$actual"
    else
        printf "FAIL  %-25s expected=%s actual=%s\n" "$label" "$expected" "$actual"
        fail+=1
    fi
}

check 200 "http://127.0.0.1:${APP_PORT}/health/alive" 	"health alive (loopback)"
check 200 "http://127.0.0.1:${APP_PORT}/health/ready" 	"health ready (loopback)"
check 200 "http://127.0.0.1/"                       	"root via nginx"            -H "Accept: text/html"
check 200 "http://127.0.0.1/items"                  	"items via nginx (json)"    -H "Accept: application/json"
check 404 "http://127.0.0.1/health/alive"           	"health blocked externally"
check 404 "http://127.0.0.1/admin"                 		"unknown path 404"
check 404 "http://127.0.0.1/.env"                  		"dotfile 404"

(( fail > 0 )) && { echo "99_verify.sh: ${fail} check(s) failed" >&2; exit 1; }
echo "99_verify.sh: all post-install checks passed"