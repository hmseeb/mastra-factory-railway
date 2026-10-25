#!/bin/bash
# Contract for the image: what Railway and a deployer rely on. Runs pgvector postgres
# and the image in one network namespace with dummy WorkOS keys (no WorkOS call happens
# until someone signs in), then checks boot, health, dual-stack bind and the email lock.
#   test/contract.sh [image]   (default: builds image/ as mastra-factory-railway:test)
set -uo pipefail
cd "$(dirname "$0")/.."
IMG=${1:-mastra-factory-railway:test}
[ -n "${1:-}" ] || docker build -q -t "$IMG" image >/dev/null || { echo "build failed"; exit 1; }

N=mf-contract-$$; PORT=14111
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fail=1; }
cleanup() { docker rm -f $N-app $N-pg >/dev/null 2>&1; docker volume rm $N-data >/dev/null 2>&1; }
trap cleanup EXIT

docker run -d --name $N-pg -p 127.0.0.1:$PORT:4111 -e POSTGRES_PASSWORD=pg -e POSTGRES_DB=railway \
  pgvector/pgvector:pg18 >/dev/null
for _ in $(seq 1 30); do docker exec $N-pg pg_isready -q -U postgres && break; sleep 1; done

app() {  # extra -e args
  docker rm -f $N-app >/dev/null 2>&1
  docker run -d --name $N-app --network container:$N-pg -v $N-data:/data \
    -e DATABASE_URL=postgres://postgres:pg@127.0.0.1:5432/railway \
    -e MASTRACODE_PUBLIC_URL=http://localhost:$PORT -e FACTORY_SANDBOX_PROVIDER=local \
    -e FACTORY_CREDENTIAL_ENCRYPTION_KEY="$(head -c 32 /dev/urandom | base64)" \
    -e WORKOS_API_KEY=sk_test_dummy -e WORKOS_CLIENT_ID=client_dummy \
    -e WORKOS_COOKIE_PASSWORD=contract-cookie-password-0123456789abcdef \
    "$@" "$IMG" >/dev/null
}
healthy() { for _ in $(seq 1 ${1:-240}); do curl -fs -o /dev/null "http://127.0.0.1:$PORT/health" && return 0
  docker inspect -f '{{.State.Running}}' $N-app 2>/dev/null | grep -q true || return 1; sleep 1; done; return 1; }

# 1. No allowlist: refuse to boot rather than serve an open instance.
app
for _ in $(seq 1 120); do docker inspect -f '{{.State.Running}}' $N-app | grep -q false && break; sleep 1; done
if docker logs $N-app 2>&1 | grep -q 'FACTORY_ALLOWED_EMAILS is required'; then ok "boot refused without FACTORY_ALLOWED_EMAILS"
else no "boot without FACTORY_ALLOWED_EMAILS"; docker logs $N-app 2>&1 | tail -5; fi

# 2. Normal boot.
start=$(date +%s)
app -e FACTORY_ALLOWED_EMAILS=owner@example.com
if healthy; then ok "healthy in $(( $(date +%s) - start ))s"; else no "never healthy"; docker logs $N-app 2>&1 | tail -30; exit 1; fi

# 3. Railway dials over IPv6 and probes over IPv4: both must answer.
docker exec $N-app node -e 'fetch("http://[::1]:4111/health").then(r=>process.exit(r.ok?0:1),()=>process.exit(1))' \
  && ok "answers on [::1]" || no "no IPv6 listener"
docker exec $N-app node -e 'fetch("http://127.0.0.1:4111/health").then(r=>process.exit(r.ok?0:1),()=>process.exit(1))' \
  && ok "answers on 127.0.0.1" || no "no IPv4 listener"

# 4. Browser lands on sign-in; API without a session is refused.
loc=$(curl -s -o /dev/null -w '%{redirect_url}' -H 'Accept: text/html' "http://127.0.0.1:$PORT/")
[[ "$loc" == *signin* || "$loc" == *auth* ]] && ok "browser redirected to sign-in ($loc)" || no "browser not redirected: '$loc'"
c=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/web/factories")
[[ "$c" == 401 || "$c" == 403 ]] && ok "unauthenticated API refused ($c)" || no "unauthenticated API returned $c"

# 5. Schema migrated on boot (pgvector itself is created lazily on first recall use).
t=$(docker exec $N-pg psql -U postgres -d railway -tAc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema')")
[ "${t:-0}" -gt 50 ] && ok "schema migrated ($t tables)" || no "schema has ${t:-0} tables"

# 6. Restart keeps working on the same volume and database.
docker restart $N-app >/dev/null; healthy && ok "healthy after restart" || no "restart"

exit $fail
