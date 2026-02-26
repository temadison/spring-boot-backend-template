# Spring Boot Backend Template

A production-style backend starter template based on the proven `stockdash` backend baseline.

## Why This Exists

This template was created to avoid rebuilding the same backend foundation for each new project.
It packages a repeatable starting point with:

- Java 17+/21 Spring Boot backend
- clean layering (`api`, `service`, `domain`, `repository`, `config`)
- Flyway migrations and startup schema validation
- validation + centralized RFC7807 Problem Details error handling
- structured JSON logs with correlation IDs
- Actuator health/readiness/liveness + Prometheus metrics
- Testcontainers integration tests + JaCoCo quality gate
- Docker Compose local stack + Prometheus/Grafana
- CI pipeline (tests, integration tests, coverage gate, security scan)

## Template Overview

This repo is itself a runnable backend project that doubles as the template source.
Use the scaffolder script to generate a new project from a config file.

## Generate A New Project (JSON or YAML)

From this template repo root:

```bash
./scripts/new-project.sh \
  --config scaffolding/examples/stockdash.template.json \
  --output ../stockdash-regenerated
```

YAML works too:

```bash
./scripts/new-project.sh \
  --config scaffolding/examples/stockdash.template.yaml \
  --output ../stockdash-regenerated-yaml
```

Requirements:

- `rsync`
- `rg`
- `ruby`
- `jq` (for JSON config)
- `yq` (for YAML config)

## Config Schema

`project.moduleName` controls the backend module folder name in generated output (for example `stockdash-backend`, `orders-backend`, or `billing-service`).


```yaml
project:
  displayName: Stock Dashboard
  rootProjectName: stock-dashboard
  moduleName: template-backend
  artifactId: template-backend
  groupId: com.temadison
  version: 1.0-SNAPSHOT
  basePackage: com.temadison.stockdash.backend
  appClassName: StockDashboardApplication
  appPort: 18090
  dbName: stockdash
  dbUser: stockdash_app
  envPrefix: STOCKDASH
```

## Stockdash Example Configs

- `scaffolding/examples/stockdash.template.json`
- `scaffolding/examples/stockdash.template.yaml`

These are included specifically so you can regenerate a fresh stockdash-style project and compare structure/config quickly.
