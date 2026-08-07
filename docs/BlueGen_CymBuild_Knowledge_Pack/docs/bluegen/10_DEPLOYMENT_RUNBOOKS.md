# CymBuild Deployment Runbooks

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## Environment principles

```text
DEV = flexible
QA = controlled
UAT = controlled and business-facing
LIVE = restricted; no direct fixes or browser DDL
```

## Standard 26.3 order

```text
1. Idempotent schema deployment
2. Metadata stage/validate/identity-map review
3. Metadata apply preview and controlled apply
4. API/worker deployment
5. PWA deployment
6. Post-deploy diagnostics and audit
```

## Schema workbench boundary

The PWA workbench is configuration, comparison, selection, validation and acceptance only:

```text
PWA → FormHelper.SchemaMigration → gRPC → SMigration persistent plan
```

It does not execute DDL. The copyable SQL only reads the plan.

## R27 controlled runner

Run from the repository root under a controlled deployment account.

Dry-run:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "<SERVER>" `
    -TargetDatabase "<DATABASE>" `
    -RunGuid "<ACCEPTED-RUN-GUID>" `
    -ReleaseReference "26.3" `
    -WhatIf
```

Apply:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "<SERVER>" `
    -TargetDatabase "<DATABASE>" `
    -RunGuid "<ACCEPTED-RUN-GUID>" `
    -ReleaseReference "26.3" `
    -Apply
```

A failed reviewed run may be retried only after correction:

```powershell
-Apply -RetryFailedDeployment
```

### Runner guarantees

- Reads `SMigration.SchemaDeploymentPlan_Get`.
- Requires reviewed/accepted plan except restricted DEV override behavior.
- Deploys only canonical files under `Database/CymBuild_DB/Schema`.
- Never executes captured source-database DDL.
- Defaults to dry-run.
- `-WhatIf` writes no deployment/audit rows.
- Blocks unsupported rows unless deliberate `-AllowPartial` is provided; do not use partial apply for a complete release plan.
- Runs `SCore.PreDeploymentScript` before object deployment.
- Runs `SCore.PostDeploymentScript` after success except for `CymBuild_Dev`.
- Attempts post-deployment recovery if apply fails after pre-deployment maintenance.
- Writes `SMigration.Schema_ExecutionLog` atomically with `SCore.DataObjects` through `SMigration.SchemaDataObject_Ensure`.
- Blocks production-looking targets unless `-AllowLive` is explicitly supplied.

## Metadata deployment

Use the run-based workbench lifecycle. Manifests provide ValidateOnly/governance support. No direct target edits, copied numeric IDs, or manual promotion.

## API/worker and PWA deployment

Confirm schema compatibility, feature toggles, worker enablement, idempotency/retry behavior, client/API proto compatibility, service-worker/cache refresh, and non-Telerik parity.

## Post-deploy checks

- Confirm run status and execution logs.
- Recompare schema with a new/preserved audit run.
- Smoke test login, navigation, dynamic forms/grids and workflow actions.
- Validate metadata-controlled changes.
- Test relevant workers, outbox, Sage microservice diagnostics and SharePoint/Outlook flows.
- Never validate status by directly changing an entity status column.

## Future Phase 2

A future Run Deployment button must queue controlled work:

```text
PWA → FormHelper → gRPC → IntegrationOutbox/deployment queue
→ controlled worker/service account → SQL Server
```

The browser/user session must not receive DDL permissions.
