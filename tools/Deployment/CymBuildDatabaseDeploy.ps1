#requires -Version 7.2
<#
.SYNOPSIS
Database phase for Publish-CymBuildServer.ps1: backup -> schema -> metadata.

.DESCRIPTION
Dot-sourced by Publish-CymBuildServer.ps1. Each step returns a result object
(Step, Status, Message, Detail, Log). Status is Succeeded, Failed or Skipped.

Target and source databases come from the committed appsettings for the environment and the
previous one (Resolve-CymBuildDeployDatabases). They can be on different SQL instances.
LIVE-looking targets are refused.

Rules (agreed 2026-10-13):
- A COPY_ONLY, CHECKSUM backup is taken and verified before any migration.
  If it fails, schema and metadata are skipped.
- Schema runs first. Metadata runs only if schema succeeded or had nothing to do.
- A failed step never stops the application deployment. It is reported, the
  remaining database steps are skipped, and schema/metadata must be completed
  manually through the workbenches.
#>

function New-DbStepResult {
    param(
        [Parameter(Mandatory)][string]$Step,
        [Parameter(Mandatory)][ValidateSet('Succeeded', 'Failed', 'Skipped')][string]$Status,
        [string]$Message = '',
        [string]$Detail = '',
        [string]$Log = ''
    )
    [pscustomobject]@{ Step = $Step; Status = $Status; Message = $Message; Detail = $Detail; Log = $Log }
}

# ------------------------------------------------------------------ database settings
<#
Database names change between releases, so they are read from the environment's appsettings file
in the commit being deployed, never hard-coded here. Same key order as Concursus.API Program.cs:
DefaultConnection, then ShoreDB, then CymBuild. Only the named per-environment file is read; the
base appsettings.json is not a fallback.
#>
function Get-CymBuildDatabaseFromAppSettings {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Appsettings file not found: $Path" }
    $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $connectionStrings = if ($json.PSObject.Properties['ConnectionStrings']) { $json.ConnectionStrings } else { $null }
    foreach ($key in 'DefaultConnection', 'ShoreDB', 'CymBuild') {
        if (-not $connectionStrings -or -not $connectionStrings.PSObject.Properties[$key]) { continue }
        $value = [string]$connectionStrings.$key
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($value)
        if ([string]::IsNullOrWhiteSpace($builder.DataSource) -or [string]::IsNullOrWhiteSpace($builder.InitialCatalog)) {
            throw "ConnectionStrings:$key in $Path has no Data Source or Initial Catalog."
        }
        return [pscustomobject]@{ Server = $builder.DataSource; Database = $builder.InitialCatalog; Key = $key; File = (Split-Path $Path -Leaf) }
    }
    throw "No ConnectionStrings:DefaultConnection, ShoreDB or CymBuild found in $Path."
}

# Mirrors Test-LiveTargetName in tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1.
function Test-CymBuildLiveDatabaseName {
    param([string]$Server, [string]$Database)
    $db = "$Database".Trim()
    ($db -ieq 'Concursus') -or ($db -match '(?i)(^|[_\-])(live|prod|production)([_\-]|$)') -or ("$Server" -match '(?i)(live|prod|production)')
}

# Resolves the target and source databases for a deploy target and refuses anything unsafe.
function Resolve-CymBuildDeployDatabases {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][hashtable]$Target)
    $settingsDir = Join-Path $RepoRoot 'services\Concursus.API'
    $targetDb = Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $settingsDir $Target.AppSettings)
    $sourceDb = Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $settingsDir $Target.SourceAppSettings)
    if (Test-CymBuildLiveDatabaseName -Server $targetDb.Server -Database $targetDb.Database) {
        throw "$($targetDb.File) points at $($targetDb.Server) / $($targetDb.Database), which looks like LIVE. This script never migrates LIVE."
    }
    if (($targetDb.Server -ieq $sourceDb.Server) -and ($targetDb.Database -ieq $sourceDb.Database)) {
        throw "$($targetDb.File) and $($sourceDb.File) both point at $($targetDb.Server) / $($targetDb.Database); source and target must differ."
    }
    [pscustomobject]@{ Target = $targetDb; Source = $sourceDb; SourceEnvironment = $Target.SourceEnvironment }
}

function New-DbConnection {
    param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Database)
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $Server
    $builder['Initial Catalog'] = $Database
    $builder['Integrated Security'] = $true
    $builder['TrustServerCertificate'] = $true
    $builder['Application Name'] = 'CymBuild Publish-CymBuildServer'
    $connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
    $connection.Open()
    $connection
}

# Runs one batch and returns the first column of the first row (or $null). Info messages
# (BACKUP progress, PRINT) are written to the console.
function Invoke-DbScalar {
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$Sql,
        [hashtable]$Parameters = @{},
        [int]$TimeoutSeconds = 300
    )
    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = $TimeoutSeconds
    foreach ($key in $Parameters.Keys) { [void]$command.Parameters.AddWithValue($key, $Parameters[$key]) }
    $command.ExecuteScalar()
}

# ------------------------------------------------------------------ backup
<#
Deploy backups rotate between two fixed files per database (<db>_deploy_A.bak / _B.bak), so the
backup folder holds at most two of them however often we deploy. One file per release filled the
shared DEV/QA SQL host's disk (2026-10-21), and the deploy login cannot delete files there
(no xp_delete_file, no admin share). WITH INIT overwrites a slot without needing delete rights.

The slot written is the one whose last completed backup (msdb history) is older, so the newest
backup is never the one being overwritten. The release label goes into the backup set NAME.
#>
function Select-CymBuildBackupSlot {
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$Database,
        [Parameter(Mandatory)][string]$Folder
    )
    $base = '{0}\{1}_deploy' -f $Folder.TrimEnd('\'), ($Database -replace '[^A-Za-z0-9._-]', '_')
    $slotA = "${base}_A.bak"
    $slotB = "${base}_B.bak"
    $sql = @'
SELECT TOP (1) UPPER(mf.physical_device_name)
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS mf
    ON mf.media_set_id = bs.media_set_id
WHERE bs.database_name = @database
  AND UPPER(mf.physical_device_name) IN (UPPER(@slotA), UPPER(@slotB))
ORDER BY bs.backup_finish_date DESC;
'@
    $newest = Invoke-DbScalar $Connection $sql @{ '@database' = $Database; '@slotA' = $slotA; '@slotB' = $slotB }
    if ($newest -is [DBNull] -or $null -eq $newest) { return $slotA }
    if ([string]$newest -ieq $slotA) { $slotB } else { $slotA }
}

function Invoke-CymBuildDatabaseBackup {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Database,
        [Parameter(Mandatory)][string]$Label
    )
    $connection = $null
    try {
        $connection = New-DbConnection -Server $Server -Database 'master'
        $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { param($s, $e) Write-Host "    [sql] $($e.Message)" }
        $connection.add_InfoMessage($handler)

        $folder = Invoke-DbScalar $connection "SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));"
        if ([string]::IsNullOrWhiteSpace($folder)) { throw 'SQL Server returned no InstanceDefaultBackupPath.' }
        # Express (EngineEdition 4) cannot compress backups.
        $edition = [int](Invoke-DbScalar $connection "SELECT CAST(SERVERPROPERTY('EngineEdition') AS int);")
        $file = Select-CymBuildBackupSlot -Connection $connection -Database $Database -Folder $folder
        $setName = "CymBuild deploy $Label"
        if ($setName.Length -gt 128) { $setName = $setName.Substring(0, 128) }
        $compression = if ($edition -eq 4) { '' } else { ', COMPRESSION' }

        Write-Host "    backing up [$Database] to $file (COPY_ONLY, overwrites the older deploy slot)"
        $null = Invoke-DbScalar $connection ("BACKUP DATABASE {0} TO DISK = @file WITH COPY_ONLY, CHECKSUM, INIT, NAME = @name, STATS = 25{1};" -f "[$($Database.Replace(']', ']]'))]", $compression) @{ '@file' = $file; '@name' = $setName } -TimeoutSeconds 0
        Write-Host '    verifying backup'
        $null = Invoke-DbScalar $connection 'RESTORE VERIFYONLY FROM DISK = @file WITH CHECKSUM;' @{ '@file' = $file } -TimeoutSeconds 0
        New-DbStepResult -Step 'Backup' -Status Succeeded -Message "Verified COPY_ONLY backup of $Database ($setName)." -Detail $file
    } catch {
        New-DbStepResult -Step 'Backup' -Status Failed -Message $_.Exception.Message
    } finally {
        if ($connection) { $connection.Dispose() }
    }
}

# ------------------------------------------------------------------ migration tool
# Concursus.Metadata.Tools hosts the headless schema-prepare and metadata-auto verbs.
function Build-CymBuildMigrationTool {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$OutDir)
    $project = Join-Path $RepoRoot 'apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj'
    # Out-Host: native output would otherwise become part of this function's return value.
    & dotnet build $project -c Release -o $OutDir --nologo -v q -tl:off -clp:ErrorsOnly | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Building the migration tool failed with exit code $LASTEXITCODE." }
    $dll = Join-Path $OutDir 'Concursus.Metadata.Tools.dll'
    if (-not (Test-Path -LiteralPath $dll)) { throw "Migration tool not found at $dll." }
    $dll
}

# Runs a migration-tool verb; returns the parsed JSON report and the exit code.
function Invoke-CymBuildMigrationVerb {
    param(
        [Parameter(Mandatory)][string]$ToolDll,
        [Parameter(Mandatory)][string]$Verb,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$OutJson,
        [Parameter(Mandatory)][string]$LogPath
    )
    & dotnet $ToolDll $Verb @Arguments --out $OutJson *>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host "    $_" }
    $exit = $LASTEXITCODE
    $report = $null
    if (Test-Path -LiteralPath $OutJson) { $report = Get-Content -LiteralPath $OutJson -Raw | ConvertFrom-Json }
    [pscustomobject]@{ ExitCode = $exit; Report = $report }
}

# Repo-relative paths (forward slashes) of every Database\CymBuild_DB file a project embeds.
function Get-CymBuildEmbeddedSchemaFiles {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $root = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $projects = foreach ($dir in 'apps', 'libs', 'services') {
        $path = Join-Path $RepoRoot $dir
        if (Test-Path -LiteralPath $path) { Get-ChildItem -LiteralPath $path -Filter '*.csproj' -Recurse -File }
    }
    $files = foreach ($project in $projects) {
        $text = Get-Content -LiteralPath $project.FullName -Raw
        foreach ($match in [regex]::Matches($text, '<EmbeddedResource\s+Include="([^"]*CymBuild_DB[^"]*)"')) {
            # Includes may use a file-name wildcard (e.g. SMigration.Metadata*.sql).
            $pattern = [IO.Path]::GetFullPath((Join-Path $project.DirectoryName $match.Groups[1].Value))
            $resolved = if ($pattern.Contains('*')) {
                $dir = Split-Path $pattern -Parent
                if (Test-Path -LiteralPath $dir) { (Get-ChildItem -LiteralPath $dir -Filter (Split-Path $pattern -Leaf) -File).FullName }
            } else { $pattern }
            foreach ($full in @($resolved)) {
                if ($full -and $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                    $full.Substring($root.Length).Replace('\', '/')
                }
            }
        }
    }
    @($files | Sort-Object -Unique)
}

function Invoke-SchemaRunner {
    param([Parameter(Mandatory)][string]$Runner, [Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$LogPath)
    & pwsh -NoProfile -File $Runner @Arguments *>&1 | Tee-Object -FilePath $LogPath -Append | ForEach-Object { Write-Host "    $_" }
    $LASTEXITCODE
}

# ------------------------------------------------------------------ schema
<#
Accepted-but-unapplied run first, otherwise a new run with every Different and MissingInTarget
object selected (schema-prepare). The selected definitions are then synced from the source into
Database\CymBuild_DB\Schema and committed, because the runner only applies committed files that
match the accepted source hashes. Finally the runner applies the run.
#>
function Invoke-CymBuildSchemaStep {
    param(
        [Parameter(Mandatory)][string]$ToolDll,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunDir,
        [Parameter(Mandatory)][string]$TargetServer,
        [Parameter(Mandatory)][string]$TargetDatabase,
        [Parameter(Mandatory)][string]$SourceServer,
        [Parameter(Mandatory)][string]$SourceDatabase,
        [Parameter(Mandatory)][string]$SourceEnvironment,
        [Parameter(Mandatory)][string]$TargetEnvironment,
        [Parameter(Mandatory)][string]$Label
    )
    $log = Join-Path $RunDir 'schema.log'
    try {
        $prepare = Invoke-CymBuildMigrationVerb -ToolDll $ToolDll -Verb 'schema-prepare' -OutJson (Join-Path $RunDir 'schema-prepare.json') -LogPath $log -Arguments @(
            '--target-server', $TargetServer, '--target-database', $TargetDatabase,
            '--source-server', $SourceServer, '--source-database', $SourceDatabase,
            '--source-environment', $SourceEnvironment, '--target-environment', $TargetEnvironment,
            '--notes', "Publish-CymBuildServer $Label")
        $report = $prepare.Report
        if ($prepare.ExitCode -ne 0 -or -not $report) {
            $message = if ($report -and $report.message) { $report.message } else { "schema-prepare exited with $($prepare.ExitCode)." }
            return New-DbStepResult -Step 'Schema' -Status Failed -Message $message -Log $log
        }
        if ($report.mode -eq 'nothing-to-do') {
            return New-DbStepResult -Step 'Schema' -Status Succeeded -Message 'No schema differences to apply.' -Log $log
        }

        $selected = @($report.selected)
        $skipped = @($report.skipped)
        Write-Host "    schema run $($report.runGuid) ($($report.mode)): $($selected.Count) object(s) selected, $($skipped.Count) skipped"
        foreach ($s in $selected) { Write-Host ("      + {0,-16} {1}.{2} ({3})" -f $s.objectType, $s.schemaName, $s.objectName, $s.differenceType) }
        foreach ($s in $skipped) { Write-Host ("      - {0,-16} {1}.{2}: {3}" -f $s.objectType, $s.schemaName, $s.objectName, $s.reason) }

        $runner = Join-Path $RepoRoot 'tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1'
        $common = @('-TargetServer', $TargetServer, '-TargetDatabase', $TargetDatabase, '-RunGuid', "$($report.runGuid)")

        Write-Host '    syncing selected schema source from the source database'
        if ((Invoke-SchemaRunner -Runner $runner -LogPath $log -Arguments ($common + @('-SyncSource', '-AllowNonDevSource'))) -ne 0) {
            return New-DbStepResult -Step 'Schema' -Status Failed -Message "Schema source sync failed for run $($report.runGuid)." -Log $log
        }

        $schemaPath = 'Database/CymBuild_DB'
        & git -C $RepoRoot add -- $schemaPath 2>&1 | Out-Host
        $staged = & git -C $RepoRoot diff --cached --name-only -- $schemaPath
        $commit = ''

        # A non-DEV source (UAT from QA) must already match the committed files. If it does not,
        # either something was applied to it out of band (it would enter source unreviewed) or it
        # is behind source (committing would revert newer code) - 2026-10-13 run e1105a38 did both.
        if ($staged -and $SourceEnvironment -ne 'DEV') {
            & git -C $RepoRoot reset -q -- $schemaPath 2>&1 | Out-Host
            & git -C $RepoRoot checkout -q -- $schemaPath 2>&1 | Out-Host
            & git -C $RepoRoot clean -q -f -- $schemaPath 2>&1 | Out-Host
            return New-DbStepResult -Step 'Schema' -Status Failed `
                -Message "$SourceDatabase ($SourceEnvironment) does not match the committed schema source; nothing was committed or applied." `
                -Detail ("Differing file(s): {0}. Get the change into source through a branch, or redeploy {1} from source, then retry." -f (@($staged) -join ', '), $SourceEnvironment) `
                -Log $log
        }

        # The API embeds some schema files for its migration bootstrap, which re-applies them when
        # the workbench is first used. The package was built before this sync, so applying now would
        # be undone by the old embedded copies (QA2, 2026-10-13 14:16). Commit, then stop: a re-run
        # builds from the new commit and finds nothing left to sync.
        $staleEmbedded = @()
        if ($staged) {
            $embedded = Get-CymBuildEmbeddedSchemaFiles -RepoRoot $RepoRoot
            $staleEmbedded = @($staged | Where-Object { $embedded -contains $_ })
        }

        if ($staged) {
            & git -C $RepoRoot commit -q -m "Schema sync from $SourceDatabase for $Label (run $($report.runGuid))" -m 'Generated by tools/Deployment/Publish-CymBuildServer.ps1 before applying the schema run to the target.' -- $schemaPath 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) {
                return New-DbStepResult -Step 'Schema' -Status Failed -Message 'Committing the synced schema source failed.' -Log $log
            }
            $commit = (& git -C $RepoRoot rev-parse --short HEAD).Trim()
            Write-Host "    committed $(@($staged).Count) schema file(s) as $commit (not pushed)"
        }

        if ($staleEmbedded.Count -gt 0) {
            return New-DbStepResult -Step 'Schema' -Status Failed `
                -Message "Synced schema source committed as $commit changes file(s) the API embeds; the package being deployed predates it, so the schema was not applied." `
                -Detail ("Embedded file(s): {0}. Re-run the deploy from the new commit." -f ($staleEmbedded -join ', ')) `
                -Log $log
        }

        # The runner refuses runs compared more than 30 minutes ago.
        $compared = [datetime]::Parse("$($report.comparedOnUtc)", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
        if (([datetime]::UtcNow - $compared).TotalMinutes -gt 29) {
            return New-DbStepResult -Step 'Schema' -Status Failed -Message "Run $($report.runGuid) was compared more than 30 minutes ago; the runner will refuse it." -Log $log
        }

        Write-Host '    applying schema run'
        if ((Invoke-SchemaRunner -Runner $runner -LogPath $log -Arguments ($common + @('-ReleaseReference', $Label, '-Apply', '-SkipSourceMaterialization'))) -ne 0) {
            $detail = if ($commit) { "Schema source commit $commit was created; review it before pushing." } else { '' }
            return New-DbStepResult -Step 'Schema' -Status Failed -Message "Schema apply failed for run $($report.runGuid)." -Detail $detail -Log $log
        }

        $detail = if ($commit) { "Synced schema source committed as $commit - push it with the release." } else { 'Committed schema source already matched.' }
        New-DbStepResult -Step 'Schema' -Status Succeeded -Message "Applied $($selected.Count) object(s) from run $($report.runGuid) ($($report.mode))." -Detail $detail -Log $log
    } catch {
        New-DbStepResult -Step 'Schema' -Status Failed -Message $_.Exception.Message -Log $log
    }
}

# ------------------------------------------------------------------ metadata
function Invoke-CymBuildMetadataStep {
    param(
        [Parameter(Mandatory)][string]$ToolDll,
        [Parameter(Mandatory)][string]$RunDir,
        [Parameter(Mandatory)][string]$TargetServer,
        [Parameter(Mandatory)][string]$TargetDatabase,
        [Parameter(Mandatory)][string]$SourceServer,
        [Parameter(Mandatory)][string]$SourceDatabase,
        [Parameter(Mandatory)][string]$SourceEnvironment,
        [Parameter(Mandatory)][string]$TargetEnvironment
    )
    $log = Join-Path $RunDir 'metadata.log'
    try {
        $result = Invoke-CymBuildMigrationVerb -ToolDll $ToolDll -Verb 'metadata-auto' -OutJson (Join-Path $RunDir 'metadata-auto.json') -LogPath $log -Arguments @(
            '--target-server', $TargetServer, '--target-database', $TargetDatabase,
            '--source-server', $SourceServer, '--source-database', $SourceDatabase,
            '--source-environment', $SourceEnvironment, '--target-environment', $TargetEnvironment)
        $report = $result.Report
        if (-not $report) {
            return New-DbStepResult -Step 'Metadata' -Status Failed -Message "metadata-auto exited with $($result.ExitCode) and wrote no report." -Log $log
        }
        $detailParts = @()
        if ($report.RunGuid) { $detailParts += "run $($report.RunGuid) ($($report.Mode))" }
        if ($report.SkippedUnsupportedCount -gt 0) { $detailParts += "$($report.SkippedUnsupportedCount) row(s) in tables without an apply handler not selected: $(@($report.SkippedUnsupportedTables) -join ', ')" }
        foreach ($issue in @($report.Issues)) { $detailParts += $issue }
        $status = if ($result.ExitCode -eq 0 -and $report.Status -eq 'Succeeded') { 'Succeeded' } else { 'Failed' }
        New-DbStepResult -Step 'Metadata' -Status $status -Message $report.Message -Detail ($detailParts -join '; ') -Log $log
    } catch {
        New-DbStepResult -Step 'Metadata' -Status Failed -Message $_.Exception.Message -Log $log
    }
}

# ------------------------------------------------------------------ phase
# backup -> schema (only after a verified backup) -> metadata (only after schema succeeded).
function Invoke-CymBuildDatabasePhase {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunDir,
        [Parameter(Mandatory)][object]$Databases,
        [Parameter(Mandatory)][string]$TargetEnvironment,
        [Parameter(Mandatory)][string]$Label
    )
    $results = [System.Collections.Generic.List[object]]::new()
    $skipReason = 'Skipped because an earlier database step failed.'
    $TargetDatabase = $Databases.Target.Database
    $SourceDatabase = $Databases.Source.Database
    $endpoints = @{
        TargetServer = $Databases.Target.Server; TargetDatabase = $TargetDatabase
        SourceServer = $Databases.Source.Server; SourceDatabase = $SourceDatabase
        SourceEnvironment = $Databases.SourceEnvironment; TargetEnvironment = $TargetEnvironment
    }

    Write-Host ''
    Write-Host "==> Database: backing up $TargetDatabase" -ForegroundColor Cyan
    $backup = Invoke-CymBuildDatabaseBackup -Server $Databases.Target.Server -Database $TargetDatabase -Label $Label
    $results.Add($backup)
    if ($backup.Status -ne 'Succeeded') {
        $results.Add((New-DbStepResult -Step 'Schema' -Status Skipped -Message 'Skipped: no verified backup.'))
        $results.Add((New-DbStepResult -Step 'Metadata' -Status Skipped -Message 'Skipped: no verified backup.'))
        return $results.ToArray()
    }

    $toolDll = $null
    try {
        $toolDll = [string](Build-CymBuildMigrationTool -RepoRoot $RepoRoot -OutDir (Join-Path $RunDir 'migration-tool'))
    } catch {
        $results.Add((New-DbStepResult -Step 'Schema' -Status Failed -Message $_.Exception.Message))
        $results.Add((New-DbStepResult -Step 'Metadata' -Status Skipped -Message $skipReason))
        return $results.ToArray()
    }

    Write-Host ''
    Write-Host "==> Database: schema $SourceDatabase -> $TargetDatabase" -ForegroundColor Cyan
    $schema = try { Invoke-CymBuildSchemaStep -ToolDll $toolDll -RepoRoot $RepoRoot -RunDir $RunDir -Label $Label @endpoints } catch { New-DbStepResult -Step 'Schema' -Status Failed -Message $_.Exception.Message }
    $results.Add($schema)
    if ($schema.Status -ne 'Succeeded') {
        $results.Add((New-DbStepResult -Step 'Metadata' -Status Skipped -Message $skipReason))
        return $results.ToArray()
    }

    Write-Host ''
    Write-Host "==> Database: metadata $SourceDatabase -> $TargetDatabase" -ForegroundColor Cyan
    $metadata = try { Invoke-CymBuildMetadataStep -ToolDll $toolDll -RunDir $RunDir @endpoints } catch { New-DbStepResult -Step 'Metadata' -Status Failed -Message $_.Exception.Message }
    $results.Add($metadata)
    $results.ToArray()
}

# ------------------------------------------------------------------ summary
function Write-DbPhaseSummary {
    param([Parameter(Mandatory)][object[]]$Results)
    Write-Host ''
    Write-Host '==> Database summary' -ForegroundColor Cyan
    foreach ($r in $Results) {
        $colour = switch ($r.Status) { 'Succeeded' { 'Green' } 'Failed' { 'Red' } default { 'Yellow' } }
        Write-Host ("    {0,-9} {1,-9} {2}" -f $r.Step, $r.Status, $r.Message) -ForegroundColor $colour
        if ($r.Detail) { Write-Host "              $($r.Detail)" }
        if ($r.Log) { Write-Host "              log: $($r.Log)" }
    }
    if ($Results | Where-Object Status -eq 'Failed') {
        Write-Host '    Complete the schema and metadata deployment manually through the workbenches.' -ForegroundColor Yellow
    }
}
