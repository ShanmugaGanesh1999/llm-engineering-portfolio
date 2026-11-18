#!/usr/bin/env bash
# Full verification: each project alone (build, demo, tests, teardown), then the combined stack
# with the live cross-project evaluation. Prints one PASS/FAIL line per step and exits non-zero
# if any step failed.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
LOG=$ROOT/reports/verify; mkdir -p "$LOG"
fails=0
check() {  # check "<label>" <command...>
  local label=$1; shift
  if "$@" > "$LOG/$(echo "$label" | tr ' /' '__').log" 2>&1; then echo "PASS  $label"
  else echo "FAIL  $label  (log: reports/verify/$(echo "$label" | tr ' /' '__').log)"; fails=$((fails+1)); fi
}
wait_healthy() {  # wait_healthy <port>
  for _ in $(seq 1 90); do curl -sf "localhost:$1/healthz" >/dev/null && return 0; sleep 1; done; return 1
}

docker compose down -v >/dev/null 2>&1

for spec in "01-hybrid-rag rag-api 8101" "02-llm-gateway gw-api 8102" \
            "03-guarded-agent agent-api 8103" "04-text-to-sql sql-api 8104"; do
  set -- $spec; dir=$1 svc=$2 port=$3
  cd "$ROOT/$dir"
  check "$dir up"     docker compose up -d --build
  check "$dir health" wait_healthy "$port"
  check "$dir demo"   bash scripts/demo.sh
  check "$dir tests"  docker compose run --rm "$svc" pytest -q
  docker compose down -v >/dev/null 2>&1
done

cd "$ROOT/05-eval-harness"
check "05-eval-harness demo"  bash scripts/demo.sh
check "05-eval-harness tests" docker compose run --rm eval-runner pytest -q
docker compose down -v >/dev/null 2>&1

cd "$ROOT"
check "combined up" docker compose up -d --build
for port in 8101 8102 8103 8104; do check "combined health $port" wait_healthy "$port"; done
check "combined live eval" ./scripts/live_eval.sh
docker compose down -v >/dev/null 2>&1

echo "failed steps: $fails"
exit $(( fails > 0 ))
