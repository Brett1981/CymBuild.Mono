# CYB-361 Manual Schema Deployment Runner

This is the manual version of the future schema deployment pipeline step.

It reads the accepted `SMigration` deployment plan for a run, resolves the matching source-controlled SQL files under `Database/CymBuild_DB/Schema`, applies supported objects to the target database, runs CymBuild pre/post deployment maintenance, and writes deployment audit entries back to `SMigration`.

## Dry run

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
    -ReleaseReference "26.3" `
    -WhatIf
```

## Apply

```powershell
.\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
    -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
    -TargetDatabase "CymBuild_QA" `
    -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
    -ReleaseReference "26.3" `
    -Apply
```

## What it deploys in R19

Supported automatically:

- `Schema` objects, safely created if missing.
- `Function`, `View`, and `StoredProcedure` objects, using `CREATE OR ALTER` generated from source-controlled SQL.
- `Table`, `TableType`, and `Sequence` objects only when they are missing in the target.

Not automatically deployed in R19:

- Existing table structural changes.
- Existing table type changes.
- Existing sequence changes.
- Standalone constraints and indexes.
- Triggers embedded in table scripts.

Those require a dedicated source-controlled, non-destructive migration script or a future object extractor. The runner refuses unsupported rows by default. Use `-AllowPartial` only when the unsupported rows are deliberately excluded from this manual deployment step.

## Output

The runner writes these files by default:

```text
artifacts/schema-deployment/<RunGuid>/deployment-plan.csv
artifacts/schema-deployment/<RunGuid>/resolved-items.csv
artifacts/schema-deployment/<RunGuid>/unsupported-items.csv
artifacts/schema-deployment/<RunGuid>/summary.json
artifacts/schema-deployment/<RunGuid>/manual-preview-deployment.sql
```

The PowerShell runner is preferred over running the generated SQL manually because it writes audit entries to `SMigration.Schema_ExecutionLog` and updates the schema run status.

## Governance

The runner does not copy ad-hoc DDL from a source database. Database snapshots are used only to identify the selected plan. Deployment source is source-controlled SQL.

LIVE/production-looking targets are blocked unless `-AllowLive` is supplied under the approved LIVE release procedure.
