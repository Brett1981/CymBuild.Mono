# CYB-361 Controlled Schema Source Sync and Deployment Runner (R7D)

R42 table convergence hotfix: generated column declarations validate collation names and emit
them as T-SQL collation tokens (for example `COLLATE SQL_Latin1_General_CP1_CI_AS`). Collation
names are deliberately not emitted as bracketed identifiers because that syntax is invalid in
a `COLLATE` clause.

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
| Manual schema deployment runner, first-class constraints and declarative table/index convergence | CYB-361 R42 |
| Selected DEV source sync, portable default constraints, idempotent programmable-object output and pipeline verification | CYB-361 R7C4 |
| Apply lock, target-drift baseline, persistent attempts/checkpoints and post-apply hash verification | CYB-361 R7D |
| Last independently verified shared-environment baseline | CYB-361 R27, unless later deployment evidence is supplied |

R39/R42/R7C4/R7D being present in source does not itself prove that those revisions have already been deployed to a shared environment. Retain the exact run, plan, source hashes, attempt/checkpoint rows and verification evidence for the first R7D rehearsal.

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
- re-snapshots every selected target object and fails if it no longer matches the accepted `TargetHash` baseline;
- resolves canonical or explicitly allowlisted source-controlled SQL files;
- can materialise missing canonical Function, View, StoredProcedure, Trigger, Constraint, existing-Table convergence or rowstore-Index SQL from the accepted declarative snapshot unless `-SkipSourceMaterialization` is supplied;
- writes the plan, resolved, unsupported and summary artefacts to a unique execution-scoped directory;
- writes an inspection-only generated SQL preview;
- executes source-controlled read-only target preflights and connection-local temporary support procedures;
- recognises only active, inspectable schema-bound functions/views whose committed definitions participate in the existing schema-binding lifecycle when `SCore.PreDeploymentScript` is scheduled to run;
- changes no target schema or business data; and
- writes no SMigration deployment/audit rows.

Materialised files are source artefacts. Review and commit them before deployment. Later-environment promotion should use `-SkipSourceMaterialization` so QA/UAT/LIVE consume only immutable committed files.

## R7C selected DEV source sync

The Schema Management UI remains the place to create a run, compare, save the explicit row selection,
validate and accept it. Once that accepted selection exists, synchronize only its supported source
artefacts from the persisted `CymBuild_Dev` snapshot:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "<ACCEPTED_DEV_SOURCE_RUN_GUID>" `
    -SyncSource
```

`-SyncSource`:

- requires a reviewed/accepted run whose recorded source is exactly `DEV / CymBuild_Dev`;
- requires an explicit non-empty selection and processes only the selected deployment-plan rows;
- updates stale canonical Function, View, StoredProcedure and Trigger files from the accepted source
  definition, and converges selected generated Constraint, Table and Index migration artefacts;
- never deletes a canonical file for `MissingInSource`; an explicit reviewed removal migration remains
  required;
- validates every persisted source/target definition hash used by the selected plan before writing;
- writes schema source only beneath `Database\CymBuild_DB\Schema` and restores every schema source file
  written by the invocation if any selected row is unsupported or the operation otherwise fails;
- emits `source-sync-manifest.json` with the selected comparison identities, source hashes, repository
  paths and file SHA-256 values; and
- returns before target preflight, DDL, business-data changes or SMigration deployment audit changes.

Review and commit the resulting `Database\CymBuild_DB` diff. A normal application compile must not
silently rewrite source control. Instead, the local release build and future pipeline use the
non-mutating verification gate:

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "<ACCEPTED_DEV_SOURCE_RUN_GUID>" `
    -VerifySource
```

`-VerifySource` fails when a selected generated artefact is missing/stale or a selected programmable
object no longer matches the accepted `CymBuild_Dev` source hash. It never writes schema source files or
preflights/deploys the target. The run Guid and plan database become explicit pipeline inputs, avoiding
an implicit "latest run" race.

## R7C4 portable defaults and idempotent module source

R7C4 removes environment noise from SQL Server system-named default constraints. A name such as
`DF__Table__Column__1A2B3C4D` is generated from object creation order and is not a portable schema
contract. Schema comparison now maps a system-named default to a deterministic CymBuild name derived
from schema, table and column. An explicitly named source constraint remains authoritative and is not
discarded.

When a default definition or explicit name genuinely differs, generated prepare/apply SQL resolves the
currently installed target constraint through `sys.default_constraints` and `sys.columns`. It drops by
the actual target name, never by a name captured from QA, and then installs the accepted deterministic or
explicit source name. Read-only preflight rejects a desired name already owned by another column.

Programmable source output is written as `CREATE OR ALTER`, while comparison hashes treat `CREATE`,
`ALTER` and `CREATE OR ALTER` declaration spelling as equivalent. This preserves the accepted module
body while keeping committed Function, View, Procedure and Trigger scripts independently idempotent.

The snapshot and hash rules changed in R7C4. Runs created before the API was restarted with R7C4 must not
be reused for source sync, verification or deployment. Create, compare, select, validate and accept a
fresh DEV-to-QA run. R7C4 does not approve business-behaviour changes found in DEV definitions: correct
them in DEV or leave those rows unselected before accepting the fresh run.

## R7D execution hardening

R7D closes the race between accepted comparison and target execution. Restart the API after deploying
the R7D source and create a fresh Schema run. Run creation transactionally converges these operational
audit tables from the embedded source-controlled bootstrap:

```text
SMigration.Schema_DeploymentAttempts
SMigration.Schema_DeploymentObjectCheckpoints
```

For `-Apply`, the runner:

1. takes an exclusive, session-owned SQL application lock for the target database;
2. reads and fingerprints the selected accepted plan again while holding that lock;
3. creates a persistent attempt row and re-snapshots the target catalogue using the same ten snapshot
   queries and hash normalizer as the API;
4. compares every selected object with the accepted `TargetHash` before any pre-deployment script or
   selected DDL;
5. records per-object support, preflight, prepare, apply and verification checkpoints;
6. runs post-deployment restoration; and
7. re-snapshots every selected object and requires its target hash to match the accepted `SourceHash`
   before `Schema_Run.RunStatus` can become `DeploymentApplied`.

A competing apply fails immediately by default with a deterministic busy message. A controlled pipeline
may set `-ApplyLockTimeoutSeconds` to a bounded non-negative wait. Do not bypass the lock. Target drift
writes `target-drift-failures.csv` and stops before pre-deployment/DDL. Verification failure writes
`post-apply-verification-failures.csv`, marks the attempt and run failed, and retains all checkpoint
evidence for diagnosis.

`-WhatIf` performs the same read-only target-baseline check without taking the apply lock or writing
attempt/checkpoint rows. `-SyncSource` and `-VerifySource` still return before target preflight and keep
the R7C4 source-sync contract.

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

Apply also requires the complete supported selected plan. `-Apply -AllowPartial` is prohibited in R7D.
Use the Schema Management UI to fix, ignore or deselect trouble rows, then validate and accept the exact
remaining selection again. `-AllowPartial` is retained only for diagnostic dry-run resolution and must
not be used as a release/pipeline apply control.

If the runner materialises new canonical SQL during an apply attempt, it stops before any target deployment starts. Review and commit the files, run `-WhatIf`, then run `-Apply` again.

## Deployment-plan behaviour

The runner calls:

```sql
EXEC [SMigration].[SchemaDeploymentPlan_Get]
    @RunGuid = @RunGuid;
```

The stored procedure controls scope:

- saved explicit selection: only selected deployable differences;
- no active selected rows: empty plan and fail closed;
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
- any constraint whose accepted definition is not valid `CYB_CONSTRAINT_V2`;
- any system-named (`is_system_named = 1`) primary-key or unique constraint that the compare could not pair one-to-one with a structurally identical target constraint. Its name is generated per database, so it cannot be recreated faithfully; give it an explicit name in source (or remove the duplicate at source) and compare again. Validation fails these rows with `SYSTEM_NAMED_CONSTRAINT_REQUIRES_EXPLICIT_NAME`.

Unsupported selected rows always block apply. For dry-run diagnosis only, `-AllowPartial` may resolve and
preflight supported rows while reporting the unsupported rows. The release selection must be corrected in
CymBuild and accepted again before apply.

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

## CYB-566 new tables, the -1 row and reference data

A selected table that is `MissingInTarget` is no longer refused. With `-SyncSource`, the runner generates its canonical create file at `Database/CymBuild_DB/Schema/Tables/<Schema>.<Table>.sql`, the same way it generates constraint, index and table-convergence files. Review and commit it like any other generated file; `-VerifySource`, `-WhatIf` and `-Apply` then require it to match the regenerated output.

The generated file:

1. Creates the table with its columns and named defaults, in source column order. Keys, unique constraints, indexes and foreign keys stay as their own plan rows and are applied after it.
2. Always adds the `-1` row: ID `-1`, zero Guid, every other column its default. A NOT NULL integer column with no default takes `-1`, the CymBuild foreign-key sentinel. Any other NOT NULL column with no default stops generation with a clear message.
3. Adds the source rows only when **Copy reference data** was ticked for that table on the Compare screen (off by default). Use it for lookup tables only; transactional data is never copied. Rows are keyed on Guid and keep their source IDs. Tables over 5,000 rows, or with unsupported column types, are refused.
4. Creates `SCore.DataObjects` rows for the copied rows, with `EntityTypeId` resolved from `SCore.EntityHobts` on the target. If the table has no registration, it prints a warning and skips them rather than guessing.

The runner never connects to the source. When the selection is saved, the API captures each selected new table's column order from the source, plus its rows when the box is ticked, and stores them on `SMigration.Schema_RunSelections` (`CopyReferenceData`, `NewTableCaptureJson`). Both are part of the plan fingerprint. If the DEV table changes after that, run Compare again and re-save the selection.

A hand-written canonical create file already at that path is used as before, unless reference data was requested.

## R42 physical-table classification and Windows PowerShell compatibility

R42 restricts key, foreign-key, check, default and standalone-index snapshots to physical user tables in `sys.tables`. Defaults that belong to multi-statement table-valued-function return definitions are part of the function module and are no longer emitted as standalone `Constraint` rows. Indexed-view or other non-table indexes are likewise excluded from the ordinary table-index contract.

The runner reads declarative JSON properties through their `PSPropertyInfo.Value`, preserving one-column `Columns` arrays under Windows PowerShell 5.1. The `SCore.ObjectSecurity` dedicated migration remains source-hash guarded, with its allow-list updated to the approved `CYB_TABLE_V2` snapshot produced by the canonical source table.

## Dedicated schema support

### `SCore.ObjectSecurity`

The runner includes an exact allowlisted migration for source hash:

```text
F8196E022BF3112E9064A03D5C684F01104A9D1DCCEFC66C00E88FFC96218465
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

1. acquire the target-database apply lock and recheck the accepted-plan fingerprint;
2. create the persistent attempt and re-snapshot every selected target baseline;
3. read-only migration, table, constraint and index preflights that are valid against the pre-change structure;
4. `SCore.PreDeploymentScript`;
5. strict post-predeployment preflights confirming managed schema-bound dependencies were removed;
6. selected index/constraint prepare files, including dependent-object ordering;
7. selected table and programmable-object source-controlled changes;
8. deferred constraint/index preflights against the converged table structure;
9. selected rowstore indexes and constraint finalisation, with primary/unique constraints before foreign keys;
10. `SCore.PostDeploymentScript` after success, except for the established `CymBuild_Dev` rule;
11. re-snapshot and verify every selected target object against its accepted source hash; and
12. complete the attempt, audit and final run status before releasing the lock.

If a later deployment step fails after pre-deployment completed, the runner attempts controlled `SCore.PostDeploymentScript` recovery before returning the original failure. Recovery success/failure is included in the audit detail.

## Audit and DataObjects

Apply mode writes `SMigration.Schema_ExecutionLog`, `SMigration.Schema_DeploymentAttempts` and
`SMigration.Schema_DeploymentObjectCheckpoints` entries. Each new operational row is created atomically
with its matching `SCore.DataObjects` row through:

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

When applicable, it also writes `target-drift-failures.csv` or
`post-apply-verification-failures.csv`. These are failure evidence and should be retained with the
execution manifest and pipeline logs.

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
