# LLM engineering portfolio

Five small services that each solve one production LLM problem. They run alone or together on one Docker network. Every service runs offline with deterministic mock models and no paid keys. The infrastructure is real: Qdrant, Redis, PostgreSQL, LangGraph and SQLGlot.

The rule they all follow: **the LLM proposes; deterministic code decides** (auth, SQL execution, tool writes, release gates).

| # | Project | What it does |
|---|---|---|
| 1 | [Hybrid RAG](https://github.com/ShanmugaGanesh1999/llm-hybrid-rag/blob/main/README.md) | Tenant-scoped Q&A: dense + BM25 retrieval in Qdrant, RRF, reranking, abstention, validated citations |
| 2 | [LLM gateway](https://github.com/ShanmugaGanesh1999/llm-gateway/blob/main/README.md) | OpenAI-compatible gateway: hashed virtual keys, RPM/TPM limits, budgets, tenant-scoped cache, failover |
| 3 | [Guarded agent](https://github.com/ShanmugaGanesh1999/llm-guarded-agent/blob/main/README.md) | LangGraph ticket agent: strict action schema, durable human approval, idempotent writes |
| 4 | [Text-to-SQL](https://github.com/ShanmugaGanesh1999/llm-text-to-sql/blob/main/README.md) | Analyst questions to vetted SQL: SQLGlot AST policy, read-only least-privilege role, cost budget |
| 5 | [Eval harness](https://github.com/ShanmugaGanesh1999/llm-eval-harness/blob/main/README.md) | Versioned gold set, deterministic metrics, bootstrap CIs, release gate as an exit code |

To prepare for an interview, read [STUDY_GUIDE.md](STUDY_GUIDE.md). The shared contract (ports, tokens, seed data, API shapes) is in [CONVENTIONS.md](CONVENTIONS.md).

## Get the code

Each project is its own repository. This repository pulls all five in as git submodules, so clone it
with `--recursive` to get the combined stack:

```bash
git clone --recursive https://github.com/ShanmugaGanesh1999/llm-engineering-portfolio.git
```

To work on one project only, clone that repository directly (links in the table above).

## Folder map

```text
llm-engineering-portfolio/
├── README.md            this file
├── STUDY_GUIDE.md       interview study guide for all five projects
├── CONVENTIONS.md       shared contract
├── docker-compose.yml   combined stack (Compose include of all five projects)
├── integration.env      combined-stack settings (P1 uses the P2 gateway)
├── scripts/live_eval.sh live evaluation across the combined stack
├── 01-hybrid-rag/       app/ (main, pipeline, store, encoders, ranking, llm, text), data/corpus/, scripts/, tests/
├── 02-llm-gateway/      app/ (main, config, db, limits, cache, router, metrics), mock_provider/, config/, data/, tests/
├── 03-guarded-agent/    app/ (main, config, planner, graph, store), data/, tests/
├── 04-text-to-sql/      app/ (main, catalog, generator, validator, executor, chart), infra/init.sql, data/, tests/
└── 05-eval-harness/     evals/ (cli, datasets, metrics, scoring, gates, live, report, judges), config/, data/gold/, reports/, tests/
```

Every project also has `README.md`, `docs/system-design.md`, `Dockerfile`, `docker-compose.yml` and `scripts/demo.sh`.

## Ports and services

| Project | API service | Host port | Other services |
|---|---|---|---|
| 1 Hybrid RAG | `rag-api` | 8101 | `rag-qdrant` |
| 2 LLM gateway | `gw-api` | 8102 | `gw-redis`, `gw-postgres`, `gw-provider-a` (8112), `gw-provider-b` (8113) |
| 3 Guarded agent | `agent-api` | 8103 | SQLite on volume `p3-agent-data` |
| 4 Text-to-SQL | `sql-api` | 8104 | `sql-postgres` |
| 5 Eval harness | `eval-runner` (one-shot) | none | writes `05-eval-harness/reports/` |

Ports bind to `127.0.0.1`. Each API serves `GET /healthz` and Swagger at `/docs`.

## Quickstart (combined stack)

Start everything. In this stack P1 sends answer generation through P2.

```bash
docker compose up -d --build
```

Check each API:

```bash
for p in 8101 8102 8103 8104; do curl -s localhost:$p/healthz; echo; done
```

Run the offline release gate (P5 on its baseline fixture, exit 0 on pass):

```bash
docker compose run --rm eval-runner
```

Run the live evaluation against P1, P3 and P4. It resets P3 to its seed first, because agent cases close tickets:

```bash
./scripts/live_eval.sh
```

Stop and remove volumes:

```bash
docker compose down -v
```

## Run one project alone

```bash
cd 01-hybrid-rag && docker compose up -d --build && ./scripts/demo.sh
```

Replace `01-hybrid-rag` with any project folder. Tests run in the container, for example `docker compose run --rm rag-api pytest -q`. Stop with `docker compose down -v` in the same folder.

## Demo tokens

These are demo values only. They are not secrets.

| Project | Token | Principal |
|---|---|---|
| P1 | `token-acme-alice`, `token-globex-bob` | tenant `acme` / `globex` |
| P2 | `sk-master-demo` | admin |
| P2 | `sk-demo-team-a` | team-a, 20 RPM, $5 / 30d |
| P2 | `sk-demo-rag-service` | rag-service, 300 RPM (P1 in the combined stack) |
| P2 | `sk-demo-team-b` | team-b, `backup` only, $0.0005 budget |
| P3 | `token-alice`, `token-bob`, `token-rita` | requesters alice and bob, reviewer rita |
| P4 | `token-analyst` | analyst ana |

## Verification status

All tests pass in containers: P1 26, P2 61, P3 30, P4 127, P5 33. The live evaluation (gold set v2, 28 cases) passes 28/28. These numbers come from a tiny demo dataset with deterministic mocks and are not benchmarks. Details are in [STUDY_GUIDE.md](STUDY_GUIDE.md#10-how-this-was-verified).

## Design docs

| Project | README | System design |
|---|---|---|
| 1 Hybrid RAG | [README](https://github.com/ShanmugaGanesh1999/llm-hybrid-rag/blob/main/README.md) | [system-design.md](https://github.com/ShanmugaGanesh1999/llm-hybrid-rag/blob/main/docs/system-design.md) |
| 2 LLM gateway | [README](https://github.com/ShanmugaGanesh1999/llm-gateway/blob/main/README.md) | [system-design.md](https://github.com/ShanmugaGanesh1999/llm-gateway/blob/main/docs/system-design.md) |
| 3 Guarded agent | [README](https://github.com/ShanmugaGanesh1999/llm-guarded-agent/blob/main/README.md) | [system-design.md](https://github.com/ShanmugaGanesh1999/llm-guarded-agent/blob/main/docs/system-design.md) |
| 4 Text-to-SQL | [README](https://github.com/ShanmugaGanesh1999/llm-text-to-sql/blob/main/README.md) | [system-design.md](https://github.com/ShanmugaGanesh1999/llm-text-to-sql/blob/main/docs/system-design.md) |
| 5 Eval harness | [README](https://github.com/ShanmugaGanesh1999/llm-eval-harness/blob/main/README.md) | [system-design.md](https://github.com/ShanmugaGanesh1999/llm-eval-harness/blob/main/docs/system-design.md) |
