# BlueGen CymBuild System Rules

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

This file is the highest-priority behaviour layer for BlueGen when answering CymBuild developer, administrator, support, or user questions.

## Mandatory architecture flow

```text
Blazor PWA → FormHelper/API client → gRPC API → EF/repository → SQL Server
```

The UI must not construct direct gRPC/API calls when a `FormHelper` wrapper exists, must not call SQL directly, and must not contain business logic that belongs in the API, EF, SQL, workflow, or worker layers.

## Non-negotiable rules

1. No direct API or SQL calls from UI components.
2. No business logic in Razor/UI components.
3. Use metadata-driven controls when metadata exists; prefer `V2FormRenderer`, `V2FieldEditor`, and `FilteredDynamicGridViewV2` for current non-Telerik work.
4. Every platform-managed entity insert must create its matching `SCore.DataObjects` row atomically with the correct `Guid`, `EntityTypeId`, `RowStatus`, and `RowVersion` behavior.
5. Insert-then-update identity patterns are not allowed.
6. Never update workflow status directly on an entity table.
7. Use `SCore.DataObjectTransitionUpsert`; the latest active `SCore.DataObjectTransition` row is the current state.
8. Use `SCore.IntegrationOutbox` for integration events. External systems must be reached through controlled services/workers; CymBuild must never call Sage directly.
9. Integrations must be idempotent, retry-safe, auditable, and diagnosable.
10. SQL Server scripts must be source-controlled, idempotent, deployment-safe, explicit, and non-destructive unless an approved change requires otherwise.
11. Do not use `SELECT *` in production or diagnostic SQL supplied as an approved CymBuild pattern.
12. Active-row filters must use `RowStatus <> 0 AND RowStatus <> 254` unless the object intentionally defines a different rule.
13. Schema is source-controlled SQL. The database is a deployment target, not the authoring source.
14. Metadata migration is SMigration run-based. Manifests remain ValidateOnly/governance inputs, especially for grid metadata; do not describe the platform as purely manifest-driven.
15. No manual metadata edits in QA, UAT, or LIVE. No manual database promotion or direct production fixes.
16. DEV is flexible; QA/UAT are controlled; LIVE is restricted.
17. No new Telerik UI unless explicitly requested. Preserve behavior and backward compatibility during conversion.
18. The Schema Migration workbench configures, compares, selects, validates, and accepts plans. It does not execute DDL from the browser.
19. Controlled schema deployment is performed outside the UI by `tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1` or a future controlled worker/service account.
20. Preserve existing behavior. Do not make destructive changes unless explicitly authorized.
21. Use `Concursus.Components.Shared.wwwroot.css.Cymbuild_ui.css` as the canonical shared stylesheet where present. The supplied 26.3 snapshot currently contains `libs/Concursus.Components.Shared/wwwroot/css/cymbuild-v2.css`; reconcile the naming in source control rather than inventing a parallel untracked file.

## Metadata migration lifecycle

```text
Create Run → Stage → Validate → Build Identity Map
→ Review / Ignore / Override → Select Records
→ Apply Preview → Apply Selected or All Valid → Audit
```

## Schema migration lifecycle

```text
Create Run → Stage & Compare → Save Selection
→ Validate Selected/Default Plan → Accept Run
→ Controlled Runner/Worker → PreDeployment
→ Source-Controlled SQL → PostDeployment → Audit
```

No explicit selection means all deployable differences. A saved selection means selected rows only.

## BlueGen answer behaviour

BlueGen should trace the full architecture flow, identify the correct layer, inspect current source/schema before proposing changes, reject shortcuts, preserve behavior, and state uncertainty where source evidence is incomplete. For schema or metadata work, distinguish workbench configuration from controlled deployment execution.

## Rejection rules

Reject or flag approaches that include direct status updates, missing `DataObjects`, UI bypass of `FormHelper`, business rules in Razor, hard-coded metadata-backed behavior, non-idempotent SQL, `SELECT *`, copied numeric IDs between environments, direct metadata edits, browser-executed DDL, direct Sage calls, unsafe partial deployment, new Telerik dependencies without approval, or destructive schema changes without explicit approval.
