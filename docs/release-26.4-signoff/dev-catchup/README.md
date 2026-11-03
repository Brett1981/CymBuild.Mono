# CymBuild_Dev 26.4 catch-up (14 Oct 2026)

`CymBuild_Dev` is the DEV source again (Dev264 has gone). QA is `Cymbuild_QA`.

**Run:** `CymBuild_Dev_26.4_CatchUp.sql` against `CymBuild_Dev`. That's the only step needed before the QA migration.

```
sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev -E -C -b -f 65001 -i CymBuild_Dev_26.4_CatchUp.sql
```

It brings `CymBuild_Dev` level with `release/26.4` (equal to `main`, d03e5df2). Everything in it is `CREATE OR ALTER` or guarded, so it's safe to re-run, and it refuses to run on any other database. It ends with a verification step: every row should read `OK`.

It replaces `../dev-pending/` and includes everything that folder had.

## What the comparison found

The check compared DEV's procedures, functions, views and triggers, plus its tables, columns, indexes and constraints, against the 26.4 source. It ignores whitespace, comments, `SCHEMABINDING`, the ordering of audit-trigger blocks, and per-environment entity property IDs.

| Result | Count | Action |
|---|---|---|
| Identical | 921 of 941 objects | none |
| DEV behind the repo | 6 | in the script (01-06) |
| CYB-515 notification triggers | 2 | in the script (07). The repo copy of these triggers sits in a generated Tables file that was never synced, so this script is the source. |
| Audit triggers DEV-ahead | 14 differ, 26 DEV-only | **left untouched.** DEV regenerated them on 12 Oct to cover new columns and tables. `-SyncSource` will bring them into the repo. |
| Missing default constraint | 1 | in the script (08) |
| Enquiry Town save metadata | 1 query + 4 parameters | in the script (09). The QA metadata migration copies it from DEV. |
| Missing unique indexes | 2 | **not included.** They need a data decision first; see the end of the script. |

## After running
1. Use the schema workbench to Compare and `-SyncSource` from `CymBuild_Dev`, then commit the generated files. This picks up the CYB-515 triggers and the newer audit triggers.
2. Run the QA schema migration and then the metadata migration, `CymBuild_Dev` to `Cymbuild_QA`.

**Rollback** for steps 01-07: `ROLLBACK_CymBuild_Dev_before_26.4_catchup.sql`. It holds the definitions captured from `CymBuild_Dev` immediately before the script was built.

**Re-checking:** `../tools/compare_modules.py` and `../tools/compare_tables.py` re-run the comparison. They need a fresh export of the DEV definitions first; the PowerShell for that is in the checkpoint.

## CYB-584: Activities query metadata and the query signature check (16 Oct 2026)

Creating an Activity failed on UAT with "An insufficient number of arguments were supplied for ... SJob.ActivitiesValidate". CYB-333 gave the function two more parameters, but the Activities validate and upsert queries were never updated in DEV, so the migration had nothing to carry. The migration now also checks every query call against its function or procedure (`SMigration.MetadataQuerySignature_Check`), during validation and at the end of every `metadata-auto` run.

Run against `CymBuild_Dev`, in this order:

1. The three changed migration procedures, so a later `-SyncSource` does not revert them:
   ```
   sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev -E -C -b -f 65001 -i ..\..\..\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataQuerySignature_Check.sql
   sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev -E -C -b -f 65001 -i ..\..\..\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataValidate_Run.sql
   sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev -E -C -b -f 65001 -i ..\..\..\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApply_Run.sql
   ```
2. `CYB-584_CymBuild_Dev_ActivityQueryMetadata.sql`. It stops without changing anything if the `SJob.Activities.IsPartOfAgreedFee` entity property does not exist. That property puts the question on the Activity form, so create it in the metadata UI first, then re-run.
3. `EXEC SMigration.MetadataQuerySignature_Check;`. It should return no rows.

QA and UAT get the procedures from the migration bootstrap and the metadata from the normal deploy. Every row the check returns for a database fails that database's metadata step until the query is fixed in DEV and migrated, or the issue is ignored in the workbench.

## Duplicate products and entity properties
Use `../data-fixes/Fix_DuplicateProductsAndEntityProperties.sql`. Run it as-is first: `@Apply = 0` is a rolled-back preview. Then run it with `@Apply = 1`. It can run in any environment because it matches rows by Guid. On `CymBuild_Dev`, it also creates `IX_UQ_EntityProperties_Hobt_Name` once the duplicates are gone.

`FIRE-SIT` is deliberately left out of the merge: its two rows are different products (Fire Engineering UK and Fire Modelling) that share a code. One of them needs a new code before `IX_UQ_Products_Code` can be created.
