# CYB-361 Manual Schema Deployment Runner (R26)

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
- executes source-controlled read-only target preflights and connection-local temporary support procedures;
- changes no target schema or business data;
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

## Dedicated schema support

### `SCore.ObjectSecurity`

The runner includes an exact allowlisted migration for source hash:

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

The runner includes the existing source-controlled `CREATE OR ALTER TRIGGER` definition to the canonical trigger location:

```text
Database/CymBuild_DB/Schema/Programmability/Triggers/SFin.tr_Transactions_RecordBatchApprovalTransition.sql
```

The runner deploys this file instead of captured database DDL.


## R24 failed-run retry

A failed apply changes the run status to `DeploymentFailed` while retaining the reviewed flag. Retrying is explicit:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
    -ReleaseReference "26.3" `
    -Apply `
    -RetryFailedDeployment
```

`-RetryFailedDeployment` is accepted only when:

- the run remains reviewed;
- the current status is `DeploymentFailed`;
- the same persisted deployment plan is being resumed.

Changing or clearing the saved selection invalidates review and requires normal validation and acceptance again.

## R24 `ROWGUIDCOL` correction (superseded mechanically by R25)

R24 introduced the correct direct `ROWGUIDCOL` sequence. R25 retains that sequence inside the reusable dependency helper rather than coding it separately in each table migration:

1. drop only the `ROWGUIDCOL` column property;
2. alter `Guid` to `UNIQUEIDENTIFIER NULL`;
3. restore the `ROWGUIDCOL` property.

No row data is updated. Any failure rolls the complete migration transaction back.

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

R25 retains the R24 tracking of whether `SCore.PreDeploymentScript` completed. If a later deployment step fails before the normal post-deployment step, the runner attempts `SCore.PostDeploymentScript` as controlled failure recovery before returning the original deployment error. Recovery success or failure is included in the SMigration audit details.

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


## R25 reusable column-dependency handling

R25 separates migration intent from SQL Server dependency mechanics and moves reusable read-only dependency validation into dry-run as well as apply.

The dedicated migration still declares the reviewed, source-controlled intent for a specific table. For `SCore.ObjectSecurity`, that intent is limited to the demonstrated nullability, default and foreign-key differences.

The runner can now attach reusable source-controlled support files to a dedicated migration. The first shared helper is:

```text
Database/CymBuild_DB/Schema/Migrations/_Shared/SMigration.AlterColumnNullabilityWithDependencies.sql
```

The helper creates a connection-local temporary procedure. It is visible only to the controlled runner connection and is removed automatically when that connection closes. It does not create a persistent helper object in the target database.

For explicitly declared nullability changes, the helper dynamically:

- validates the existing table and column shapes;
- rejects identity, computed, masked, hidden, sparse, FILESTREAM, encrypted, user-defined and other unsupported column forms;
- rejects memory-optimized, temporal/ledger, node and edge tables;
- blocks `NOT NULL` changes when existing NULL rows are present;
- detects whether each altered column is `ROWGUIDCOL`;
- discovers dependent nonclustered rowstore indexes and standalone user-created statistics through SQL Server catalogue views, including supported filtered predicates;
- blocks schema-bound and full-text dependencies rather than disabling them implicitly;
- blocks primary/unique constraints, clustered/partitioned or auto-created indexes, columnstore/XML/spatial/hash/hypothetical indexes and other unfamiliar dependency types;
- blocks temporary or persisted-sample statistics and auto-created statistics that cannot be safely auto-dropped;
- scripts the supported target dependency definitions, including key order, included columns, filters, uniqueness, fill factor, locking options, compression, filegroup and disabled state;
- drops the supported dependencies inside the caller transaction;
- temporarily removes and restores `ROWGUIDCOL` only where required;
- performs the declared nullability changes while retaining the existing data type and collation;
- recreates the dependencies before the transaction commits.

If any alter or recreation fails, the caller transaction rolls back the column and dependency changes together. The helper does not infer business meaning, add/drop columns, change data types, fabricate missing values or promote captured source-database DDL.

A dedicated migration opts in by declaring a source-controlled support file in its allowlisted descriptor. This keeps future table-specific decisions explicit while making common SQL Server mechanics reusable across tables.

## R26 filtered-expression dependency classification

R26 corrects the shared nullability helper's dependency classification. SQL Server records filtered-index and filtered-statistics predicates as table-owned schema-bound expressions in `sys.sql_expression_dependencies`. These are not external schema-bound modules and are already handled by the helper's transactional index/statistics suspension and restoration.

The helper now:

- allows table-owned filtered-index and filtered-statistics expression rows to flow to the existing guarded dependency handler;
- still blocks computed columns that depend on an altered column;
- still blocks true external schema-bound views, functions and constraints;
- includes the blocking dependency names in the error message; and
- makes no attempt to rewrite or deploy captured target-module definitions.

Migration intent remains explicit and source-controlled. This correction only removes a false-positive guardrail for dependency types the helper already scripts and restores.

