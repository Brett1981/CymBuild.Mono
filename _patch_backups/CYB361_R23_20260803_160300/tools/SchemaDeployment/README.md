# CYB-361 Manual Schema Deployment Runner (R22)

This is the controlled manual implementation of the future schema deployment worker.

The CymBuild Schema Migration workbench remains a configuration, validation and acceptance tool. It does not execute DDL from the browser. The runner is executed from the repository root by a controlled deployment machine/account and follows this boundary:

`PWA → FormHelper → gRPC API → SMigration accepted plan`

then, outside the browser:

`PowerShell runner → source-controlled SQL → target SQL Server → SMigration audit`

## Dry run

Dry-run is the default. `-WhatIf` is shown explicitly for clarity.

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
    -ReleaseReference "26.3" `
    -WhatIf
```

Dry-run:

- reads the accepted run and `SMigration.SchemaDeploymentPlan_Get`;
- resolves source-controlled SQL files;
- writes plan, supported and unsupported artefacts;
- writes an inspection-only generated SQL file;
- executes no SQL batches;
- writes no SMigration audit or deployment rows.

## Apply

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
    -ReleaseReference "26.3" `
    -Apply
```

Apply requires the run to be in the accepted `Reviewed` state. Saving or clearing a deployment selection resets validation and acceptance, so the current plan must be validated and accepted again before deployment.

## Deployment-plan behaviour

The runner calls:

```sql
EXEC [SMigration].[SchemaDeploymentPlan_Get]
    @RunGuid = @RunGuid;
```

The stored procedure controls scope:

- saved explicit selection: only selected deployable differences;
- no active selection rows: all deployable differences.

No captured `SourceDefinition` or source-database DDL is executed. Every object is resolved to a file under:

```text
Database/CymBuild_DB/Schema
```

Resolved paths are canonicalised and rejected if they escape that source-controlled root.

## Supported objects

Automatically supported:

- `Schema`: created only when missing.
- `Function`, `View`, `StoredProcedure`: source-controlled `CREATE` is converted to `CREATE OR ALTER`.
- `Table`, `TableType`, `Sequence`: only when `DifferenceType = MissingInTarget`; the runner checks again immediately before execution and skips a non-destructive recreate if the object already exists.

Not automatically supported:

- existing table, table type or sequence structural changes;
- standalone constraints and indexes;
- triggers.

These require a dedicated source-controlled, idempotent, non-destructive migration script or a future controlled extractor. Unsupported selected rows block deployment unless `-AllowPartial` is explicitly supplied. With `-AllowPartial`, only resolved supported rows are applied and the run is recorded as `DeploymentPartiallyApplied`.

## Pre/post deployment

Apply mode runs:

1. `SCore.PreDeploymentScript`;
2. selected source-controlled schema objects in deployment-plan order;
3. `SCore.PostDeploymentScript`, except when the target database is `CymBuild_Dev`.

Skip switches remain available for controlled diagnostics, but they do not grant browser execution or bypass LIVE protection.

## Audit and DataObjects

Apply mode writes `SMigration.Schema_ExecutionLog` entries. Each log row is created atomically with its matching `SCore.DataObjects` row through:

```sql
EXEC [SMigration].[SchemaDataObject_Ensure]
```

Successful apply updates `SMigration.Schema_Run`. A failure after deployment starts records `DeploymentFailed` and a failure audit entry. Dry-run never writes these records.

## Environment guardrails

- The run target, requested target and actual opened SQL connection are checked.
- `-SkipAcceptanceCheck` apply mode is restricted to DEV-like databases.
- LIVE/production-looking targets are blocked unless `-AllowLive` is explicitly supplied under the approved LIVE release procedure.
- A custom `-ConnectionString` cannot silently redirect apply mode to a different database/server without the target mismatch guard or an explicit approved override.

## Output

Default location:

```text
artifacts/schema-deployment/<RunGuid>/
```

Files:

```text
deployment-plan.csv
resolved-items.csv
unsupported-items.csv
summary.json
manual-preview-deployment.sql
```

`manual-preview-deployment.sql` is inspection-only. The approved execution path is the PowerShell runner because it enforces object existence checks, environment controls and SMigration audit.

## R22 corrections

R22 includes:

- the R21 generic-list/StrictMode fix using typed arrays and `List<T>.ToArray()`;
- the R20 DataTable fix by returning query results without PowerShell enumeration;
- the correct `MissingInTarget` comparison value;
- typed SQL parameters and deterministic command/adapter disposal;
- direct consumption of `SMigration.SchemaDeploymentPlan_Get`;
- no WhatIf failure-audit writes;
- DataObjects-compliant execution logging;
- stronger requested/run/actual target checks and LIVE protection;
- deterministic `-AllowPartial` handling.
