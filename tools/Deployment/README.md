# QA and UAT server deployment

`Publish-CymBuildServer.ps1` builds the CymBuild API and PWA from a clean checkout and
deploys them to the QA or UAT environment on **SOC-CONIIS**. It replaces the manual process
of publishing to a folder, backing up by hand, and copying files over RDP.

QA and UAT are configured. LIVE is deliberately absent and stays manual.

| `-Environment` | API service | PWA site / pool | Deploy root |
|---|---|---|---|
| `QA` (default) | `Concursus.API_dev`, `https://cymbuild-dev.socotec.co.uk:9401/` | `Concursus.PWA_Dev`, `https://cymbuild-dev.socotec.co.uk/` | `C:\CymBuildDeploy\QA` |
| `UAT` | `Concursus.API_Test`, `https://cymbuild-uat.socotec.co.uk:9501/` | `Concursus.PWA_Test`, `https://cymbuild-uat.socotec.co.uk/` | `C:\CymBuildDeploy\UAT` |

## Prerequisites

- PowerShell 7.2+ and the .NET 10 SDK on your machine.
- An account that is a local administrator on SOC-CONIIS, for example `ESGL\<you>_adm`.
  If PowerShell is already running as an `_adm` account, the script uses that login with no prompt.
  Otherwise it prompts for `<you>_adm`, or you can pass `-Credential`.
- A clean working tree. The script refuses uncommitted changes and warns if the branch is
  not `release/*`.

The server needs nothing installed. It uses Windows PowerShell 5.1, WinRM on port 5985 with
Kerberos, robocopy and IIS, all of which are already present.

## Usage

```powershell
# Read-only: local checks, remote preflight and the plan. No build, no backup, no runs, no changes.
./tools/Deployment/Publish-CymBuildServer.ps1 -WhatIf
./tools/Deployment/Publish-CymBuildServer.ps1 -Environment UAT -WhatIf

# Back up and migrate the QA database, then deploy API and PWA (prompts once to confirm).
./tools/Deployment/Publish-CymBuildServer.ps1

# The same for UAT (database migrated from QA).
./tools/Deployment/Publish-CymBuildServer.ps1 -Environment UAT

# Deploy one component.
./tools/Deployment/Publish-CymBuildServer.ps1 -Component Api

# Application only, no database phase.
./tools/Deployment/Publish-CymBuildServer.ps1 -SkipDatabase

# Put back the most recent backup (the current files are backed up first).
./tools/Deployment/Publish-CymBuildServer.ps1 -Environment UAT -RestoreBackup latest
```

## Databases come from appsettings

Database names change between releases, so the script does not hard-code them. It reads the
server and database from the committed `services/Concursus.API/appsettings.<Env>.json`, using
the same key order as the API (`DefaultConnection`, then `ShoreDB`, then `CymBuild`):

| Target | Target database from | Source database from |
|---|---|---|
| QA | `appsettings.QA.json` | `appsettings.Development.json` (DEV) |
| UAT | `appsettings.Test.json` | `appsettings.QA.json` (QA) |

Only the named file is read; the base `appsettings.json` is not a fallback. The resolved
databases are printed before the confirmation prompt (also with `-WhatIf`). The script
refuses to continue when:

- the file has no connection string, or no Data Source or Initial Catalog;
- the target looks like LIVE (`Concursus`, or a `live`/`prod`/`production` name or server),
  matching the schema runner's own LIVE guard;
- source and target are the same database.

When a database is renamed, update that file (keeping it in line with the server's own
appsettings, which the API actually loads) and commit it before deploying.

## What it does

1. **Preflight (read-only).** Confirms that the environment's API service and PWA site and
   pool exist and point at the expected folders. Also checks that the server-owned config is
   present, there is at least 10 GB free, and no other deployment holds the lock.
2. **Build.** Runs `dotnet publish -c Release` for each component, writes a SHA-256
   manifest per component, and packages everything into one zip under
   `artifacts/server-deploy/<release>/`.
3. **Stage.** Copies the zip over remoting, checks its hash, extracts it to
   `<deploy root>\releases\<release>`, and re-verifies every file. It reports:
   - configuration keys present in the build but missing from the server's
     `appsettings.json`, by name only;
   - files on the server that the new build would remove. Superseded `_framework` files, which Blazor renames on every build, are only counted. You must confirm any other removals.
4. **Database** (skip with `-SkipDatabase`). See [Database phase](#database-phase).
5. **Switch.** Backs up the live folders to `<deploy root>\backups\before-<release>`,
   then for each component:
   - **API:** stop the service, mirror the files, verify sizes and hashes, start the
     service, check it is still running after 30 s, and confirm the API URL answers.
   - **PWA:** stop the pool, mirror the files, verify, start the pool, and check the home
     page and `appsettings.json` on the PWA URL.
6. **Rollback.** If any step after a live folder has changed fails, that component is
   restored from the backup and restarted. If the restore also fails, the lock is left in
   place and the script reports `NeedsAttention`.
7. **Record.** Appends to `<deploy root>\history.log`, writes `current.json`, and
   keeps the newest 3 releases and backups (`-KeepReleases`).

## Server-owned files

These are never copied from the build, overwritten or deleted:

| Pattern | Why |
|---|---|
| `appsettings*.json` (any folder) | Environment configuration and secrets are maintained on the server |
| `web.config` | IIS rewrite/cache rules (PWA), host settings (API) |
| `nlog.config` | API logging targets, maintained per server |
| `logs\` | API logs |

When a build adds a configuration key, the script lists the key name. Add the key to the
server's `appsettings.json` yourself.

## Database phase

Runs after the package is staged and before the application switch, against the target
database, with the previous environment's database as the source (see
[Databases come from appsettings](#databases-come-from-appsettings)). Source and target can
be on different SQL instances (each comes from its own appsettings file). It is implemented in `CymBuildDatabaseDeploy.ps1` and the
`schema-prepare` and `metadata-auto` verbs of `apps/Concursus.Metadata.Tools`.

1. **Backup.** `BACKUP DATABASE ... WITH COPY_ONLY, CHECKSUM, INIT` to the target instance's
   default backup folder, then `RESTORE VERIFYONLY`. If the backup fails, schema and metadata
   are skipped.
   - Backups rotate between two files per database, `<default>\<database>_deploy_A.bak` and
     `_B.bak`, so the folder never holds more than two however often you deploy. Each deploy
     overwrites the slot whose last backup (msdb history) is older, so the newest backup is
     never the one overwritten. The release label is the backup set name
     (`RESTORE HEADERONLY`, or `msdb.dbo.backupset.name`).
   - The deploy login cannot delete files on the SQL host, so overwriting is the only cleanup.
     One `.bak` per release filled the shared DEV/QA host's disk on 2026-10-21. Older
     `<database>_<release>.bak` files from before the rotation must be deleted by someone with
     access to the server.
   - Limitation: if one deploy's backup completes but fails `RESTORE VERIFYONLY`, and the next
     deploy's backup also fails part-way, both slots are unusable. Each failure is reported and
     stops the database steps, so take a manual backup before retrying.
2. **Schema** (`schema-prepare`, then the schema runner).
   - An accepted, unapplied run is used first. If it was compared more than 25 minutes ago it
     is re-compared, re-validated and re-accepted with its original selection.
   - Otherwise a new run is created and every `Different` and `MissingInTarget` object is
     selected. `MissingInSource` objects are never selected. Objects that would fail
     validation are skipped and listed with the reason.
   - The runner syncs the selected definitions from the source into `Database\CymBuild_DB\Schema`
     (`-SyncSource -AllowNonDevSource`). Any changed files are **committed to the current
     branch, not pushed**, because the runner only applies committed files that match the
     source. Push that commit with the release.
   - **A non-DEV source must already match source control.** For UAT the source is QA, which
     should have been deployed from committed files. If the sync would change any committed
     file, the changes are discarded and the step fails, listing the files. Either the source
     database had something applied out of band (it would enter source unreviewed) or it is
     behind source (committing would revert newer code). Fix the source or redeploy QA, then
     retry. On 2026-10-13 run `e1105a38` did both: it committed CYB-580's
     `SFin.InvoiceRequestItemsUpsert` from QA2 before its branch was merged, and reverted two
     `SMigration` procedures QA2 was behind on.
   - **A sync that changes a file the API embeds stops the step after committing.** The API
     embeds some schema files (`EmbeddedResource` in any project under `apps`, `libs` or
     `services`) for its migration bootstrap, which re-applies them the first time the
     workbench is used. The package being deployed was built before the sync commit, so it
     would put the old definitions back (QA2, 2026-10-13 14:16). Re-run the deploy: it
     builds from the new commit and finds nothing left to sync.
   - When the source is not DEV (UAT), the schema engine runs the source's pre-deployment
     maintenance procedure during the comparison and restores it afterwards, as the
     workbench does.
   - The runner then applies the run (`-Apply`). Runs older than 30 minutes are refused.
3. **Metadata** (`metadata-auto`, only if schema succeeded).
   - An accepted run whose preview is still current is used first. If its acceptance is stale
     but nothing is blocked, the current preview is re-accepted.
   - Otherwise a new run is created, staged without retirements, and every `Insert` and
     `Update` row in a table with an apply handler is selected, with dependencies added.
     Rows in other tables are listed, not selected.
   - Any validation failure, blocked preview row, selected unsupported table or drift stops
     the step.
4. **Summary.** Each step is reported as Succeeded, Failed or Skipped with its log
   (`artifacts/server-deploy/<release>/schema.log`, `metadata.log`).

**A failed database step never stops the application deployment.** It is reported, the
remaining database steps are skipped, and schema and metadata must then be completed
manually through the workbenches. The backup file is the way back for the database.

**Risks you accepted by running unattended:**
- DEV contains unreleased work from every branch. All of it reaches QA, and then UAT.
- If the source is behind what is committed or already in the target for an object, the
  older definition is applied and committed. Check the schema commit before pushing it.
  For UAT this happens if QA was last deployed from an older commit than the one you are
  deploying to UAT.
- Metadata identity-map review is not performed.
- QA to UAT crosses SQL instances. The metadata two-connection path has had gaps before;
  treat the first UAT run as a trial and read the metadata log.

## Not covered

- **LIVE.** Promotion stays manual.
- **API health endpoint.** `Concursus.API` has no `/health` endpoint, so the check only
  proves that Kestrel answers on the port.

## Tests

```powershell
# Offline: database-name resolution, then server-side functions under Windows PowerShell 5.1
# against temp folders.
pwsh -File tools/Deployment/Tests/Invoke-PublishCymBuildServerTests.ps1
```

`tests/CymBuild.Architecture.Tests/ServerDeploymentScriptSourceContractTests.cs` guards the
safety rules: QA and UAT only (never LIVE), database names read from the committed
appsettings in the API's key order, server-owned files kept, schema applied only through the
runner, the backup -> schema -> metadata order, database failures not stopping the
deployment, and no credentials in source. `tests/Concursus.EF.Tests` covers the selection
rules (`SchemaMigrationRulesTests`, `MetadataMigrationCliTests`).
