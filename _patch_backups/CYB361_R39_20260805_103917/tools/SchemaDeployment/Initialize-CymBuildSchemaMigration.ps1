<#
.SYNOPSIS
    CYB-361 R35 controlled Schema Migration workbench bootstrap runner.

.DESCRIPTION
    Checks whether the target database contains the minimum SMigration objects required by the
    Schema Migration workbench and controlled deployment runner.

    Default behaviour is read-only. Use -Apply to execute the source-controlled, idempotent
    bootstrap SQL under Database/CymBuild_DB/Schema/Migrations/CYB361.

    This script must be run from a controlled deployment account. It is not called directly by
    the Blazor UI and does not grant DDL permissions to a browser or user session.

.EXAMPLE
    .\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_UAT" `
        -WhatIf

.EXAMPLE
    .\tools\SchemaDeployment\Initialize-CymBuildSchemaMigration.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_UAT" `
        -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetServer,

    [Parameter(Mandatory = $true)]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionString = "",

    [Parameter(Mandatory = $false)]
    [string]$SqlUsername = "",

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$SqlPassword,

    [Parameter(Mandatory = $false)]
    [switch]$Apply,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$AllowLive,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Apply -and $WhatIf) {
    throw "Specify either -Apply or -WhatIf, not both."
}

if (-not $Apply) {
    $WhatIf = $true
}

if (-not [string]::IsNullOrWhiteSpace($SqlUsername) -and $null -eq $SqlPassword) {
    throw "-SqlPassword is required when -SqlUsername is supplied."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bootstrapSqlPath = Join-Path $RepoRoot "Database\CymBuild_DB\Schema\Migrations\CYB361\SMigration.SchemaWorkbench.Bootstrap.sql"

if (-not (Test-Path -LiteralPath $bootstrapSqlPath -PathType Leaf)) {
    throw "Source-controlled bootstrap SQL was not found: $bootstrapSqlPath"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $safeDatabaseName = ($TargetDatabase -replace '[^A-Za-z0-9_.-]', '_')
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
    $OutputDirectory = Join-Path $RepoRoot "artifacts\schema-migration-bootstrap\$safeDatabaseName\$timestamp"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function ConvertTo-PlainTextPassword {
    param([System.Security.SecureString]$SecureValue)

    if ($null -eq $SecureValue) {
        return ""
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function New-CymBuildSqlConnectionString {
    if (-not [string]::IsNullOrWhiteSpace($ConnectionString)) {
        return $ConnectionString
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $TargetServer
    $builder["Initial Catalog"] = $TargetDatabase
    $builder["TrustServerCertificate"] = $true
    $builder["MultipleActiveResultSets"] = $false
    $builder["Application Name"] = "CymBuild.SchemaMigrationBootstrap"

    if (-not [string]::IsNullOrWhiteSpace($SqlUsername)) {
        $builder["Integrated Security"] = $false
        $builder["User ID"] = $SqlUsername
        $builder["Password"] = ConvertTo-PlainTextPassword -SecureValue $SqlPassword
    }
    else {
        $builder["Integrated Security"] = $true
    }

    return $builder.ConnectionString
}

function New-SqlConnection {
    param([string]$SqlConnectionString)

    $connection = New-Object System.Data.SqlClient.SqlConnection($SqlConnectionString)
    try {
        $connection.Open()
        return $connection
    }
    catch {
        $connection.Dispose()
        throw
    }
}

function Invoke-SqlQuery {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Sql,
        [int]$TimeoutSeconds = 300
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandType = [System.Data.CommandType]::Text
    $command.CommandTimeout = $TimeoutSeconds

    $table = New-Object System.Data.DataTable
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
    try {
        [void]$adapter.Fill($table)
        return ,$table
    }
    finally {
        $adapter.Dispose()
        $command.Dispose()
    }
}

function Invoke-SqlNonQuery {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Sql,
        [int]$TimeoutSeconds = 600
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandType = [System.Data.CommandType]::Text
    $command.CommandTimeout = $TimeoutSeconds
    try {
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Split-SqlBatches {
    param([string]$Sql)

    $batches = New-Object System.Collections.Generic.List[string]
    $builder = New-Object System.Text.StringBuilder
    $lines = $Sql -split "`r?`n"

    foreach ($line in $lines) {
        if ($line -match '^\s*GO\s*(\d+)?\s*(?:--.*)?$') {
            $batch = $builder.ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($batch)) {
                $repeatToken = if ($Matches.ContainsKey(1)) { [string]$Matches[1] } else { "" }
                $repeatCount = if ([string]::IsNullOrWhiteSpace($repeatToken)) { 1 } else { [int]$repeatToken }
                if ($repeatCount -lt 1) {
                    throw "Invalid GO repeat count '$repeatCount'."
                }

                for ($repeatIndex = 0; $repeatIndex -lt $repeatCount; $repeatIndex++) {
                    [void]$batches.Add($batch)
                }
            }
            [void]$builder.Clear()
        }
        else {
            [void]$builder.AppendLine($line)
        }
    }

    $lastBatch = $builder.ToString().Trim()
    if (-not [string]::IsNullOrWhiteSpace($lastBatch)) {
        [void]$batches.Add($lastBatch)
    }

    return [string[]]$batches.ToArray()
}

function Invoke-SqlScriptText {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Sql,
        [string]$Description,
        [int]$TimeoutSeconds = 600
    )

    $batches = Split-SqlBatches -Sql $Sql
    $batchNumber = 0

    foreach ($batch in $batches) {
        $batchNumber++
        try {
            Invoke-SqlNonQuery -Connection $Connection -Sql $batch -TimeoutSeconds $TimeoutSeconds
        }
        catch {
            throw "SQL batch $batchNumber failed for $Description. $($_.Exception.Message)"
        }
    }
}

function Test-LiveTargetName {
    param(
        [string]$ServerName,
        [string]$DatabaseName
    )

    if (-not [string]::IsNullOrWhiteSpace($DatabaseName)) {
        $databaseValue = $DatabaseName.Trim()
        if ($databaseValue.Equals("Concursus", [System.StringComparison]::OrdinalIgnoreCase) -or
            $databaseValue -match '(?i)(^|[_\-])(live|prod|production)([_\-]|$)') {
            return $true
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ServerName) -and
        $ServerName -match '(?i)(live|prod|production)') {
        return $true
    }

    return $false
}

function Get-BootstrapReadiness {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    return Invoke-SqlQuery -Connection $Connection -Sql @"
SELECT
    required.[SortOrder],
    required.[ObjectKind],
    required.[ObjectName],
    required.[IsPresent]
FROM
(
    VALUES
        (10, N'Schema', N'[SMigration]', CONVERT(BIT, CASE WHEN SCHEMA_ID(N'SMigration') IS NULL THEN 0 ELSE 1 END)),
        (20, N'Table', N'[SMigration].[Schema_Run]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (30, N'Table', N'[SMigration].[Schema_ObjectComparisons]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (40, N'Table', N'[SMigration].[Schema_ValidationIssues]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ValidationIssues]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (50, N'Table', N'[SMigration].[Schema_ExecutionLog]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ExecutionLog]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (60, N'Table', N'[SMigration].[Schema_RunSelections]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (70, N'StoredProcedure', N'[SMigration].[SchemaDataObject_Ensure]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[SchemaDataObject_Ensure]', N'P') IS NULL THEN 0 ELSE 1 END)),
        (80, N'StoredProcedure', N'[SMigration].[SchemaDeploymentPlan_Get]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[SchemaDeploymentPlan_Get]', N'P') IS NULL THEN 0 ELSE 1 END))
) AS required
(
    [SortOrder],
    [ObjectKind],
    [ObjectName],
    [IsPresent]
)
ORDER BY required.[SortOrder];
"@
}

function Get-MissingReadinessRows {
    param([System.Data.DataTable]$ReadinessTable)

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $ReadinessTable.Rows) {
        if (-not [Convert]::ToBoolean($row["IsPresent"])) {
            [void]$rows.Add([pscustomobject]@{
                ObjectKind = [string]$row["ObjectKind"]
                ObjectName = [string]$row["ObjectName"]
            })
        }
    }

    return [object[]]$rows.ToArray()
}

function Write-BootstrapSummary {
    param(
        [string]$Mode,
        [string]$Status,
        [object[]]$MissingBefore,
        [object[]]$MissingAfter,
        [string]$SqlHash
    )

    $summary = [ordered]@{
        TargetServer = $TargetServer
        TargetDatabase = $TargetDatabase
        Mode = $Mode
        Status = $Status
        MissingBefore = @($MissingBefore)
        MissingAfter = @($MissingAfter)
        BootstrapSql = $bootstrapSqlPath
        BootstrapSqlSha256 = $SqlHash
        GeneratedOnUtc = (Get-Date).ToUniversalTime().ToString("o")
    }

    $summaryPath = Join-Path $OutputDirectory "summary.json"
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    return $summaryPath
}

$isLiveTarget = Test-LiveTargetName -ServerName $TargetServer -DatabaseName $TargetDatabase
if ($Apply -and $isLiveTarget -and -not $AllowLive) {
    throw "Target appears to be LIVE/production. Re-run with -AllowLive only under the approved LIVE release procedure."
}

$bootstrapSql = Get-Content -LiteralPath $bootstrapSqlPath -Raw
$sqlHash = (Get-FileHash -LiteralPath $bootstrapSqlPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sqlConnectionString = New-CymBuildSqlConnectionString
$connection = $null

try {
    $connection = New-SqlConnection -SqlConnectionString $sqlConnectionString
    $readinessBefore = Get-BootstrapReadiness -Connection $connection
    $missingBefore = @(Get-MissingReadinessRows -ReadinessTable $readinessBefore)

    Write-Host "CYB-361 R35 Schema Migration bootstrap"
    Write-Host "Repo root       : $RepoRoot"
    Write-Host "Target          : $TargetServer / $TargetDatabase"
    Write-Host "Mode            : $(if ($Apply) { 'Apply' } else { 'WhatIf' })"
    Write-Host "Bootstrap SQL   : $bootstrapSqlPath"
    Write-Host "Missing objects : $($missingBefore.Count)"
    Write-Host "Output folder   : $OutputDirectory"

    if ($missingBefore.Count -gt 0) {
        foreach ($missing in $missingBefore) {
            Write-Host "  - $($missing.ObjectKind) $($missing.ObjectName)"
        }
    }

    if ($WhatIf) {
        $status = if ($missingBefore.Count -eq 0) { "Ready" } else { "BootstrapRequired" }
        $summaryPath = Write-BootstrapSummary -Mode "WhatIf" -Status $status -MissingBefore $missingBefore -MissingAfter $missingBefore -SqlHash $sqlHash

        if ($missingBefore.Count -eq 0) {
            Write-Host "Target is already ready for the Schema Migration workbench. No SQL was executed."
        }
        else {
            Write-Host "Dry-run only. No SQL was executed. Re-run with -Apply from a controlled deployment account."
        }

        Write-Host "Summary         : $summaryPath"
        return
    }

    if ($missingBefore.Count -eq 0) {
        $summaryPath = Write-BootstrapSummary -Mode "Apply" -Status "AlreadyReady" -MissingBefore $missingBefore -MissingAfter @() -SqlHash $sqlHash
        Write-Host "Target is already ready. No bootstrap SQL was required."
        Write-Host "Summary         : $summaryPath"
        return
    }

    Write-Host "Applying source-controlled Schema Migration bootstrap..."
    Invoke-SqlScriptText -Connection $connection -Sql $bootstrapSql -Description "Schema Migration workbench bootstrap" -TimeoutSeconds 900

    $readinessAfter = Get-BootstrapReadiness -Connection $connection
    $missingAfter = @(Get-MissingReadinessRows -ReadinessTable $readinessAfter)
    if ($missingAfter.Count -gt 0) {
        $missingNames = ($missingAfter | ForEach-Object { $_.ObjectName }) -join ", "
        throw "Bootstrap verification failed. Missing objects remain: $missingNames"
    }

    $summaryPath = Write-BootstrapSummary -Mode "Apply" -Status "Applied" -MissingBefore $missingBefore -MissingAfter $missingAfter -SqlHash $sqlHash
    Write-Host "Schema Migration bootstrap completed successfully."
    Write-Host "Summary         : $summaryPath"
}
finally {
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}
