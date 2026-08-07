# CYB-361 Schema Exclusions

Schema exclusions are persistent operational configuration for the Schema Migration workbench.
They are not per-run selections and are not target-local manual edits.

## Authority and propagation

The database recorded as the run source is authoritative. When an object is excluded from a
comparison row, CymBuild writes the exclusion to the source first and synchronizes it to the
current target. Every later **Run Compare** synchronizes the complete source policy, including
unexclude tombstones, to the selected target before reading schema snapshots.

This permits the policy to move through the controlled environment chain:

```text
DEV source -> QA target -> UAT target -> LIVE target
```

When QA later becomes the source for a QA-to-UAT comparison, the exclusion records previously
received from DEV are passed to UAT. No direct production metadata edit is required.

## Effect

An active exclusion is identified by object type, schema, object name and parent object name.
Excluded objects are omitted from:

- new comparison rows;
- comparison lists for existing runs;
- saved selection counts;
- validation scope;
- accepted deployment plans; and
- `SMigration.SchemaDeploymentPlan_Get`, consumed by the controlled runner.

Changing an exclusion invalidates validation and acceptance for the current run. Rerun comparison
before validating and accepting the refreshed plan.

## Bootstrap

Both the source and target databases must contain the R39 Schema Migration bootstrap objects.
Run from a controlled deployment account:

```powershell
.\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
    -TargetServer '<SERVER>' `
    -TargetDatabase '<DATABASE>' `
    -WhatIf

.\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
    -TargetServer '<SERVER>' `
    -TargetDatabase '<DATABASE>' `
    -Apply
```

The browser only performs readiness checks and generates these commands. It does not execute DDL.
The bootstrap is idempotent and installs or refreshes:

- `SMigration.Schema_ExcludedObjects`;
- `SMigration.SchemaExcludedObject_Apply`;
- `SMigration.SchemaExcludedObjects_List`; and
- the exclusion-aware `SMigration.SchemaDeploymentPlan_Get`.

## DataObjects and audit

Every exclusion row has a matching `SCore.DataObjects` row before insert. Exclusion uses a reason,
origin server/database, user ID, timestamps and the last-seen run Guid. Unexclude is a soft delete
through `SCore.DeleteDataObject`; re-excluding the same stable identity reactivates the existing
record rather than creating a duplicate.

Cross-database propagation is source-first and idempotent. If the current target write fails, the
source policy remains authoritative and the next comparison retries synchronization.
