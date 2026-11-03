# AGENTS.md — CymBuild

Repository rules for AI coding agents working on CymBuild. Read this file before
changing code. If a nested `AGENTS.md` or an applicable repository instruction
file exists, read it as well; the most specific instruction wins.

## Non-negotiable architecture

- Preserve the application flow: **Blazor PWA UI → FormHelper/API client → gRPC
  API → EF/repository → SQL Server**.
- UI components must not call the API or database directly and must not contain
  business rules. Put client coordination in FormHelper, server validation and
  orchestration in the gRPC API, and persistence in EF/repositories or controlled
  SQL.
- Every managed entity insert must atomically create the corresponding
  `SCore.DataObjects` row with the correct `EntityTypeId`.
- Never update workflow status directly. Use
  `SCore.DataObjectTransitionUpsert`; the latest transition is current state.
- Use `SCore.IntegrationOutbox` for integration events. Producers and consumers
  must be idempotent, retry-safe, and diagnosable.

See [architecture and data rules](docs/architecture-and-data-rules.md).

## Code-first and metadata rules

- Source-controlled SQL is the schema source of truth. The database is a
  deployment target, not the source of a fix.
- Source-controlled manifests are the metadata source of truth. Do not edit
  metadata directly in a database.
- Deploy in this order: idempotent schema → metadata validation → idempotent
  metadata apply by stable Guid → verification.
- Preserve metadata dependency order, including **Grid → View → Columns**.
- Do not create duplicate metadata. Never depend on environment-specific numeric
  IDs when a stable Guid or controlled natural key exists.
- Do not run schema or metadata migration from application startup.

## SQL and UI rules

- Use schema-qualified names, explicit columns, and idempotent scripts. Never use
  `SELECT *`.
- Active-row logic uses `RowStatus NOT IN (0,254)` unless an exact existing
  contract requires a different expression.
- Do not guess missing schema, procedures, entity types, metadata properties, or
  component contracts. Inspect the current source; if it is not present, ask.
- Preserve existing behaviour unless the requested change explicitly alters it.
- Do not hard-code UI behaviour or labels when metadata already controls them.
- Do not introduce Telerik unless explicitly requested.

## Required test workflow

1. Establish the requested behaviour and inspect the exact affected code,
   contracts, SQL, metadata manifests, and existing tests.
2. Map the change to all affected test layers using
   [testing strategy](docs/testing-strategy.md).
3. Add or update tests with the change. For metadata-driven screens, use
   [metadata-driven UI testing](docs/metadata-driven-ui-testing.md), not a
   page-name-only test.
4. Generate candidate test-case manifests only from source-controlled evidence,
   using [test-case generation](docs/test-case-generation.md). Review and commit
   the cases before CI executes generated artefacts.
5. Run the smallest relevant tests first, then the repository fast suite, then
   SQL/integration/browser tests when the change requires them.
6. Report commands run, results, tests not run, and residual risk. A test not run
   is not a passing test.

The agent must never query LIVE to discover test cases, run generated write tests
against LIVE, or generate new tests nondeterministically inside CI.

## Environment and delivery safety

- CymBuild logical environments are DEV → QA → UAT → LIVE. QA, UAT and LIVE
  are hosted on the Windows/IIS server SOC-CONIIS: the PWA is an IIS static
  site and the API is a Windows service running Kestrel. QA uses the `_Dev`
  site and service with the database named in
  `services/Concursus.API/appsettings.QA.json`. UAT is controlled and
  LIVE is restricted. CymBuild is not deployed through containers or a
  pipeline.
- Deploy QA and UAT with `tools/Deployment/Publish-CymBuildServer.ps1`
  (`-Environment UAT`). Extend that script rather than adding manual copy
  steps. LIVE stays manual until it is explicitly extended to it. Database
  names come from the committed `services/Concursus.API/appsettings.<Env>.json`;
  never hard-code them in the script.
- Build each release once from a clean, committed tree, verify its SHA-256
  manifest on the server, and back up the live files before switching.
- Never overwrite server-owned files from a build: `appsettings*.json`,
  `web.config`, `nlog.config` and `logs\`.
- Do not commit, push, create a pull request, force-push, deploy, or modify a
  remote system unless the user explicitly asks for that action.
- Never make manual QA/UAT/LIVE database changes as a substitute for a
  source-controlled deployment.
- Preserve unrelated working-tree changes and avoid destructive Git operations.

See [CI/CD and environments](docs/ci-cd-and-environments.md) and
[review and delivery](docs/review-and-delivery.md).

## Before executable adoption

Complete the [adoption plan](docs/adoption-plan.md) and resolve the evidence
items in [open decisions](docs/open-decisions.md). Do not fill gaps by guessing.

Do not add `Co-Authored-By` lines to commits.

## Shared .NET guidance

Read [the shared .NET guidance](vendor/agents-template/docs/dotnet.md) before
planning or changing .NET code. The CymBuild-specific rules in this file take
precedence if the shared guidance conflicts with them.
