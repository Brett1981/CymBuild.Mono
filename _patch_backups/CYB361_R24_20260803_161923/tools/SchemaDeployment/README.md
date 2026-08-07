# CYB-361 Manual Schema Deployment Runner (R23)

This is the controlled manual implementation of the future schema deployment worker.

The CymBuild Schema Migration workbench remains configuration, validation and acceptance only. It does not execute DDL from the browser. The runner is executed from the repository root by a controlled deployment machine/account:

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
- resolves canonical or explicitly allowlisted source-controlled SQL files;
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

No captured `SourceDefinition` or source-database DDL is executed. Every object resolves to an approved file under:

```text
Database/CymBuild_DB/Schema
```

Resolved paths are canonicalised and rejected if they escape that source-controlled root.

## Supported objects

Automatically supported:

- `Schema`: created only when missing.
- `Function`, `View`, `StoredProcedure`: source-controlled `CREATE` is converted to `CREATE OR ALTER`.
- `Trigger`: supported only when a canonical file exists under `Schema/Programmability/Triggers`; `CREATE` is converted to `CREATE OR ALTER`.
- `Table`, `TableType`, `Sequence`: only when `DifferenceType = MissingInTarget`; the runner checks again immediately before execution and skips a recreate if the object already exists.
- Existing objects with a reviewed, exact allowlisted migration descriptor and guarded source-controlled migration.

Still unsupported by default:

- existing table, table type or sequence changes without a dedicated migration;
- standalone constraints and indexes without a dedicated migration;
- any dedicated migration whose approved source hash no longer matches the staged comparison.

Unsupported selected rows block deployment unless `-AllowPartial` is explicitly supplied. `-AllowPartial` remains a deliberate partial-deployment control and must not be used when the whole accepted plan is intended.

## R23 dedicated support

### `SCore.ObjectSecurity`

R23 adds an exact allowlisted migration for source hash:

```text
6BB3BF24C7B4A3991239D04BD8F0726389DCDE6AE5BC4E0B71FBFB5B5FF9751C
```

Files:

```text
Database/CymBuild_DB/Schema/Migrations/CYB361/SCore.ObjectSecurity.preflight.sql
Database/CymBuild_DB/Schema/Migrations/CYB361/SCore.ObjectSecurity.alter.sql
```

The migration aligns the demonstrated QA shape to the source-controlled DEV shape:

- `Guid`: `UNIQUEIDENTIFIER NULL ROWGUIDCOL`;
- `ObjectGuid`: `UNIQUEIDENTIFIER NOT NULL`;
- `UserId`: `INT NOT NULL`;
- adds the zero-Guid default for `ObjectGuid` when missing;
- adds the `UserId → SCore.Identities.ID` foreign key when missing.

It does not recreate the table and does not update or delete business rows. Apply mode executes the read-only preflight before `SCore.PreDeploymentScript`. The migration is blocked if:

- `ObjectGuid` or `UserId` contains NULL values;
- `UserId` contains orphan references;
- the table/column types are unexpected;
- the comparison source hash has changed;
- an existing default or foreign key has an incompatible definition.

### `SFin.tr_Transactions_RecordBatchApprovalTransition`

R23 adds the existing source-controlled `CREATE OR ALTER TRIGGER` definition to the canonical trigger location:

```text
Database/CymBuild_DB/Schema/Programmability/Triggers/SFin.tr_Transactions_RecordBatchApprovalTransition.sql
```

The runner deploys this file instead of captured database DDL.

## Pre/post deployment

Apply mode runs:

1. dedicated read-only migration preflights;
2. `SCore.PreDeploymentScript`;
3. selected source-controlled schema objects in deployment-plan order;
4. `SCore.PostDeploymentScript`, except when the target database is `CymBuild_Dev`.

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
- A custom `-ConnectionString` cannot silently redirect apply mode to another database/server without the target mismatch guard or an explicit approved override.

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

`manual-preview-deployment.sql` is inspection-only. The approved execution path is the PowerShell runner because it enforces source-path checks, preflight checks, environment controls and SMigration audit.
