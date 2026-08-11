# CYB-361 Controlled Schema Deployment Runner (R41)

This is the controlled manual implementation of the future schema deployment pipeline worker.

The CymBuild Schema Migration workbench remains configuration, comparison, selection, validation and acceptance only. It does not execute DDL from the browser. The runner is executed from the repository root by a controlled deployment machine/account:

```text
PWA -> FormHelper -> gRPC API -> SMigration accepted plan
```

then, outside the browser:

```text
PowerShell runner/pipeline worker -> committed source-controlled SQL -> target SQL Server -> SMigration audit
```

## Version position

| Component | Current source revision |
|---|---|
| Schema Migration workbench/bootstrap and persistent exclusions | CYB-361 R39 |
| Manual schema deployment runner, first-class constraints and declarative table/index convergence | CYB-361 R41 |
| Last independently verified shared-environment baseline | CYB-361 R27, unless later deployment evidence is supplied |

R39/R41 being present in source does not itself prove that those revisions have already been deployed to a shared environment. Retain the exact run, plan, source hashes and verification evidence for the first R41 rehearsal.

Historical run Guids shown in older records are audit evidence only and must not be reused.

Related contracts:

- [Persistent schema exclusions](SchemaExclusions.md)
- [Declarative constraint, table and index deployment contract](ConstraintDeployment.md)

## Bootstrap/readiness

The controlled bootstrap checks or installs the minimum R39 SMigration workbench and exclusion-policy objects from source-controlled, idempotent SQL:

```powershell
.\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
    -TargetServer "<SERVER>" `
    -TargetDatabase "<DATABASE>" `
    -WhatIf

.\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
    -TargetServer "<SERVER>" `
    -TargetDatabase "<DATABASE>" `
    -Apply
```

The bootstrap runs only under a controlled deployment identity. It is not called directly by the Blazor UI and does not grant browser/user sessions DDL permission.

## Dry run

Dry-run is the default. `-WhatIf` is shown explicitly for clarity.

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "<ACCEPTED_RUN_GUID>" `
    -ReleaseReference "26.3" `
    -WhatIf
```

Dry-run:

- reads the accepted run and `SMigration.SchemaDeploymentPlan_Get`;
- resolves canonical or explicitly allowlisted source-controlled SQL files;
- can materialise missing canonical Function, View, StoredProcedure, Trigger, Constraint, existing-Table convergence or rowstore-Index SQL from the accepted declarative snapshot unless `-SkipSourceMaterialization` is supplied;
- writes the plan, resolved, unsupported and summary artefacts to a unique execution-scoped directory;
- writes an inspection-only generated SQL preview;
- executes source-controlled read-only target preflights and connection-local temporary support procedures;
- recognises only active, inspectable schema-bound functions/views whose committed definitions participate in the existing schema-binding lifecycle when `SCore.PreDeploymentScript` is scheduled to run;
- changes no target schema or business data; and
- writes no SMigration deployment/audit rows.

Materialised files are source artefacts. Review and commit them before deployment. Later-environment promotion should use `-SkipSourceMaterialization` so QA/UAT/LIVE consume only immutable committed files.

## Apply

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "<ACCEPTED_RUN_GUID>" `
    -ReleaseReference "26.3" `
    -Apply `
    -SkipSourceMaterialization
```

Apply requires the run to be in the accepted `Reviewed` state. Saving or clearing a deployment selection resets validation and acceptance, so the current plan must be validated and accepted again before deployment.

If the runner materialises new canonical SQL during an apply attempt, it stops before any target deployment starts. Review and commit the files, run `-WhatIf`, then run `-Apply` again.

## Deployment-plan behaviour

The runner calls:

```sql
EXEC [SMigration].[SchemaDeploymentPlan_Get]
    @RunGuid = @RunGuid;
```

The stored procedure controls scope:

- saved explicit selection: only selected deployable differences;
- no active selection rows: all deployable differences;
- active persistent exclusions: omitted from comparison, validation and plan scope.

No captured executable source-database DDL is run directly. Each deployment item resolves to an approved file under:

```text
Database/CymBuild_DB/Schema
```

Resolved paths are canonicalised and rejected if they escape that source-controlled root.

## Supported objects

Automatically supported:

- `Schema`: created only when missing.
- `Function`, `View`, `StoredProcedure`: committed or materialised canonical SQL; `CREATE` is converted to `CREATE OR ALTER` where applicable.
- `Trigger`: canonical SQL under `Schema/Programmability/Triggers`; `CREATE` is converted to `CREATE OR ALTER`.
- `Constraint`: source-controlled create, replace and explicitly accepted removal for foreign keys, checks, defaults, primary keys and unique constraints using `CYB_CONSTRAINT_V2`.
- `Table` with `DifferenceType = Different`: source-controlled `CYB_TABLE_V2` convergence for ordinary disk-based tables. This supports missing-column insertion, typed temporary backfill for new `NOT NULL` columns without a source default, source-default alignment, convertible type/nullability changes, lock-escalation alignment and explicitly selected target-only column removal. Every operation is transactional and idempotent.
- `Index`: source-controlled create, replace and explicitly accepted removal for ordinary clustered/nonclustered rowstore indexes using `CYB_INDEX_V2`, including uniqueness, key direction, included columns, filters, filegroup, compression and standard index options.
- `Table`, `TableType`, `Sequence`: only when `DifferenceType = MissingInTarget`; the runner checks immediately before execution and skips recreation if the object already exists.
- Existing objects with a reviewed, exact allowlisted migration descriptor and guarded source-controlled migration.

Still unsupported by default:

- memory-optimised, temporal, `SCHEMA_ONLY`, encrypted, generated-always or other specialist table changes without a dedicated migration;
- identity/computed/ROWGUIDCOL/SPARSE/FILESTREAM characteristic changes and data conversions that cannot pass the read-only `TRY_CONVERT` preflight;
- partitioned, XML, spatial, columnstore, hash or other specialist index changes without a dedicated migration;
- any dedicated migration whose approved source hash no longer matches the staged comparison;
- any constraint whose accepted definition is not valid `CYB_CONSTRAINT_V2`.

Unsupported selected rows block deployment unless `-AllowPartial` is explicitly supplied. `-AllowPartial` remains a deliberate partial-deployment control and must not be used when the whole accepted plan is intended.

## R39 persistent schema exclusions

The database recorded as the run source is authoritative for exclusions. Every Run Compare synchronises the complete policy, including unexclude tombstones, to the selected target before reading schema snapshots:

```text
DEV source -> QA target -> UAT target -> LIVE target
```

Excluded objects are omitted from new/existing comparison lists, selection counts, validation, accepted plans and `SMigration.SchemaDeploymentPlan_Get`.

Changing an exclusion invalidates current validation and acceptance. Run comparison again before validating and accepting the refreshed plan.

Each exclusion row has a matching `SCore.DataObjects` row. Unexclude is a soft delete through `SCore.DeleteDataObject`; re-excluding the stable identity reactivates the existing row.

See [SchemaExclusions.md](SchemaExclusions.md) for the complete contract.

## R40 constraint deployment

R40 deploys foreign-key, check, default, primary-key and unique constraints as first-class governed plan items. The accepted comparison contains a `CYB_CONSTRAINT_V2` declarative snapshot rather than executable captured DDL.

Canonical files are generated/refreshed beneath:

```text
Database/CymBuild_DB/Schema/Constraints
```

Changed constraints are split into:

1. `*.prepare.sql` - drop the target definition before dependent structural deployment;
2. `*.preflight.sql` - validate tables/columns and key viability without changing data;
3. `*.sql` - recreate the accepted source definition after non-constraint schema work.

Foreign keys prepare before key constraints. Primary/unique constraints recreate before foreign keys.

Existing-data policy:

- foreign-key and check constraints are added with `WITH NOCHECK`; no historical data is changed or retroactively trusted;
- primary-key and unique constraints use read-only NULL/duplicate preflight and block deployment when creation would fail;
- target-only constraint removal is destructive-risk, is excluded from the default plan and requires explicit selection, validation and acceptance.

See [ConstraintDeployment.md](ConstraintDeployment.md) for the complete contract and pipeline order.

## R41 table and index convergence

R41 fixes validation so the persisted definitions are loaded before the snapshot-version checks. A fresh R40 constraint comparison is therefore no longer misclassified as a legacy row.

Existing tables and standalone indexes use declarative snapshots rather than captured executable DDL:

- `CYB_TABLE_V2` records the logical column definitions, defaults and supported table options. Physical column ordinal is intentionally excluded because CymBuild SQL uses explicit column lists and reordering would require a destructive table rebuild without changing the logical schema.
- `CYB_INDEX_V2` records ordinary rowstore index keys, direction, includes, filter, uniqueness, filegroup, compression and standard options.

The runner materialises deterministic preflight/prepare/apply files beneath `Database/CymBuild_DB/Schema`, stops apply if new files were generated, and requires those files to be reviewed and committed before promotion. Constraint/index preflights that depend on selected table changes are executed after table convergence and before the dependent object is recreated.

Table convergence never drops and recreates the whole table. It changes only the reviewed column/table properties. Removing a target-only column is possible only through an explicitly saved table selection because existing-table differences remain destructive-risk rows. Unsupported dependencies or conversions fail closed; they do not trigger inferred data deletion.

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

The migration aligns the demonstrated target shape to the source-controlled shape:

- `Guid`: `UNIQUEIDENTIFIER NULL ROWGUIDCOL`;
- `ObjectGuid`: `UNIQUEIDENTIFIER NOT NULL`;
- `UserId`: `INT NOT NULL`;
- adds the zero-Guid default for `ObjectGuid` when missing;
- adds the `UserId -> SCore.Identities.ID` foreign key when missing.

It does not recreate the table and does not update/delete business rows. Apply mode executes a read-only preflight before `SCore.PreDeploymentScript`, then repeats it in strict mode after pre-deployment maintenance. The migration is blocked if:

- `ObjectGuid` or `UserId` contains NULL values;
- `UserId` contains orphan references;
- the table/column types are unexpected;
- the comparison source hash has changed; or
- an existing default or foreign key has an incompatible definition.

### `SFin.tr_Transactions_RecordBatchApprovalTransition`

The canonical trigger file is:

```text
Database/CymBuild_DB/Schema/Programmability/Triggers/SFin.tr_Transactions_RecordBatchApprovalTransition.sql
```

The runner deploys this source-controlled definition rather than captured database DDL.

## Failed-run retry

A failed apply changes the run status to `DeploymentFailed` while retaining the reviewed flag. Retrying is explicit:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "<FAILED_ACCEPTED_RUN_GUID>" `
    -ReleaseReference "26.3" `
    -Apply `
    -SkipSourceMaterialization `
    -RetryFailedDeployment
```

`-RetryFailedDeployment` is accepted only when:

- the run remains reviewed;
- the current status is `DeploymentFailed`; and
- the same persisted deployment plan is being resumed.

Changing or clearing the saved selection invalidates review and requires normal validation and acceptance again.

## Pre/post deployment and convergence order

Apply mode runs the controlled sequence:

1. read-only migration, table, constraint and index preflights that are valid against the pre-change structure;
2. `SCore.PreDeploymentScript`;
3. strict post-predeployment preflights confirming managed schema-bound dependencies were removed;
4. selected index/constraint prepare files, including dependent-object ordering;
5. selected table and programmable-object source-controlled changes;
6. deferred constraint/index preflights against the converged table structure;
7. selected rowstore indexes;
8. constraint finalisation files, with primary/unique constraints before foreign keys;
9. `SCore.PostDeploymentScript` after success, except for the established `CymBuild_Dev` rule;
10. SMigration execution audit and final run status.

If a later deployment step fails after pre-deployment completed, the runner attempts controlled `SCore.PostDeploymentScript` recovery before returning the original failure. Recovery success/failure is included in the audit detail.

## Audit and DataObjects

Apply mode writes `SMigration.Schema_ExecutionLog` entries. Each log row is created atomically with its matching `SCore.DataObjects` row through:

```sql
EXEC [SMigration].[SchemaDataObject_Ensure]
```

Successful apply updates `SMigration.Schema_Run`. A failure after deployment starts records `DeploymentFailed` and a failure audit entry. Dry-run never writes these records.

## Environment guardrails

- The accepted run target, requested target and actual opened SQL connection are checked.
- `-SkipAcceptanceCheck` apply mode is restricted to DEV-like databases.
- LIVE/production-looking targets are blocked unless `-AllowLive` is explicitly supplied under the approved LIVE release procedure.
- A custom `-ConnectionString` cannot silently redirect apply mode to another database/server without the target-mismatch guard or explicit approved override.
- Later environments should use `-SkipSourceMaterialization` and immutable reviewed repository artefacts.

## Output

Default structure:

```text
artifacts/schema-deployment/<RunGuid>/executions/<UTC-mode-process-unique-id>/
```

Each execution writes:

```text
deployment-plan.csv
resolved-items.csv
unsupported-items.csv
summary.json
manual-preview-deployment.sql
```

`manual-preview-deployment.sql` is inspection-only. The approved execution path is the PowerShell runner/pipeline worker because it enforces source-path validation, preflights, environment controls, dependency ordering and SMigration audit.

## Historical compatibility notes: R24-R27

### R24 retry and ROWGUIDCOL correction

R24 introduced explicit failed-run retry and the correct `ROWGUIDCOL` sequence:

1. remove only the `ROWGUIDCOL` property;
2. alter `Guid` to `UNIQUEIDENTIFIER NULL`;
3. restore the `ROWGUIDCOL` property.

R25 moved that sequence into the reusable dependency helper. No row data is updated; failure rolls the complete migration transaction back.

### R25 reusable column-dependency handling

The shared helper is:

```text
Database/CymBuild_DB/Schema/Migrations/_Shared/SMigration.AlterColumnNullabilityWithDependencies.sql
```

It creates a connection-local temporary procedure and does not create a persistent target helper object. For explicitly declared nullability changes it:

- validates existing table/column shapes;
- rejects unsupported identity, computed, masked, hidden, sparse, FILESTREAM, encrypted, user-defined and other unfamiliar forms;
- rejects memory-optimised, temporal/ledger, node and edge tables;
- blocks `NOT NULL` changes when existing NULL rows are present;
- discovers supported nonclustered rowstore indexes and user-created statistics, including supported filters;
- blocks unmanaged schema-bound, full-text, computed-column, primary/unique, clustered/partitioned and unfamiliar dependencies;
- scripts, drops and recreates supported dependencies inside the caller transaction;
- temporarily removes/restores `ROWGUIDCOL` only where required; and
- never infers business meaning, fabricates data or executes captured source-database DDL.

### R26 filtered-expression dependency classification

R26 allows table-owned filtered-index/filtered-statistics expression dependencies to flow to the guarded dependency handler while still blocking computed columns and true unmanaged external schema-bound dependencies.

### R27 managed schema-bound lifecycle

R27 integrates the shared column-alter preflight with `SCore.PreDeploymentScript`/`SCore.PostDeploymentScript`:

- before pre-deployment, read-only preflight may classify only inspectable managed `V`, `IF`, `TF` and `FN` modules as lifecycle candidates;
- `-SkipPreDeployment` leaves those dependencies blocking;
- after pre-deployment the runner repeats strict preflights;
- remaining dependencies stop deployment before table alteration; and
- the transactional helper independently refuses active external schema-bound dependencies.

R39/R40 retain these guardrails while adding persistent exclusions, source materialisation and first-class constraints.
