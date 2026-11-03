# CI/CD and environment gates

## Environment map

| CymBuild logical environment | SOCOTEC physical meaning | Generated-test policy |
|---|---|---|
| DEV | Stephen/local developer environment | Full local unit/component and disposable integration testing; controlled synthetic writes allowed. |
| QA | SOC-CONIIS `_Dev` site/service + the database in `appsettings.QA.json` | Automated integration and functional journeys with controlled test identities/data. |
| UAT | SOCOTEC UAT | Approval-controlled functional/regression tests; writes only through an agreed isolated test-data policy. |
| LIVE | SOCOTEC LIVE | Restricted, explicitly approved, non-mutating smoke/health/render/read-only checks only. |

The exact credentials, endpoints, namespaces, and test-user provisioning belong
in protected pipeline/environment configuration, not `AGENTS.md`, test cases,
source code, or agent output.

## Application hosting

QA, UAT and LIVE are hosted on the Windows/IIS server **SOC-CONIIS**
(`soc-coniis.esgl.co.uk`), confirmed by read-only discovery on 2026-10-13.
IIS/Windows-service hosting is the intended long-term model.

| Environment | PWA (IIS static site) | API (Windows service, Kestrel) |
|---|---|---|
| QA | site/pool `Concursus.PWA_Dev`, `C:\inetpub\wwwroot\Concursus.PWA_Dev`, `https://cymbuild-dev.socotec.co.uk` | service `Concursus.API_dev`, `C:\Program Files\Concursus.API_Dev`, `https://cymbuild-dev.socotec.co.uk:9401` |
| UAT | site/pool `Concursus.PWA_Test`, `https://cymbuild-uat.socotec.co.uk` | service `Concursus.API_Test`, port 9501 |
| LIVE | site/pool `Concursus.PWA`, `https://cymbuild.socotec.co.uk` | service `Concursus.API`, port 9601 |

Each deployed folder owns its environment configuration: `appsettings.json`
(API root, PWA `wwwroot\`), `web.config`, the API's `nlog.config` and `logs\`. Those files are edited on
the server and are never replaced from a build. The `appsettings.<Env>.json`
files in source control are reference copies, not what the server loads, with one
exception: the deploy script reads the database server and name from them.

QA and UAT deployment is automated by
[`tools/Deployment/Publish-CymBuildServer.ps1`](../tools/Deployment/README.md),
including the database phase: a verified COPY_ONLY backup of the target database, then
schema and metadata migration from the previous environment (accepted workbench runs
first, otherwise new runs selecting every supported difference). The databases come from
the committed `services/Concursus.API/appsettings.<Env>.json`:

| Target | Target database from | Source database from |
|---|---|---|
| QA | `appsettings.QA.json` | `appsettings.Development.json` (DEV) |
| UAT | `appsettings.Test.json` | `appsettings.QA.json` (QA) |

When a database is renamed, update that file (keep it matching the server's own
appsettings) and commit it before deploying. LIVE remains manual and is deliberately not
configured in that script.

The `k8s/` manifests and Dockerfiles under `services/` and `apps/` are not used
by any current environment.

## Build and promotion policy

- Build each release once from a clean, committed source tree.
- Record the release identity, branch, commit and a SHA-256 manifest of every
  published file; verify that manifest on the target after transfer and after
  the files are switched.
- Promote the same verified package rather than rebuilding per environment.
- Back up the live files before every switch and keep the backup until a later
  release supersedes it.
- Keep stateful services such as SQL Server external to the application hosts.
- The current Sage Wrapper is the active Sage boundary; the retained legacy
  Sage microservice is not part of the current build/deploy matrix.

## Proposed pull-request pipeline gates

Run commands confirmed from the current repo in this logical order:

1. restore/build/format/static validation;
2. test-case and metadata manifest validation;
3. architecture tests;
4. fast unit and component tests;
5. API client, API, shared, and EF tests;
6. SQL integration and schema/metadata deployment repeatability tests where the
   change impact requires them;
7. publish the application packages and smoke-test them without deploying;
8. produce a test-impact/coverage report and immutable artefact identity.

A pull-request pipeline does not deploy merely because tests pass.

## Deployment order

The approved release uses explicit gates:

1. verify release identity, approved definition/hash, and target environment;
2. run schema validation/WhatIf against controlled target;
3. apply idempotent schema through the source-controlled deployment runner;
4. verify schema and audit result;
5. validate source-controlled metadata and dependency order;
6. preview/apply the approved metadata definition by stable Guid;
7. verify metadata convergence and audit result;
8. deploy/promote the verified application package;
9. wait for service and site health;
10. run the environment-allowed smoke and functional suites;
11. retain test, deployment, transition, and outbox diagnostics.

If the established CymBuild pipeline deliberately deploys the application
before a particular compatible migration step, preserve that behaviour until a
reviewed release design changes it. The required invariant is that compatibility
and rollback/forward strategy are explicit and tested; do not reorder a live
pipeline from this document alone.

## Failure behaviour

- Stop on schema or metadata validation failure.
- Do not run metadata apply after schema apply failed.
- Do not run schema or metadata migration without a verified backup.
- QA/UAT exception (agreed 2026-10-13): `Publish-CymBuildServer.ps1` still deploys the
  application when a database step fails. The failure is reported in the
  deployment summary and schema/metadata must then be completed manually through
  the workbenches. Elsewhere, do not deploy the application when required
  schema/metadata verification failed.
- Do not patch the target database manually to make the next stage green.
- Preserve the original error while running only established safe recovery or
  post-deployment restoration logic.
- A retry uses the same approved release/run identity and supported retry path;
  it does not silently restage from a changed source.
- Publish diagnostics without connection strings, tokens, personal data, or
  secret values.

## Generated test artefacts

The agent may create candidate case manifests during development. CI should:

- validate committed manifests deterministically;
- fail for invalid/duplicate IDs or prohibited LIVE write modes;
- run only committed generated test code or deterministic parameterised tests;
- record the generator/tool version and source commit;
- fail when generated output is stale, if generated code is committed;
- never call an LLM to decide pass/fail or create new expectations mid-run.

## Smoke-test scope

Post-deployment smoke should cover application health, gRPC reachability,
authorisation, representative metadata render, critical SQL/query availability,
worker/outbox health, and current active integration routes. LIVE smoke excludes
create/edit/transition/integration-triggering operations unless a separately
approved, demonstrably non-production test channel exists.
