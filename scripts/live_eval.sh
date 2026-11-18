#!/usr/bin/env bash
# Run Project 5's live evaluation against the combined stack (P1 via P2 gateway, P3, P4).
# Agent cases change ticket state, so Project 3 is reset to its seed data first.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Resetting Project 3 (agent) to seed state"
docker compose rm -sf agent-api >/dev/null
docker volume rm -f llm-portfolio_p3-agent-data >/dev/null
docker compose up -d agent-api >/dev/null

echo "== Waiting for all APIs"
for port in 8101 8102 8103 8104; do
  for _ in $(seq 1 60); do curl -sf "localhost:$port/healthz" >/dev/null && break; sleep 1; done
  curl -sf "localhost:$port/healthz" >/dev/null || { echo "port $port not healthy"; exit 2; }
done

echo "== Live evaluation"
EVAL_MODE=live EVAL_OUT=reports/live_report.json docker compose run --rm eval-runner
echo "Report: 05-eval-harness/reports/live_report.md"
