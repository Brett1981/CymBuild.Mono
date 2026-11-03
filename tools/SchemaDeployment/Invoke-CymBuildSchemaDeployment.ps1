<#
.SYNOPSIS
    CYB-361 R7D selected DEV source-sync and execution-hardened schema convergence runner.

.DESCRIPTION
    Reads an accepted SMigration schema deployment plan from the target database and applies the
    corresponding source-controlled SQL artefacts from the repository. Every selected canonical
    artefact is verified against the immutable accepted source snapshot before target preflight.
    Normal dry-run and apply modes never create or rewrite repository files.

    This is the manual version of the future release-pipeline step. It never executes captured DDL
    directly. Only explicit -SyncSource mode may write deterministic definitions under
    Database/CymBuild_DB/Schema. WhatIf and Apply require every selected artefact to be tracked,
    committed and unchanged at the current repository HEAD.

    Default behaviour is dry-run. Use -Apply to execute.
    Use -SyncSource to update only the selected source artefacts from a DEV / CymBuild_Dev run, or
    -VerifySource to fail without writing when those artefacts are stale. Both source modes return
    before target SQL preflight or deployment and are intended for the source-control and future
    pipeline handoff. Unlike -Apply and -WhatIf, neither mode requires the run to already be in a
    Reviewed/accepted state, because they never preflight or change the target database and only
    generate the artefact a reviewer needs; every plan row must still carry an explicit saved
    selection, and the resulting diff still requires manual review and commit before it can be used
    by -VerifySource, -WhatIf or -Apply.

    By default a run must record source DEV / CymBuild_Dev exactly, or -SyncSource and -VerifySource
    are refused. Pass -AllowNonDevSource to deliberately synchronize or verify from a run recording a
    different source (e.g. while the CymBuild environments are not yet aligned). This only relaxes
    the source-environment check; every other target-matching and LIVE-target rule (-AllowLive,
    -IgnoreTargetMismatch, etc.) is unchanged, and -Apply/-WhatIf acceptance is unchanged.
    The actual recorded source and whether the override was used are written to the console output and
    to source-sync-manifest.json for review before commit.

    Each invocation writes artifacts to a unique execution-scoped directory beneath the run Guid, so
    a prior dry-run, editor, Explorer preview pane or concurrent process cannot block an apply by
    holding summary.json or another fixed artifact open.

.EXAMPLE
    .\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_QA" `
        -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
        -ReleaseReference "26.3" `
        -WhatIf

.EXAMPLE
    .\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_QA" `
        -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
        -ReleaseReference "26.3" `
        -Apply

.EXAMPLE
    .\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_QA" `
        -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
        -SyncSource

.EXAMPLE
    .\tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1 `
        -TargetServer "SOC-SQLDEVBRE01\GENERAL" `
        -TargetDatabase "CymBuild_QA" `
        -RunGuid "B92EC354-5517-4DA3-9FFE-CBC40455ABFA" `
        -VerifySource
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetServer,

    [Parameter(Mandatory = $true)]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $true)]
    [Guid]$RunGuid,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseReference = "",

    [Parameter(Mandatory = $false)]
    [string]$DeploymentReference = "",

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
    [switch]$AllowPartial,

    [Parameter(Mandatory = $false)]
    [switch]$AllowLive,

    [Parameter(Mandatory = $false)]
    [switch]$AllowNonDevSource,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreTargetMismatch,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAcceptanceCheck,

    [Parameter(Mandatory = $false)]
    [switch]$RetryFailedDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPreDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPostDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSourceMaterialization,

    [Parameter(Mandatory = $false)]
    [switch]$SyncSource,

    [Parameter(Mandatory = $false)]
    [switch]$VerifySource,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483)]
    [int]$ApplyLockTimeoutSeconds = 0,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$deploymentAuditStarted = $false
$sourceSyncBackups = @{}
$deploymentLockAcquired = $false
$deploymentLockResource = ""
$deploymentAttemptGuid = [Guid]::Empty
$deploymentAttemptNumber = 0
$planFingerprint = ""
$activeCheckpointItem = $null
$activeCheckpointPhase = ""
$sourceCommit = ""
$selectedSourceFingerprint = ""

if ($Apply -and $WhatIf) {
    throw "Specify either -Apply or -WhatIf, not both."
}

if ($Apply -and $AllowPartial) {
    throw "-Apply cannot be combined with -AllowPartial. A controlled apply requires the complete accepted selected plan; ignore or deselect unsupported rows in CymBuild, then validate and accept again."
}

if ($SyncSource -and $VerifySource) {
    throw "Specify either -SyncSource or -VerifySource, not both."
}

if (($SyncSource -or $VerifySource) -and $Apply) {
    throw "Schema source synchronization and verification are read-only with respect to the target database and cannot be combined with -Apply."
}

if (($SyncSource -or $VerifySource) -and $WhatIf) {
    throw "-SyncSource and -VerifySource are explicit source modes and cannot be combined with -WhatIf."
}

if ($SyncSource -and $SkipSourceMaterialization) {
    throw "-SyncSource cannot be combined with -SkipSourceMaterialization because source synchronization must be allowed to write selected repository artefacts."
}

if ($AllowNonDevSource -and -not ($SyncSource -or $VerifySource)) {
    throw "-AllowNonDevSource only relaxes the source-environment check for -SyncSource or -VerifySource and has no effect otherwise. Remove it, or add -SyncSource/-VerifySource."
}

if ($VerifySource) {
    $SkipSourceMaterialization = $true
}

if (($SyncSource -or $VerifySource) -and
    ($AllowPartial -or $SkipAcceptanceCheck -or $RetryFailedDeployment)) {
    throw "-SyncSource and -VerifySource require the complete accepted selection. They cannot be combined with -AllowPartial, -SkipAcceptanceCheck or -RetryFailedDeployment."
}

if ($RetryFailedDeployment -and ($SkipPreDeployment -or $SkipPostDeployment)) {
    throw "-RetryFailedDeployment cannot skip SCore.PreDeploymentScript or SCore.PostDeploymentScript. A controlled retry must return lifecycle-managed schema binding and dependencies to the prepared comparison state before selected DDL, then restore them before verification."
}

if (-not $Apply -and -not $SyncSource -and -not $VerifySource) {
    $WhatIf = $true
}

if (-not [string]::IsNullOrWhiteSpace($SqlUsername) -and $null -eq $SqlPassword) {
    throw "-SqlPassword is required when -SqlUsername is supplied."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if ([string]::IsNullOrWhiteSpace($DeploymentReference)) {
    if ([string]::IsNullOrWhiteSpace($ReleaseReference)) {
        $DeploymentReference = "ManualSchemaDeployment-$($RunGuid.ToString())"
    }
    else {
        $DeploymentReference = $ReleaseReference
    }
}

$outputDirectoryWasExplicit = -not [string]::IsNullOrWhiteSpace($OutputDirectory)
$executionMode = if ($SyncSource) {
    "source-sync"
}
elseif ($VerifySource) {
    "source-verify"
}
elseif ($Apply) {
    "apply"
}
else {
    "whatif"
}
$executionId = "{0}-{1}-pid{2}-{3}" -f `
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"), `
    $executionMode, `
    $PID, `
    ([Guid]::NewGuid().ToString("N").Substring(0, 8))

if (-not $outputDirectoryWasExplicit) {
    $runOutputRoot = Join-Path $RepoRoot "artifacts\schema-deployment\$($RunGuid.ToString())"
    $OutputDirectory = Join-Path $runOutputRoot "executions\$executionId"
}
else {
    $runOutputRoot = $OutputDirectory
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Write-CymBuildTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $false)]
        [int]$MaximumAttempts = 8
    )

    if ($MaximumAttempts -lt 1) {
        throw "MaximumAttempts must be at least 1."
    }

    if ($SyncSource -and
        (Test-ApprovedSchemaSourcePath -Path $Path) -and
        -not $sourceSyncBackups.ContainsKey($Path)) {
        $sourceSyncBackups[$Path] = if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [System.IO.File]::ReadAllBytes($Path)
        }
        else {
            $null
        }
    }

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $temporaryPath = Join-Path $directory (".{0}.{1}.{2}.tmp" -f ([System.IO.Path]::GetFileName($Path)), $PID, [Guid]::NewGuid().ToString("N"))
    $utf8WithBom = [System.Text.UTF8Encoding]::new($true)

    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, $utf8WithBom)

        for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
            try {
                if (Test-Path -LiteralPath $Path -PathType Leaf) {
                    Remove-Item -LiteralPath $Path -Force
                }

                Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
                return
            }
            catch {
                if ($attempt -ge $MaximumAttempts) {
                    throw "Unable to write artifact '$Path' after $MaximumAttempts attempts. The destination may be held open by another process. Original error: $($_.Exception.Message)"
                }

                $delayMilliseconds = [Math]::Min(1000, 100 * [Math]::Pow(2, $attempt - 1))
                Start-Sleep -Milliseconds ([int]$delayMilliseconds)
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Restore-CymBuildSourceSyncFiles {
    foreach ($path in $sourceSyncBackups.Keys) {
        $originalBytes = $sourceSyncBackups[$path]
        if ($null -eq $originalBytes) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Remove-Item -LiteralPath $path -Force
            }
            continue
        }

        $directory = Split-Path -Parent $path
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        [System.IO.File]::WriteAllBytes($path, $originalBytes)

        $restoredBytes = [System.IO.File]::ReadAllBytes($path)
        if ($restoredBytes.Length -ne $originalBytes.Length) {
            throw "Source-sync rollback length verification failed for '$path'."
        }
        for ($index = 0; $index -lt $originalBytes.Length; $index++) {
            if ($restoredBytes[$index] -ne $originalBytes[$index]) {
                throw "Source-sync rollback byte verification failed for '$path'."
            }
        }
    }
}

function ConvertTo-CymBuildCsvText {
    param([object[]]$Rows)

    if ($null -eq $Rows -or $Rows.Count -eq 0) {
        return ""
    }

    [string[]]$lines = @($Rows | ConvertTo-Csv -NoTypeInformation)
    return ([string]::Join("`r`n", $lines) + "`r`n")
}

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
    $builder["Application Name"] = "CymBuild.SchemaDeploymentRunner"

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

function Add-SqlParameter {
    param(
        [System.Data.SqlClient.SqlCommand]$Command,
        [string]$Name,
        [System.Data.SqlDbType]$Type,
        [object]$Value,
        [int]$Size = 0
    )

    $parameter = if ($Size -ne 0) {
        New-Object System.Data.SqlClient.SqlParameter($Name, $Type, $Size)
    }
    else {
        New-Object System.Data.SqlClient.SqlParameter($Name, $Type)
    }

    $parameter.Value = if ($null -eq $Value) { [DBNull]::Value } else { $Value }
    [void]$Command.Parameters.Add($parameter)
}

function Add-InferredSqlParameter {
    param(
        [System.Data.SqlClient.SqlCommand]$Command,
        [string]$Name,
        [object]$Value
    )

    if ($null -eq $Value -or $Value -is [DBNull]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::NVarChar) -Value $null -Size 1
        return
    }

    if ($Value -is [Guid]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::UniqueIdentifier) -Value $Value
        return
    }

    if ($Value -is [bool]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::Bit) -Value $Value
        return
    }

    if ($Value -is [byte]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::TinyInt) -Value $Value
        return
    }

    if ($Value -is [int16]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::SmallInt) -Value $Value
        return
    }

    if ($Value -is [int32]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::Int) -Value $Value
        return
    }

    if ($Value -is [int64]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::BigInt) -Value $Value
        return
    }

    if ($Value -is [datetime]) {
        Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::DateTime2) -Value $Value
        return
    }

    if ($Value -is [decimal]) {
        $parameter = New-Object System.Data.SqlClient.SqlParameter($Name, [System.Data.SqlDbType]::Decimal)
        $parameter.Precision = 38
        $parameter.Scale = 10
        $parameter.Value = $Value
        [void]$Command.Parameters.Add($parameter)
        return
    }

    $stringValue = [string]$Value
    $size = if ($stringValue.Length -gt 4000) { -1 } else { [Math]::Max(1, $stringValue.Length) }
    Add-SqlParameter -Command $Command -Name $Name -Type ([System.Data.SqlDbType]::NVarChar) -Value $stringValue -Size $size
}

function Add-SqlParameters {
    param(
        [System.Data.SqlClient.SqlCommand]$Command,
        [hashtable]$Parameters
    )

    foreach ($key in $Parameters.Keys) {
        Add-InferredSqlParameter -Command $Command -Name ([string]$key) -Value $Parameters[$key]
    }
}

function Invoke-SqlQuery {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Sql,
        [hashtable]$Parameters = @{},
        [int]$TimeoutSeconds = 300
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandType = [System.Data.CommandType]::Text
    $command.CommandTimeout = $TimeoutSeconds

    Add-SqlParameters -Command $command -Parameters $Parameters

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
        [hashtable]$Parameters = @{},
        [int]$TimeoutSeconds = 300
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandType = [System.Data.CommandType]::Text
    $command.CommandTimeout = $TimeoutSeconds

    Add-SqlParameters -Command $command -Parameters $Parameters

    try {
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Set-SchemaPreflightContext {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [bool]$PreDeploymentWillRun
    )

    Invoke-SqlNonQuery -Connection $Connection -Sql @"
EXEC sys.sp_set_session_context
    @key = N'CymBuild_schema_predeployment_will_run',
    @value = @ContextValue,
    @read_only = 0;
"@ -Parameters @{
        "@ContextValue" = $PreDeploymentWillRun
    }
}

function ConvertTo-JsonSafe {
    param([object]$Value)

    if ($null -eq $Value) {
        return "{}"
    }

    $json = $Value | ConvertTo-Json -Depth 12 -Compress
    if ($json.Length -gt 3900) {
        return $json.Substring(0, 3900)
    }

    return $json
}

function Add-SchemaExecutionLog {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Guid]$RunGuidValue,
        [string]$StepName,
        [string]$StepStatus,
        [string]$Message,
        [object]$Details
    )

    $detailsJson = ConvertTo-JsonSafe -Value $Details
    $messageValue = if ($null -eq $Message) { "" } else { $Message }
    $safeMessage = if ($messageValue.Length -gt 2000) { $messageValue.Substring(0, 2000) } else { $messageValue }

    Invoke-SqlNonQuery -Connection $Connection -Sql @"
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @LogGuid UNIQUEIDENTIFIER = NEWID();

    EXEC [SMigration].[SchemaDataObject_Ensure]
        @Guid = @LogGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Schema_ExecutionLog';

    INSERT INTO [SMigration].[Schema_ExecutionLog]
    (
        [Guid],
        [RowStatus],
        [RunGuid],
        [StepName],
        [StepStatus],
        [Message],
        [DetailsJson],
        [CreatedOnUtc]
    )
    VALUES
    (
        @LogGuid,
        1,
        @RunGuid,
        @StepName,
        @StepStatus,
        @Message,
        @DetailsJson,
        SYSUTCDATETIME()
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
"@ -Parameters @{
        "@RunGuid" = $RunGuidValue
        "@StepName" = $StepName
        "@StepStatus" = $StepStatus
        "@Message" = $safeMessage
        "@DetailsJson" = $detailsJson
    } -TimeoutSeconds 300
}

function Split-SqlBatches {
    param([string]$Sql)

    $batches = New-Object System.Collections.Generic.List[string]

    # Match GO-separator lines directly against the original text instead of splitting the
    # script into lines and rejoining them. A split/rejoin has no awareness of string-literal
    # context, so it normalizes every line ending in the script - including CR/LF characters
    # embedded inside a multi-line T-SQL string literal - to whatever the rejoin uses. That
    # mutates the literal text a CREATE/ALTER statement submits versus what the committed
    # source file and its accepted hash actually contain, so any object with a multi-line
    # string literal permanently fails pre/post-deployment verification. Locating GO lines by
    # position and slicing the untouched original string around them means every other byte -
    # including CR/LF inside string literals - reaches SQL Server unchanged.
    $goPattern = [regex]'(?m)^[ \t]*GO[ \t]*(\d+)?[ \t]*(?:--[^\r\n]*)?[ \t]*\r?$'

    $position = 0
    foreach ($match in $goPattern.Matches($Sql)) {
        $segment = $Sql.Substring($position, $match.Index - $position)
        $batch = $segment.Trim()
        if (-not [string]::IsNullOrWhiteSpace($batch)) {
            $repeatToken = $match.Groups[1].Value
            $repeatCount = if ([string]::IsNullOrWhiteSpace($repeatToken)) { 1 } else { [int]$repeatToken }
            if ($repeatCount -lt 1) {
                throw "Invalid GO repeat count '$repeatCount'."
            }

            for ($repeatIndex = 0; $repeatIndex -lt $repeatCount; $repeatIndex++) {
                [void]$batches.Add($batch)
            }
        }

        $position = $match.Index + $match.Length
    }

    $lastBatch = $Sql.Substring($position).Trim()
    if (-not [string]::IsNullOrWhiteSpace($lastBatch)) {
        [void]$batches.Add($lastBatch)
    }

    return [string[]]$batches.ToArray()
}

# Runs lifecycle SQL (SCore.PreDeploymentScript / PostDeploymentScript) holding the schema lifecycle
# lock in Shared mode, so a migration bootstrap cannot replace those procedures mid-run. Must match
# Concursus.EF.SchemaLifecycleLock.WrapLifecycleSql (2026-10-13 QA2 SQL 2801 incident).
function Get-CymBuildLifecycleLockedSql {
    param([Parameter(Mandatory)][string]$Sql)
    $resource = 'CymBuild.SchemaLifecycle'
    @"
DECLARE @CymBuildLifecycleLock int;
EXEC @CymBuildLifecycleLock = sys.sp_getapplock @Resource = N'$resource', @LockMode = N'Shared', @LockOwner = N'Session', @LockTimeout = 600000;
IF @CymBuildLifecycleLock < 0
    THROW 60381, N'Could not acquire the schema lifecycle lock ${resource}: a migration bootstrap is replacing the lifecycle procedures. Try again shortly.', 1;
BEGIN TRY
$Sql
END TRY
BEGIN CATCH
    EXEC sys.sp_releaseapplock @Resource = N'$resource', @LockOwner = N'Session';
    THROW;
END CATCH;
EXEC sys.sp_releaseapplock @Resource = N'$resource', @LockOwner = N'Session';
"@
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

function Test-SqlObjectExists {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$ObjectType,
        [string]$SchemaName,
        [string]$ObjectName
    )

    $sql = switch ($ObjectType) {
        "Schema" { "SELECT CONVERT(BIT, CASE WHEN SCHEMA_ID(@SchemaName) IS NULL THEN 0 ELSE 1 END) AS ExistsFlag;" }
        "Table" { "SELECT CONVERT(BIT, CASE WHEN OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName), N'U') IS NULL THEN 0 ELSE 1 END) AS ExistsFlag;" }
        "TableType" { "SELECT CONVERT(BIT, CASE WHEN TYPE_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName)) IS NULL THEN 0 ELSE 1 END) AS ExistsFlag;" }
        "Sequence" { "SELECT CONVERT(BIT, CASE WHEN OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName), N'SO') IS NULL THEN 0 ELSE 1 END) AS ExistsFlag;" }
        default { "SELECT CONVERT(BIT, CASE WHEN OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName)) IS NULL THEN 0 ELSE 1 END) AS ExistsFlag;" }
    }

    $table = Invoke-SqlQuery -Connection $Connection -Sql $sql -Parameters @{ "@SchemaName" = $SchemaName; "@ObjectName" = $ObjectName }
    return [bool]$table.Rows[0]["ExistsFlag"]
}

function Get-SourceSqlFile {
    param(
        [string]$ObjectType,
        [string]$SchemaName,
        [string]$ObjectName,
        [string]$ParentObjectName
    )

    $schemaRoot = Join-Path $RepoRoot "Database\CymBuild_DB\Schema"
    $fileName = "$SchemaName.$ObjectName.sql"

    switch ($ObjectType) {
        "Schema" { return Join-Path $schemaRoot "Security\Schemas\$SchemaName.sql" }
        "Table" { return Join-Path $schemaRoot "Tables\$fileName" }
        "TableType" { return Join-Path $schemaRoot "Programmability\User Types\Table Types\$fileName" }
        "Sequence" { return Join-Path $schemaRoot "Programmability\Sequences\$fileName" }
        "Function" { return Join-Path $schemaRoot "Programmability\Functions\$fileName" }
        "View" { return Join-Path $schemaRoot "Views\$fileName" }
        "StoredProcedure" { return Join-Path $schemaRoot "Programmability\Procedures\$fileName" }
        "Trigger" { return Join-Path $schemaRoot "Programmability\Triggers\$fileName" }
        "Constraint" { return (Get-CymBuildConstraintPaths -SchemaName $SchemaName -ParentObjectName $ParentObjectName -ObjectName $ObjectName).ApplyFile }
        default { return "" }
    }
}

function Get-DedicatedMigrationDescriptor {
    param(
        [string]$ObjectType,
        [string]$SchemaName,
        [string]$ObjectName,
        [string]$DifferenceType
    )

    $schemaRoot = Join-Path $RepoRoot "Database\CymBuild_DB\Schema"

    if ($ObjectType.Equals("Table", [System.StringComparison]::OrdinalIgnoreCase) -and
        $SchemaName.Equals("SCore", [System.StringComparison]::OrdinalIgnoreCase) -and
        $ObjectName.Equals("ObjectSecurity", [System.StringComparison]::OrdinalIgnoreCase) -and
        $DifferenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            SourceFile = Join-Path $schemaRoot "Migrations\CYB361\SCore.ObjectSecurity.alter.sql"
            PreflightFile = Join-Path $schemaRoot "Migrations\CYB361\SCore.ObjectSecurity.preflight.sql"
            SupportFiles = @(
                (Join-Path $schemaRoot "Migrations\_Shared\SMigration.AlterColumnNullabilityWithDependencies.sql")
            )
            # Approved CYB_TABLE_V2 source snapshot for the canonical
            # Database/CymBuild_DB/Schema/Tables/SCore.ObjectSecurity.sql shape.
            ExpectedSourceHash = "F8196E022BF3112E9064A03D5C684F01104A9D1DCCEFC66C00E88FFC96218465"
            DeploymentMode = "DedicatedMigration"
            Description = "Guarded data-preserving ObjectSecurity alignment using reusable ROWGUIDCOL, index and statistics dependency handling."
        }
    }

    return $null
}

function Test-ApprovedSchemaSourcePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $schemaRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot "Database\CymBuild_DB\Schema"))
    $candidatePath = [System.IO.Path]::GetFullPath($Path)
    $schemaRootPrefix = $schemaRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    return $candidatePath.StartsWith($schemaRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Convert-SchemaScriptForDeployment {
    param(
        [string]$Sql,
        [string]$ObjectType,
        [string]$SchemaName,
        [string]$ObjectName,
        [string]$DifferenceType
    )

    $sqlText = $Sql.TrimStart([char]0xFEFF)

    switch ($ObjectType) {
        "Schema" {
            $schemaEscaped = $SchemaName.Replace("]", "]]" )
            $schemaSqlLiteral = $SchemaName.Replace("'", "''")
            return "IF SCHEMA_ID(N'$schemaSqlLiteral') IS NULL`r`nBEGIN`r`n    EXEC(N'CREATE SCHEMA [$schemaEscaped];');`r`nEND;"
        }
        "Function" {
            return [regex]::Replace($sqlText, '(?im)^(\s*)(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)FUNCTION\b', '$1CREATE OR ALTER FUNCTION', 1)
        }
        "View" {
            return [regex]::Replace($sqlText, '(?im)^(\s*)(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)VIEW\b', '$1CREATE OR ALTER VIEW', 1)
        }
        "StoredProcedure" {
            $converted = [regex]::Replace($sqlText, '(?im)^(\s*)(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)PROCEDURE\b', '$1CREATE OR ALTER PROCEDURE', 1)
            if ($converted -eq $sqlText) {
                $converted = [regex]::Replace($sqlText, '(?im)^(\s*)(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)PROC\b', '$1CREATE OR ALTER PROC', 1)
            }
            return $converted
        }
        "Trigger" {
            return [regex]::Replace($sqlText, '(?im)^(\s*)(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)TRIGGER\b', '$1CREATE OR ALTER TRIGGER', 1)
        }
        default {
            return $sqlText
        }
    }
}

function Get-DataRowText {
    param(
        [System.Data.DataRow]$Row,
        [string]$ColumnName
    )

    # Type test, not -eq: PowerShell converts the right operand to the left operand's type, and
    # [bool][DBNull]::Value is $true, so an equality test against DBNull treated a BIT column
    # holding 1 as NULL. That silently read every ticked CYB-566 CopyReferenceData as unticked.
    if ($null -eq $Row -or
        -not $Row.Table.Columns.Contains($ColumnName) -or
        $Row[$ColumnName] -is [System.DBNull]) {
        return ""
    }

    return [string]$Row[$ColumnName]
}

function Test-CanMaterializeProgrammableObject {
    param([string]$ObjectType)

    return $ObjectType -in @("Function", "View", "StoredProcedure", "Trigger")
}

function Get-TextSha256 {
    param([string]$Text)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
    }
}

function ConvertTo-CymBuildFileNamePart {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "_"
    }

    return [regex]::Replace($Value.Trim(), '[<>:"/\\|?*\x00-\x1F]', '_')
}

function Quote-CymBuildSqlIdentifier {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "A SQL identifier cannot be empty."
    }

    return "[$($Value.Replace(']', ']]'))]"
}

function Quote-CymBuildSqlStringLiteral {
    param([string]$Value)

    $escapedValue = $Value.Replace("'", "''")
    return "N'$escapedValue'"
}

function Get-CymBuildDeterministicDefaultConstraintName {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [string]$ColumnName
    )

    $baseName = "DF_${SchemaName}_${TableName}_${ColumnName}"
    if ($baseName.Length -le 128) {
        return $baseName
    }

    $schemaPart = $SchemaName.Substring(0, [Math]::Min(20, $SchemaName.Length))
    $tablePart = $TableName.Substring(0, [Math]::Min(40, $TableName.Length))
    $columnPart = $ColumnName.Substring(0, [Math]::Min(40, $ColumnName.Length))
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $nameBytes = [System.Text.Encoding]::Unicode.GetBytes("$SchemaName.$TableName.$ColumnName")
        $nameHash = ([System.BitConverter]::ToString($sha256.ComputeHash($nameBytes))).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
    }
    $hashPart = $nameHash.Substring($nameHash.Length - 20, 20)
    $constraintName = "DF_${schemaPart}_${tablePart}_${columnPart}_${hashPart}"
    if ($constraintName.Length -gt 128) {
        throw "Unable to create a valid deterministic default-constraint name for '$SchemaName.$TableName.$ColumnName'."
    }

    return $constraintName
}

function Add-CymBuildDropDefaultConstraintByColumnSql {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$TableIdentifier,
        [string]$TableLiteral,
        [string]$ColumnLiteral
    )

    [void]$Lines.Add("    SET @CymBuildDefaultConstraintName = NULL;")
    [void]$Lines.Add("    SELECT @CymBuildDefaultConstraintName = dc.name FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID($TableLiteral, N'U') AND c.name = $ColumnLiteral;")
    [void]$Lines.Add("    IF @CymBuildDefaultConstraintName IS NOT NULL")
    [void]$Lines.Add("    BEGIN")
    [void]$Lines.Add("        SET @CymBuildDropDefaultSql = N'ALTER TABLE $TableIdentifier DROP CONSTRAINT ' + QUOTENAME(@CymBuildDefaultConstraintName) + N';';")
    [void]$Lines.Add("        EXEC sys.sp_executesql @CymBuildDropDefaultSql;")
    [void]$Lines.Add("    END;")
}

function Add-CymBuildDefaultConstraintNamePreflightSql {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$SchemaName,
        [string]$TableLiteral,
        [string]$ColumnLiteral,
        [string]$ConstraintName
    )

    $constraintObjectLiteral = Quote-CymBuildSqlStringLiteral -Value "[$SchemaName].[$ConstraintName]"
    $escapedLabel = "$SchemaName.$ConstraintName".Replace("'", "''")
    [void]$Lines.Add("IF OBJECT_ID($constraintObjectLiteral, N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID($constraintObjectLiteral, N'D') AND dc.parent_object_id = OBJECT_ID($TableLiteral, N'U') AND c.name = $ColumnLiteral) THROW 51422, 'Default constraint name $escapedLabel is already used by another column.', 1;")
}

function ConvertTo-CymBuildCollationSql {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "A SQL collation name cannot be empty."
    }

    $collationName = $Value.Trim()
    if ($collationName.Length -gt 128 -or
        -not [regex]::IsMatch($collationName, '\A[A-Za-z0-9_]+\z', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        throw "SQL collation name '$Value' contains unsupported characters."
    }

    # COLLATE expects a collation-name grammar token, not a delimited SQL
    # identifier. Emitting [SQL_Latin1_...] is invalid T-SQL.
    return $collationName
}

function ConvertTo-CymBuildBoolean {
    param([object]$Value)

    if ($null -eq $Value) {
        return $false
    }

    return [System.Convert]::ToBoolean($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-CymBuildObjectProperty {
    param(
        [object]$InputObject,
        [string]$PropertyName,
        [switch]$Required
    )

    if ($null -eq $InputObject) {
        if ($Required) {
            throw "Constraint definition property '$PropertyName' is required."
        }

        return $null
    }

    # Use the PSPropertyInfo value directly. Windows PowerShell 5.1 can expose
    # nested JSON arrays inconsistently through dynamic member enumeration;
    # direct lookup preserves one-column Columns arrays from ConvertFrom-Json.
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        if ($Required) {
            throw "Constraint definition property '$PropertyName' is required."
        }

        return $null
    }

    $value = $property.Value
    if ($Required -and
        ($null -eq $value -or
         ($value -is [string] -and ([string]$value).Length -eq 0) -or
         ($value -is [System.Collections.ICollection] -and $value.Count -eq 0))) {
        throw "Constraint definition property '$PropertyName' is required."
    }

    return $value
}

function Get-CymBuildConstraintPayload {
    param([string]$Definition)

    $prefix = "CYB_CONSTRAINT_V2|"
    if ([string]::IsNullOrWhiteSpace($Definition) -or -not $Definition.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        throw "Constraint definition is not in the CYB_CONSTRAINT_V2 declarative format. Run Stage & Compare again with the R40 API before accepting the plan."
    }

    $json = $Definition.Substring($prefix.Length)
    try {
        return ($json | ConvertFrom-Json)
    }
    catch {
        throw "Constraint definition JSON is invalid. $($_.Exception.Message)"
    }
}

function Test-CymBuildSystemNamedKeyConstraintDefinition {
    param([string]$Definition)

    # Mirrors CoreService IsSystemNamedKeyConstraintDefinition: a PRIMARY KEY / UNIQUE constraint
    # whose name SQL Server generated (is_system_named = 1).
    if ([string]::IsNullOrWhiteSpace($Definition) -or
        -not $Definition.StartsWith("CYB_CONSTRAINT_V2|", [System.StringComparison]::Ordinal)) {
        return $false
    }

    return $Definition.Contains('"IsSystemNamed":true') -and
        ($Definition.Contains('"ConstraintKind":"PRIMARY_KEY"') -or $Definition.Contains('"ConstraintKind":"UNIQUE"'))
}

function Get-CymBuildConstraintPaths {
    param(
        [string]$SchemaName,
        [string]$ParentObjectName,
        [string]$ObjectName
    )

    $schemaRoot = Join-Path $RepoRoot "Database\CymBuild_DB\Schema"
    $constraintRoot = Join-Path $schemaRoot "Constraints"
    $baseName = "{0}.{1}.{2}" -f `
        (ConvertTo-CymBuildFileNamePart -Value $SchemaName), `
        (ConvertTo-CymBuildFileNamePart -Value $ParentObjectName), `
        (ConvertTo-CymBuildFileNamePart -Value $ObjectName)

    return [pscustomobject]@{
        ApplyFile = Join-Path $constraintRoot "$baseName.sql"
        PrepareFile = Join-Path $constraintRoot "$baseName.prepare.sql"
        PreflightFile = Join-Path $constraintRoot "$baseName.preflight.sql"
    }
}

function Get-CymBuildConstraintActionSql {
    param([string]$Action)

    $normalizedAction = if ([string]::IsNullOrWhiteSpace($Action)) { "NO_ACTION" } else { $Action.ToUpperInvariant() }
    switch ($normalizedAction) {
        "NO_ACTION" { return "NO ACTION" }
        "CASCADE" { return "CASCADE" }
        "SET_NULL" { return "SET NULL" }
        "SET_DEFAULT" { return "SET DEFAULT" }
        default { throw "Unsupported referential action '$Action'." }
    }
}

function New-CymBuildGeneratedSchemaHeader {
    param(
        [string]$ObjectDescription,
        [string]$ComparisonGuid,
        [string]$DifferenceType,
        [string]$ComparisonHash,
        [string]$DefinitionSha256,
        [string]$Purpose
    )

    return @"
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : $ObjectDescription
    Difference         : $DifferenceType
    Comparison hash    : $ComparisonHash
    Definition SHA-256 : $DefinitionSha256
    Purpose            : $Purpose

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

"@
}

function ConvertTo-CymBuildNormalizedGeneratedSourceContent {
    param([AllowEmptyString()][string]$Content)

    if ($null -eq $Content) {
        return ""
    }

    $normalizedContent = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
    while ($normalizedContent.Length -gt 0 -and
        $normalizedContent[$normalizedContent.Length - 1] -eq [char]10) {
        $normalizedContent = $normalizedContent.Substring(0, $normalizedContent.Length - 1)
    }

    return $normalizedContent
}

function Write-CymBuildConstraintGeneratedFile {
    param(
        [string]$Path,
        [string]$Content,
        [string]$DefinitionSha256,
        [bool]$AllowCreate,
        [bool]$RequireDefinitionMatch = $false
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existingContent = Get-Content -LiteralPath $Path -Raw
        $isGeneratedFile = $existingContent.Contains("CymBuild generated canonical schema source.")
        if (-not $isGeneratedFile -and $RequireDefinitionMatch) {
            throw "Source-controlled file '$Path' is not a CymBuild generated file and cannot be verified against the selected declarative snapshot automatically."
        }

        if (-not $isGeneratedFile) {
            return $false
        }

        if ($existingContent.Contains("Definition SHA-256 : $DefinitionSha256")) {
            $normalizedExistingContent = ConvertTo-CymBuildNormalizedGeneratedSourceContent `
                -Content $existingContent
            $normalizedExpectedContent = ConvertTo-CymBuildNormalizedGeneratedSourceContent `
                -Content $Content
            $generatedContentMatches = $normalizedExistingContent.Equals(
                $normalizedExpectedContent,
                [System.StringComparison]::Ordinal)
            $hasDeterministicR7C4Header = $existingContent.Contains(
                "Generated by       : CYB-361 R7C4 selected DEV schema source sync")
            if ($RequireDefinitionMatch -and
                (-not $hasDeterministicR7C4Header -or -not $generatedContentMatches)) {
                if (-not $AllowCreate) {
                    throw "Generated source file '$Path' has the selected definition but does not match the current deterministic generator output. Run -SyncSource, review and commit the regenerated file, then run -VerifySource again."
                }

                Write-CymBuildTextFile -Path $Path -Content $Content
                return $true
            }

            if (-not $generatedContentMatches) {
                if (-not $AllowCreate) {
                    throw "Generated source file '$Path' does not match the current deterministic generator output and source materialization is disabled."
                }

                Write-CymBuildTextFile -Path $Path -Content $Content
                return $true
            }

            return $false
        }

        if (-not $AllowCreate) {
            throw "Generated constraint source file '$Path' is stale and source materialization is disabled."
        }

        Write-CymBuildTextFile -Path $Path -Content $Content
        return $true
    }

    if (-not $AllowCreate) {
        throw "Required source-controlled constraint file '$Path' is missing and source materialization is disabled."
    }

    Write-CymBuildTextFile -Path $Path -Content $Content
    return $true
}


function New-MaterializedConstraintSourceFiles {
    param(
        [System.Data.DataRow]$Row,
        [bool]$AllowCreate = $true,
        [bool]$RequireDefinitionMatch = $false
    )

    $schemaName = Get-DataRowText -Row $Row -ColumnName "SchemaName"
    $objectName = Get-DataRowText -Row $Row -ColumnName "ObjectName"
    $parentObjectName = Get-DataRowText -Row $Row -ColumnName "ParentObjectName"
    $differenceType = Get-DataRowText -Row $Row -ColumnName "DifferenceType"
    $comparisonGuid = Get-DataRowText -Row $Row -ColumnName "ComparisonGuid"
    $sourceHash = Get-DataRowText -Row $Row -ColumnName "SourceHash"
    $targetHash = Get-DataRowText -Row $Row -ColumnName "TargetHash"
    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"
    $targetDefinition = Get-DataRowText -Row $Row -ColumnName "TargetDefinition"
    $definition = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { $targetDefinition } else { $sourceDefinition }
    $comparisonHash = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { $targetHash } else { $sourceHash }
    $paths = Get-CymBuildConstraintPaths -SchemaName $schemaName -ParentObjectName $parentObjectName -ObjectName $objectName

    $result = [ordered]@{
        Succeeded = $false
        WasCreated = $false
        ApplyFile = ""
        PrepareFile = ""
        PreflightFile = ""
        MaterializedFiles = @()
        DefinitionSha256 = ""
        ConstraintKind = ""
        Reason = ""
    }

    try {
        if ([string]::IsNullOrWhiteSpace($parentObjectName)) {
            throw "Constraint '$schemaName.$objectName' does not have a parent table name."
        }

        $payload = Get-CymBuildConstraintPayload -Definition $definition
        $constraintKind = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ConstraintKind" -Required)
        $constraintKind = $constraintKind.ToUpperInvariant()
        if ($constraintKind -notin @("FOREIGN_KEY", "CHECK", "DEFAULT", "PRIMARY_KEY", "UNIQUE")) {
            throw "Unsupported constraint kind '$constraintKind'."
        }

        $definitionSha256 = Get-TextSha256 -Text $definition
        $tableName = "$(Quote-CymBuildSqlIdentifier -Value $schemaName).$(Quote-CymBuildSqlIdentifier -Value $parentObjectName)"
        $tableNameLiteral = Quote-CymBuildSqlStringLiteral -Value $tableName
        $requiredFiles = New-Object System.Collections.Generic.List[string]
        $createdFiles = New-Object System.Collections.Generic.List[string]
        $defaultParentColumnName = if ($constraintKind -eq "DEFAULT") {
            [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ParentColumnName" -Required)
        }
        else {
            ""
        }
        $constraintDeploymentName = if ($constraintKind -eq "DEFAULT") {
            [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ConstraintName" -Required)
        }
        else {
            $objectName
        }
        $constraintIdentifier = Quote-CymBuildSqlIdentifier -Value $constraintDeploymentName
        $constraintNameLiteral = Quote-CymBuildSqlStringLiteral -Value $constraintDeploymentName
        $objectDescription = if ($constraintDeploymentName.Equals($objectName, [System.StringComparison]::OrdinalIgnoreCase)) {
            "Constraint $schemaName.$parentObjectName.$objectName"
        }
        else {
            "Constraint $schemaName.$parentObjectName.$objectName deployed as $constraintDeploymentName"
        }

        $constraintExistsPredicate = @"
EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID($tableNameLiteral, N'U')
      AND constraintObject.name = $constraintNameLiteral
)
"@

        # PRIMARY KEY / UNIQUE constraints can be the mandatory KEY INDEX of a full-text
        # index (e.g. SOffice.OutlookEmails, SCrm.Accounts). SQL Server refuses to drop such
        # a constraint while the full-text index depends on it, and CREATE/DROP FULLTEXT INDEX
        # cannot run inside a user transaction, so both fragments below run as autocommit
        # batches outside the constraint drop/add transaction. Captured state is persisted in
        # SCore.SchemaDeploymentFullTextCapture (not a #temp table) so it survives a dropped
        # connection if the overall run aborts on a later, unrelated object between this
        # constraint's prepare and apply phases.
        $fullTextCaptureAndDropSql = ""
        $fullTextRecreateSql = ""
        if ($constraintKind -in @("PRIMARY_KEY", "UNIQUE")) {
            $schemaNameLiteral = Quote-CymBuildSqlStringLiteral -Value $schemaName
            $parentObjectNameLiteral = Quote-CymBuildSqlStringLiteral -Value $parentObjectName
            $constraintDeploymentNameLiteral = Quote-CymBuildSqlStringLiteral -Value $constraintDeploymentName
            $comparisonGuidLiteral = Quote-CymBuildSqlStringLiteral -Value $comparisonGuid
            $fullTextCaptureExistsPredicate = "EXISTS (SELECT 1 FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = $schemaNameLiteral AND [TableName] = $parentObjectNameLiteral)"

            $fullTextCaptureAndDropSql = @"
DELETE FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = $schemaNameLiteral AND [TableName] = $parentObjectNameLiteral;

INSERT INTO [SCore].[SchemaDeploymentFullTextCapture] ([ComparisonGuid], [SchemaName], [TableName], [ConstraintName], [CatalogName], [ChangeTrackingState], [StopListClause], [ColumnsClause])
SELECT
    $comparisonGuidLiteral,
    $schemaNameLiteral,
    $parentObjectNameLiteral,
    $constraintDeploymentNameLiteral,
    cat.name,
    CASE WHEN fi.change_tracking_state_desc IN (N'AUTO', N'MANUAL', N'OFF') THEN fi.change_tracking_state_desc ELSE N'AUTO' END,
    CASE
        WHEN fi.stoplist_id IS NULL THEN N'OFF'
        WHEN fi.stoplist_id = 0 THEN N'SYSTEM'
        ELSE QUOTENAME(sl.name)
    END,
    (
        SELECT STRING_AGG(
            CAST(
                QUOTENAME(col.name)
                + CASE WHEN fic.type_column_id IS NOT NULL AND fic.type_column_id <> 0
                       THEN N' TYPE COLUMN ' + QUOTENAME(typeCol.name)
                       ELSE N''
                  END
                + N' LANGUAGE ' + CAST(fic.language_id AS NVARCHAR(10))
                + CASE WHEN fic.statistical_semantics = 1 THEN N' STATISTICAL_SEMANTICS' ELSE N'' END
                AS NVARCHAR(MAX)
            ), N', '
        ) WITHIN GROUP (ORDER BY fic.column_id)
        FROM sys.fulltext_index_columns AS fic
        INNER JOIN sys.columns AS col ON col.object_id = fic.object_id AND col.column_id = fic.column_id
        LEFT JOIN sys.columns AS typeCol ON typeCol.object_id = fic.object_id AND typeCol.column_id = fic.type_column_id
        WHERE fic.object_id = fi.object_id
    )
FROM sys.fulltext_indexes AS fi
INNER JOIN sys.indexes AS idx ON idx.object_id = fi.object_id AND idx.index_id = fi.unique_index_id
LEFT JOIN sys.fulltext_catalogs AS cat ON cat.fulltext_catalog_id = fi.fulltext_catalog_id
LEFT JOIN sys.fulltext_stoplists AS sl ON sl.stoplist_id = fi.stoplist_id
WHERE fi.object_id = OBJECT_ID($tableNameLiteral, N'U')
  AND idx.name = $constraintNameLiteral;

IF $fullTextCaptureExistsPredicate
BEGIN
    DROP FULLTEXT INDEX ON $tableName;
END;
"@

            $fullTextRecreateSql = @"
IF $fullTextCaptureExistsPredicate
BEGIN
    DECLARE @CymBuildFullTextCatalogName SYSNAME;
    DECLARE @CymBuildFullTextChangeTracking NVARCHAR(20);
    DECLARE @CymBuildFullTextStopListClause NVARCHAR(300);
    DECLARE @CymBuildFullTextColumnsClause NVARCHAR(MAX);
    DECLARE @CymBuildFullTextCreateSql NVARCHAR(MAX);

    SELECT
        @CymBuildFullTextCatalogName = [CatalogName],
        @CymBuildFullTextChangeTracking = [ChangeTrackingState],
        @CymBuildFullTextStopListClause = [StopListClause],
        @CymBuildFullTextColumnsClause = [ColumnsClause]
    FROM [SCore].[SchemaDeploymentFullTextCapture]
    WHERE [SchemaName] = $schemaNameLiteral AND [TableName] = $parentObjectNameLiteral;

    IF @CymBuildFullTextColumnsClause IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID($tableNameLiteral, N'U'))
    BEGIN
        SET @CymBuildFullTextCreateSql =
            N'CREATE FULLTEXT INDEX ON $tableName(' + @CymBuildFullTextColumnsClause
            + N') KEY INDEX $constraintIdentifier ON ' + QUOTENAME(@CymBuildFullTextCatalogName)
            + N' WITH CHANGE_TRACKING ' + @CymBuildFullTextChangeTracking
            + N', STOPLIST ' + @CymBuildFullTextStopListClause + N';';
        EXEC sys.sp_executesql @CymBuildFullTextCreateSql;
    END;

    DELETE FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = $schemaNameLiteral AND [TableName] = $parentObjectNameLiteral;
END;
"@
        }

        if ($differenceType -in @("Different", "MissingInSource")) {
            $prepareHeader = New-CymBuildGeneratedSchemaHeader `
                -ObjectDescription $objectDescription `
                -ComparisonGuid $comparisonGuid `
                -DifferenceType $differenceType `
                -ComparisonHash $comparisonHash `
                -DefinitionSha256 $definitionSha256 `
                -Purpose "Prepare phase: remove the target constraint before structural deployment."
            $prepareSql = if ($constraintKind -eq "DEFAULT") {
                $defaultParentColumnLiteral = Quote-CymBuildSqlStringLiteral -Value $defaultParentColumnName
                @"
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @CymBuildDefaultConstraintName SYSNAME;
    DECLARE @CymBuildDropDefaultSql NVARCHAR(MAX);

    SELECT @CymBuildDefaultConstraintName = dc.name
    FROM sys.default_constraints AS dc
    INNER JOIN sys.columns AS c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID($tableNameLiteral, N'U')
      AND c.name = $defaultParentColumnLiteral;

    IF @CymBuildDefaultConstraintName IS NOT NULL
    BEGIN
        SET @CymBuildDropDefaultSql = N'ALTER TABLE $tableName DROP CONSTRAINT '
            + QUOTENAME(@CymBuildDefaultConstraintName)
            + N';';
        EXEC sys.sp_executesql @CymBuildDropDefaultSql;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@
            }
            else {
                $fullTextPrepareBatch = if ([string]::IsNullOrWhiteSpace($fullTextCaptureAndDropSql)) { "" } else {
                    "SET NOCOUNT ON;`r`n$fullTextCaptureAndDropSql`r`nGO`r`n"
                }
                @"
$fullTextPrepareBatch
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF $constraintExistsPredicate
    BEGIN
        ALTER TABLE $tableName DROP CONSTRAINT $constraintIdentifier;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@
            }
            [void]$requiredFiles.Add($paths.PrepareFile)
            $prepareContent = $prepareHeader + $prepareSql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PrepareFile -Content $prepareContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) {
                [void]$createdFiles.Add($paths.PrepareFile)
            }
            $result.PrepareFile = $paths.PrepareFile
        }

        if (-not $differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) {
            $preflightLines = New-Object System.Collections.Generic.List[string]
            [void]$preflightLines.Add("SET NOCOUNT ON;")
            [void]$preflightLines.Add("")
            [void]$preflightLines.Add("IF OBJECT_ID($tableNameLiteral, N'U') IS NULL")
            [void]$preflightLines.Add("    THROW 51400, 'Constraint parent table $schemaName.$parentObjectName does not exist.', 1;")

            $applyStatement = ""
            $postCreateStateStatement = ""

            switch ($constraintKind) {
                "FOREIGN_KEY" {
                    $referencedSchemaName = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ReferencedSchemaName" -Required)
                    $referencedTableName = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ReferencedTableName" -Required)
                    $columns = @((Get-CymBuildObjectProperty -InputObject $payload -PropertyName "Columns" -Required) | Sort-Object { [int]$_.ColumnOrder })
                    if ($columns.Count -eq 0) { throw "Foreign-key constraint '$objectName' has no columns." }

                    $parentColumns = New-Object System.Collections.Generic.List[string]
                    $referencedColumns = New-Object System.Collections.Generic.List[string]
                    foreach ($column in $columns) {
                        $parentColumn = [string](Get-CymBuildObjectProperty -InputObject $column -PropertyName "ParentColumn" -Required)
                        $referencedColumn = [string](Get-CymBuildObjectProperty -InputObject $column -PropertyName "ReferencedColumn" -Required)
                        [void]$parentColumns.Add((Quote-CymBuildSqlIdentifier -Value $parentColumn))
                        [void]$referencedColumns.Add((Quote-CymBuildSqlIdentifier -Value $referencedColumn))
                        [void]$preflightLines.Add("IF COL_LENGTH($tableNameLiteral, $(Quote-CymBuildSqlStringLiteral -Value $parentColumn)) IS NULL")
                        [void]$preflightLines.Add("    THROW 51401, 'Foreign-key parent column $schemaName.$parentObjectName.$parentColumn does not exist.', 1;")
                    }

                    $referencedTable = "$(Quote-CymBuildSqlIdentifier -Value $referencedSchemaName).$(Quote-CymBuildSqlIdentifier -Value $referencedTableName)"
                    $referencedTableLiteral = Quote-CymBuildSqlStringLiteral -Value $referencedTable
                    [void]$preflightLines.Add("IF OBJECT_ID($referencedTableLiteral, N'U') IS NULL")
                    [void]$preflightLines.Add("    THROW 51402, 'Foreign-key referenced table $referencedSchemaName.$referencedTableName does not exist.', 1;")
                    foreach ($column in $columns) {
                        $referencedColumn = [string]$column.ReferencedColumn
                        [void]$preflightLines.Add("IF COL_LENGTH($referencedTableLiteral, $(Quote-CymBuildSqlStringLiteral -Value $referencedColumn)) IS NULL")
                        [void]$preflightLines.Add("    THROW 51403, 'Foreign-key referenced column $referencedSchemaName.$referencedTableName.$referencedColumn does not exist.', 1;")
                    }

                    $deleteAction = Get-CymBuildConstraintActionSql -Action ([string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "DeleteAction"))
                    $updateAction = Get-CymBuildConstraintActionSql -Action ([string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "UpdateAction"))
                    $notForReplication = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsNotForReplication")) { " NOT FOR REPLICATION" } else { "" }
                    $referentialActions = " ON DELETE $deleteAction ON UPDATE $updateAction$notForReplication"
                    $applyStatement = "ALTER TABLE $tableName WITH NOCHECK ADD CONSTRAINT $constraintIdentifier FOREIGN KEY ($([string]::Join(', ', $parentColumns))) REFERENCES $referencedTable ($([string]::Join(', ', $referencedColumns)))$referentialActions;"
                    $postCreateStateStatement = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsDisabled")) {
                        "ALTER TABLE $tableName NOCHECK CONSTRAINT $constraintIdentifier;"
                    }
                    else {
                        "ALTER TABLE $tableName CHECK CONSTRAINT $constraintIdentifier;"
                    }
                }
                "CHECK" {
                    $checkDefinition = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "CheckDefinition" -Required)
                    if ([regex]::IsMatch($checkDefinition, '(?im)^\s*(?:GO|USE\s+)')) { throw "Check constraint definition contains a forbidden batch or database-context statement." }
                    $notForReplication = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsNotForReplication")) { " NOT FOR REPLICATION" } else { "" }
                    $applyStatement = "ALTER TABLE $tableName WITH NOCHECK ADD CONSTRAINT $constraintIdentifier CHECK$notForReplication $checkDefinition;"
                    $postCreateStateStatement = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsDisabled")) {
                        "ALTER TABLE $tableName NOCHECK CONSTRAINT $constraintIdentifier;"
                    }
                    else {
                        "ALTER TABLE $tableName CHECK CONSTRAINT $constraintIdentifier;"
                    }
                }
                "DEFAULT" {
                    $parentColumnName = $defaultParentColumnName
                    $defaultDefinition = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "DefaultDefinition" -Required)
                    if ([regex]::IsMatch($defaultDefinition, '(?im)^\s*(?:GO|USE\s+)')) { throw "Default constraint definition contains a forbidden batch or database-context statement." }
                    $parentColumnLiteral = Quote-CymBuildSqlStringLiteral -Value $parentColumnName
                    $constraintObjectLiteral = Quote-CymBuildSqlStringLiteral -Value "[$schemaName].[$constraintDeploymentName]"
                    [void]$preflightLines.Add("IF COL_LENGTH($tableNameLiteral, $parentColumnLiteral) IS NULL")
                    [void]$preflightLines.Add("    THROW 51404, 'Default-constraint column $schemaName.$parentObjectName.$parentColumnName does not exist.', 1;")
                    [void]$preflightLines.Add("IF OBJECT_ID($constraintObjectLiteral, N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID($constraintObjectLiteral, N'D') AND dc.parent_object_id = OBJECT_ID($tableNameLiteral, N'U') AND c.name = $parentColumnLiteral) THROW 51422, 'Default constraint name $schemaName.$constraintDeploymentName is already used by another column.', 1;")
                    [void]$preflightLines.Add("IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID($tableNameLiteral, N'U') AND c.name = $parentColumnLiteral AND dc.name <> $constraintNameLiteral) THROW 51423, 'Default-constraint column $schemaName.$parentObjectName.$parentColumnName already has a different constraint.', 1;")
                    $applyStatement = "ALTER TABLE $tableName ADD CONSTRAINT $constraintIdentifier DEFAULT $defaultDefinition FOR $(Quote-CymBuildSqlIdentifier -Value $parentColumnName);"
                }
                { $_ -in @("PRIMARY_KEY", "UNIQUE") } {
                    $indexType = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IndexType" -Required)
                    $indexType = $indexType.ToUpperInvariant()
                    if ($indexType -notin @("CLUSTERED", "NONCLUSTERED")) { throw "Unsupported key-constraint index type '$indexType'." }
                    if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsDisabled")) { throw "Disabled PRIMARY KEY or UNIQUE constraints require a dedicated reviewed migration." }
                    $dataSpaceType = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "DataSpaceType")
                    if (-not [string]::IsNullOrWhiteSpace($dataSpaceType) -and -not $dataSpaceType.Equals("ROWS_FILEGROUP", [System.StringComparison]::OrdinalIgnoreCase)) {
                        throw "Key constraint '$objectName' uses unsupported data-space type '$dataSpaceType'. Partitioned and specialist constraints require a dedicated migration."
                    }
                    $columns = @((Get-CymBuildObjectProperty -InputObject $payload -PropertyName "Columns" -Required) | Sort-Object { [int]$_.KeyOrdinal })
                    if ($columns.Count -eq 0) { throw "Key constraint '$objectName' has no columns." }
                    $columnSql = New-Object System.Collections.Generic.List[string]
                    $groupBySql = New-Object System.Collections.Generic.List[string]
                    $nullPredicates = New-Object System.Collections.Generic.List[string]
                    foreach ($column in $columns) {
                        $columnName = [string](Get-CymBuildObjectProperty -InputObject $column -PropertyName "ColumnName" -Required)
                        $quotedColumn = Quote-CymBuildSqlIdentifier -Value $columnName
                        $direction = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $column -PropertyName "IsDescending")) { "DESC" } else { "ASC" }
                        [void]$columnSql.Add("$quotedColumn $direction")
                        [void]$groupBySql.Add($quotedColumn)
                        [void]$nullPredicates.Add("$quotedColumn IS NULL")
                        [void]$preflightLines.Add("IF COL_LENGTH($tableNameLiteral, $(Quote-CymBuildSqlStringLiteral -Value $columnName)) IS NULL")
                        [void]$preflightLines.Add("    THROW 51405, 'Key-constraint column $schemaName.$parentObjectName.$columnName does not exist.', 1;")
                    }

                    if ($constraintKind -eq "PRIMARY_KEY") {
                        [void]$preflightLines.Add("IF EXISTS (SELECT 1 FROM $tableName WHERE $([string]::Join(' OR ', $nullPredicates)))")
                        [void]$preflightLines.Add("    THROW 51406, 'PRIMARY KEY constraint $objectName cannot be created because NULL key values exist.', 1;")
                    }
                    [void]$preflightLines.Add("IF EXISTS (SELECT $([string]::Join(', ', $groupBySql)) FROM $tableName GROUP BY $([string]::Join(', ', $groupBySql)) HAVING COUNT_BIG(1) > 1)")
                    [void]$preflightLines.Add("    THROW 51407, 'Key constraint $objectName cannot be created because duplicate key values exist.', 1;")

                    $options = New-Object System.Collections.Generic.List[string]
                    [void]$options.Add("PAD_INDEX = $(if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName 'IsPadded')) { 'ON' } else { 'OFF' })")
                    [void]$options.Add("IGNORE_DUP_KEY = $(if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName 'IgnoreDuplicateKey')) { 'ON' } else { 'OFF' })")
                    [void]$options.Add("ALLOW_ROW_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName 'AllowRowLocks')) { 'ON' } else { 'OFF' })")
                    [void]$options.Add("ALLOW_PAGE_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName 'AllowPageLocks')) { 'ON' } else { 'OFF' })")
                    $fillFactor = [int](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "FillFactor")
                    if ($fillFactor -gt 100) { throw "Constraint fill factor must be between 1 and 100." }
                    # See the equivalent index path above (SchemaMigration index materialization) for
                    # why an explicit FILLFACTOR = 100 is emitted rather than omitting the option when
                    # the captured value is 0: omission inherits the target server's configured
                    # default fill factor, which is not guaranteed to be 0.
                    [void]$options.Add("FILLFACTOR = $(if ($fillFactor -gt 0) { $fillFactor } else { 100 })")
                    $keyKeyword = if ($constraintKind -eq "PRIMARY_KEY") { "PRIMARY KEY" } else { "UNIQUE" }
                    $dataSpaceName = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "DataSpaceName")
                    $onClause = if ([string]::IsNullOrWhiteSpace($dataSpaceName)) { "" } else { " ON $(Quote-CymBuildSqlIdentifier -Value $dataSpaceName)" }
                    $applyStatement = "ALTER TABLE $tableName ADD CONSTRAINT $constraintIdentifier $keyKeyword $indexType ($([string]::Join(', ', $columnSql))) WITH ($([string]::Join(', ', $options)))$onClause;"
                }
            }

            $preflightHeader = New-CymBuildGeneratedSchemaHeader `
                -ObjectDescription $objectDescription `
                -ComparisonGuid $comparisonGuid `
                -DifferenceType $differenceType `
                -ComparisonHash $comparisonHash `
                -DefinitionSha256 $definitionSha256 `
                -Purpose "Read-only preflight for the selected constraint operation."
            [void]$requiredFiles.Add($paths.PreflightFile)
            $preflightContent = $preflightHeader + ([string]::Join("`r`n", $preflightLines)) + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) {
                [void]$createdFiles.Add($paths.PreflightFile)
            }

            $applyHeader = New-CymBuildGeneratedSchemaHeader `
                -ObjectDescription $objectDescription `
                -ComparisonGuid $comparisonGuid `
                -DifferenceType $differenceType `
                -ComparisonHash $comparisonHash `
                -DefinitionSha256 $definitionSha256 `
                -Purpose "Finalize phase: create the source constraint from the declarative snapshot."
            $stateSql = if ([string]::IsNullOrWhiteSpace($postCreateStateStatement)) { "" } else { "`r`n    $postCreateStateStatement" }
            $fullTextApplyBatch = if ([string]::IsNullOrWhiteSpace($fullTextRecreateSql)) { "" } else {
                "GO`r`nSET NOCOUNT ON;`r`n$fullTextRecreateSql"
            }
            $applySql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT $constraintExistsPredicate
    BEGIN
        $applyStatement
    END;$stateSql

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
$fullTextApplyBatch
"@
            [void]$requiredFiles.Add($paths.ApplyFile)
            $applyContent = $applyHeader + $applySql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) {
                [void]$createdFiles.Add($paths.ApplyFile)
            }
            $result.ApplyFile = $paths.ApplyFile
            $result.PreflightFile = $paths.PreflightFile
        }

        foreach ($requiredFile in $requiredFiles) {
            if (-not (Test-ApprovedSchemaSourcePath -Path $requiredFile)) {
                throw "Constraint source path '$requiredFile' is outside Database/CymBuild_DB/Schema."
            }
            if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
                throw "Required generated constraint source file '$requiredFile' does not exist."
            }
        }

        $result.Succeeded = $true
        $result.WasCreated = $createdFiles.Count -gt 0
        $result.MaterializedFiles = [string[]]$createdFiles.ToArray()
        $result.DefinitionSha256 = $definitionSha256
        $result.ConstraintKind = $constraintKind
        $result.Reason = if ($result.WasCreated) {
            "Constraint prepare/preflight/apply SQL was materialized from the accepted declarative snapshot."
        }
        else {
            "Source-controlled constraint SQL files were resolved."
        }
        return [pscustomobject]$result
    }
    catch {
        $result.Reason = $_.Exception.Message
        return [pscustomobject]$result
    }
}


function Get-CymBuildDeclarativePayload {
    param(
        [string]$Definition,
        [string]$Prefix,
        [string]$ObjectDescription
    )

    if ([string]::IsNullOrWhiteSpace($Definition) -or
        -not $Definition.StartsWith($Prefix, [System.StringComparison]::Ordinal)) {
        throw "$ObjectDescription is not in the required '$Prefix' declarative format. Run Stage & Compare again before accepting the plan."
    }

    try {
        return ($Definition.Substring($Prefix.Length) | ConvertFrom-Json)
    }
    catch {
        throw "$ObjectDescription declarative JSON is invalid. $($_.Exception.Message)"
    }
}

function Get-CymBuildPropertyText {
    param(
        [object]$InputObject,
        [string]$PropertyName
    )

    $value = Get-CymBuildObjectProperty -InputObject $InputObject -PropertyName $PropertyName
    if ($null -eq $value) {
        return ""
    }

    return [string]$value
}

function Test-CymBuildForbiddenSqlFragment {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return [regex]::IsMatch($Value, '(?im)^\s*(?:GO\s*(?:--.*)?$|USE\s+)')
}

function Get-CymBuildColumnTypeSql {
    param([object]$Column)

    $dataTypeName = (Get-CymBuildPropertyText -InputObject $Column -PropertyName "DataTypeName").ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($dataTypeName)) {
        throw "A table column is missing DataTypeName."
    }

    if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsUserDefined")) {
        $typeSchemaName = Get-CymBuildPropertyText -InputObject $Column -PropertyName "TypeSchemaName"
        if ([string]::IsNullOrWhiteSpace($typeSchemaName)) {
            throw "User-defined type '$dataTypeName' is missing TypeSchemaName."
        }

        return "$(Quote-CymBuildSqlIdentifier -Value $typeSchemaName).$(Quote-CymBuildSqlIdentifier -Value $dataTypeName)"
    }

    $maximumLength = [int](Get-CymBuildObjectProperty -InputObject $Column -PropertyName "MaxLength" -Required)
    $precision = [int](Get-CymBuildObjectProperty -InputObject $Column -PropertyName "PrecisionValue" -Required)
    $scale = [int](Get-CymBuildObjectProperty -InputObject $Column -PropertyName "ScaleValue" -Required)

    switch ($dataTypeName) {
        { $_ -in @("varchar", "char", "varbinary", "binary") } {
            $length = if ($maximumLength -eq -1 -and $_ -in @("varchar", "varbinary")) { "MAX" } else { [string]$maximumLength }
            if ($maximumLength -eq 0 -or $maximumLength -lt -1) { throw "Invalid maximum length for data type '$dataTypeName'." }
            return "$dataTypeName($length)"
        }
        { $_ -in @("nvarchar", "nchar") } {
            if ($maximumLength -eq -1 -and $_ -eq "nvarchar") { return "nvarchar(MAX)" }
            if ($maximumLength -le 0 -or ($maximumLength % 2) -ne 0) { throw "Invalid Unicode maximum length for data type '$dataTypeName'." }
            return "$dataTypeName($([int]($maximumLength / 2)))"
        }
        { $_ -in @("decimal", "numeric") } { return "$dataTypeName($precision,$scale)" }
        { $_ -in @("datetime2", "datetimeoffset", "time") } { return "$dataTypeName($scale)" }
        "float" { return "float($precision)" }
        { $_ -in @(
            "bigint", "int", "smallint", "tinyint", "bit", "money", "smallmoney", "real",
            "date", "datetime", "smalldatetime", "uniqueidentifier", "rowversion", "timestamp",
            "text", "ntext", "image", "xml", "sql_variant", "sysname", "hierarchyid", "geometry", "geography"
        ) } { return $dataTypeName }
        default { throw "Built-in data type '$dataTypeName' is not supported by automatic table convergence." }
    }
}

function Get-CymBuildColumnDeclarationSql {
    param(
        [object]$Column,
        [switch]$ForAlter
    )

    $columnName = Get-CymBuildPropertyText -InputObject $Column -PropertyName "ColumnName"
    if ([string]::IsNullOrWhiteSpace($columnName)) {
        throw "A table column is missing ColumnName."
    }

    $columnIdentifier = Quote-CymBuildSqlIdentifier -Value $columnName
    $isComputed = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsComputed")
    if ($isComputed) {
        if ($ForAlter) {
            throw "Computed column '$columnName' cannot be altered in place."
        }

        $computedDefinition = Get-CymBuildPropertyText -InputObject $Column -PropertyName "ComputedDefinition"
        if ([string]::IsNullOrWhiteSpace($computedDefinition) -or (Test-CymBuildForbiddenSqlFragment -Value $computedDefinition)) {
            throw "Computed column '$columnName' has an invalid definition."
        }

        $persisted = if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsPersisted")) { " PERSISTED" } else { "" }
        return "$columnIdentifier AS $computedDefinition$persisted"
    }

    $encryptionType = Get-CymBuildPropertyText -InputObject $Column -PropertyName "EncryptionType"
    $generatedAlwaysType = Get-CymBuildPropertyText -InputObject $Column -PropertyName "GeneratedAlwaysType"
    $isGeneratedAlways = -not [string]::IsNullOrWhiteSpace($generatedAlwaysType) -and
        -not $generatedAlwaysType.Equals("NOT_APPLICABLE", [System.StringComparison]::OrdinalIgnoreCase)
    if (-not [string]::IsNullOrWhiteSpace($encryptionType) -or $isGeneratedAlways) {
        throw "Encrypted or GENERATED ALWAYS column '$columnName' requires a dedicated source-controlled migration."
    }

    if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsColumnSet")) {
        throw "COLUMN_SET column '$columnName' requires a dedicated source-controlled migration."
    }

    $declaration = "$columnIdentifier $(Get-CymBuildColumnTypeSql -Column $Column)"
    $collationName = Get-CymBuildPropertyText -InputObject $Column -PropertyName "CollationName"
    if (-not [string]::IsNullOrWhiteSpace($collationName)) {
        $declaration += " COLLATE $(ConvertTo-CymBuildCollationSql -Value $collationName)"
    }

    if (-not $ForAlter) {
        if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsFileStream")) {
            $declaration += " FILESTREAM"
        }
        if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsSparse")) {
            $declaration += " SPARSE"
        }
        if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsRowGuidCol")) {
            $declaration += " ROWGUIDCOL"
        }
        if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsIdentity")) {
            $identitySeed = Get-CymBuildPropertyText -InputObject $Column -PropertyName "IdentitySeed"
            $identityIncrement = Get-CymBuildPropertyText -InputObject $Column -PropertyName "IdentityIncrement"
            if ([string]::IsNullOrWhiteSpace($identitySeed) -or [string]::IsNullOrWhiteSpace($identityIncrement)) {
                throw "Identity column '$columnName' is missing its seed or increment."
            }
            $declaration += " IDENTITY($identitySeed,$identityIncrement)"
        }
    }

    $declaration += if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsNullable")) { " NULL" } else { " NOT NULL" }
    return $declaration
}

function Get-CymBuildBackfillExpression {
    param([object]$Column)

    $sourceDefault = Get-CymBuildPropertyText -InputObject $Column -PropertyName "DefaultDefinition"
    if (-not [string]::IsNullOrWhiteSpace($sourceDefault)) {
        if (Test-CymBuildForbiddenSqlFragment -Value $sourceDefault) {
            throw "The source default contains a forbidden batch or database-context statement."
        }
        return $sourceDefault
    }

    if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $Column -PropertyName "IsUserDefined")) {
        throw "A NOT NULL user-defined-type column without a source default cannot be backfilled automatically."
    }

    $dataTypeName = (Get-CymBuildPropertyText -InputObject $Column -PropertyName "DataTypeName").ToLowerInvariant()
    switch ($dataTypeName) {
        { $_ -in @("bigint", "int", "smallint", "tinyint", "decimal", "numeric", "money", "smallmoney", "float", "real", "bit") } { return "(0)" }
        { $_ -in @("char", "varchar", "text") } { return "('')" }
        { $_ -in @("nchar", "nvarchar", "ntext", "sysname") } { return "(N'')" }
        { $_ -in @("binary", "varbinary", "image") } { return "(0x)" }
        "uniqueidentifier" { return "(CONVERT(uniqueidentifier, '00000000-0000-0000-0000-000000000000'))" }
        "date" { return "(CONVERT(date, '19000101', 112))" }
        { $_ -in @("datetime", "smalldatetime", "datetime2") } { return "(CONVERT($dataTypeName, '19000101', 112))" }
        "datetimeoffset" { return "(CONVERT(datetimeoffset, '1900-01-01T00:00:00+00:00', 127))" }
        "time" { return "(CONVERT(time, '00:00:00'))" }
        "xml" { return "(CONVERT(xml, N''))" }
        "sql_variant" { return "(CONVERT(sql_variant, 0))" }
        "hierarchyid" { return "(hierarchyid::GetRoot())" }
        default { throw "Data type '$dataTypeName' has no approved CymBuild backfill default. Add an explicit source default or a dedicated migration." }
    }
}

function Test-CymBuildColumnPropertyDifference {
    param(
        [object]$SourceColumn,
        [object]$TargetColumn,
        [string[]]$PropertyNames
    )

    foreach ($propertyName in $PropertyNames) {
        if (-not (Get-CymBuildPropertyText -InputObject $SourceColumn -PropertyName $propertyName).Equals(
            (Get-CymBuildPropertyText -InputObject $TargetColumn -PropertyName $propertyName),
            [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-CymBuildTableMigrationPaths {
    param(
        [string]$SchemaName,
        [string]$TableName
    )

    $root = Join-Path $RepoRoot "Database\CymBuild_DB\Schema\Migrations\Generated\Tables"
    $baseName = "{0}.{1}" -f (ConvertTo-CymBuildFileNamePart -Value $SchemaName), (ConvertTo-CymBuildFileNamePart -Value $TableName)
    return [pscustomobject]@{
        ApplyFile = Join-Path $root "$baseName.alter.sql"
        PreflightFile = Join-Path $root "$baseName.preflight.sql"
    }
}

function New-MaterializedTableSourceFiles {
    param(
        [System.Data.DataRow]$Row,
        [bool]$AllowCreate = $true,
        [bool]$RequireDefinitionMatch = $false
    )

    $schemaName = Get-DataRowText -Row $Row -ColumnName "SchemaName"
    $tableName = Get-DataRowText -Row $Row -ColumnName "ObjectName"
    $differenceType = Get-DataRowText -Row $Row -ColumnName "DifferenceType"
    $comparisonGuid = Get-DataRowText -Row $Row -ColumnName "ComparisonGuid"
    $sourceHash = Get-DataRowText -Row $Row -ColumnName "SourceHash"
    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"
    $targetDefinition = Get-DataRowText -Row $Row -ColumnName "TargetDefinition"
    $paths = Get-CymBuildTableMigrationPaths -SchemaName $schemaName -TableName $tableName
    $result = [ordered]@{ Succeeded = $false; WasCreated = $false; ApplyFile = ""; PreflightFile = ""; MaterializedFiles = @(); DefinitionSha256 = ""; Reason = "" }

    try {
        if (-not $differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Automatic existing-table convergence is valid only for a Different table row."
        }

        $source = Get-CymBuildDeclarativePayload -Definition $sourceDefinition -Prefix "CYB_TABLE_V2|" -ObjectDescription "Table $schemaName.$tableName source definition"
        $target = Get-CymBuildDeclarativePayload -Definition $targetDefinition -Prefix "CYB_TABLE_V2|" -ObjectDescription "Table $schemaName.$tableName target definition"
        foreach ($payload in @($source, $target)) {
            if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IsMemoryOptimized")) {
                throw "Memory-optimized table '$schemaName.$tableName' requires a dedicated migration."
            }
            $temporalType = Get-CymBuildPropertyText -InputObject $payload -PropertyName "TemporalType"
            if (-not [string]::IsNullOrWhiteSpace($temporalType) -and -not $temporalType.Equals("NON_TEMPORAL_TABLE", [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Temporal table '$schemaName.$tableName' requires a dedicated migration."
            }
            $durability = Get-CymBuildPropertyText -InputObject $payload -PropertyName "Durability"
            if (-not [string]::IsNullOrWhiteSpace($durability) -and -not $durability.Equals("SCHEMA_AND_DATA", [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "SCHEMA_ONLY table '$schemaName.$tableName' requires a dedicated migration."
            }
        }

        $sourceColumns = @((Get-CymBuildObjectProperty -InputObject $source -PropertyName "Columns" -Required))
        $targetColumns = @((Get-CymBuildObjectProperty -InputObject $target -PropertyName "Columns" -Required))
        $sourceByName = @{}
        $targetByName = @{}
        foreach ($column in $sourceColumns) {
            $name = Get-CymBuildPropertyText -InputObject $column -PropertyName "ColumnName"
            if ([string]::IsNullOrWhiteSpace($name) -or $sourceByName.ContainsKey($name)) { throw "The source table snapshot contains a missing or duplicate column name." }
            $sourceByName[$name] = $column
        }
        foreach ($column in $targetColumns) {
            $name = Get-CymBuildPropertyText -InputObject $column -PropertyName "ColumnName"
            if ([string]::IsNullOrWhiteSpace($name) -or $targetByName.ContainsKey($name)) { throw "The target table snapshot contains a missing or duplicate column name." }
            $targetByName[$name] = $column
        }

        $tableIdentifier = "$(Quote-CymBuildSqlIdentifier -Value $schemaName).$(Quote-CymBuildSqlIdentifier -Value $tableName)"
        $tableLiteral = Quote-CymBuildSqlStringLiteral -Value $tableIdentifier
        $preflight = New-Object System.Collections.Generic.List[string]
        $apply = New-Object System.Collections.Generic.List[string]
        [void]$preflight.Add("SET NOCOUNT ON;")
        [void]$preflight.Add("IF OBJECT_ID($tableLiteral, N'U') IS NULL THROW 51420, 'Table convergence parent table does not exist.', 1;")
        [void]$apply.Add("SET NOCOUNT ON;")
        [void]$apply.Add("SET XACT_ABORT ON;")
        [void]$apply.Add("BEGIN TRY")
        [void]$apply.Add("    BEGIN TRANSACTION;")
        [void]$apply.Add("    DECLARE @CymBuildDefaultConstraintName SYSNAME;")
        [void]$apply.Add("    DECLARE @CymBuildDropDefaultSql NVARCHAR(MAX);")

        $alterProperties = @("TypeSchemaName", "DataTypeName", "IsUserDefined", "MaxLength", "PrecisionValue", "ScaleValue", "IsNullable", "CollationName")
        $fixedProperties = @("IsIdentity", "IdentitySeed", "IdentityIncrement", "IsComputed", "ComputedDefinition", "IsPersisted", "IsAnsiPadded", "IsRowGuidCol", "IsSparse", "IsColumnSet", "IsFileStream", "GeneratedAlwaysType", "EncryptionType")

        foreach ($sourceColumn in $sourceColumns) {
            $columnName = Get-CymBuildPropertyText -InputObject $sourceColumn -PropertyName "ColumnName"
            $columnIdentifier = Quote-CymBuildSqlIdentifier -Value $columnName
            $columnLiteral = Quote-CymBuildSqlStringLiteral -Value $columnName
            $sourceDefaultName = Get-CymBuildPropertyText -InputObject $sourceColumn -PropertyName "DefaultConstraintName"
            $sourceDefaultDefinition = Get-CymBuildPropertyText -InputObject $sourceColumn -PropertyName "DefaultDefinition"

            if (-not $targetByName.ContainsKey($columnName)) {
                $declaration = Get-CymBuildColumnDeclarationSql -Column $sourceColumn
                $isNullable = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsNullable")
                $isIdentity = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsIdentity")
                $isComputed = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsComputed")
                $dataTypeName = (Get-CymBuildPropertyText -InputObject $sourceColumn -PropertyName "DataTypeName").ToLowerInvariant()
                $defaultClause = ""
                $withValues = ""
                $temporaryDefaultName = ""
                if (-not [string]::IsNullOrWhiteSpace($sourceDefaultDefinition)) {
                    if (Test-CymBuildForbiddenSqlFragment -Value $sourceDefaultDefinition) { throw "Column '$columnName' has an invalid source default." }
                    if ([string]::IsNullOrWhiteSpace($sourceDefaultName)) {
                        $sourceDefaultName = Get-CymBuildDeterministicDefaultConstraintName -SchemaName $schemaName -TableName $tableName -ColumnName $columnName
                    }
                    Add-CymBuildDefaultConstraintNamePreflightSql -Lines $preflight -SchemaName $schemaName -TableLiteral $tableLiteral -ColumnLiteral $columnLiteral -ConstraintName $sourceDefaultName
                    $defaultClause = " CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $sourceDefaultName) DEFAULT $sourceDefaultDefinition"
                    if (-not $isNullable) { $withValues = " WITH VALUES" }
                }
                elseif (-not $isNullable -and -not $isIdentity -and -not $isComputed -and $dataTypeName -notin @("rowversion", "timestamp")) {
                    $temporaryDefaultName = "DF_CymBuild_Migration_$((Get-TextSha256 -Text "$schemaName.$tableName.$columnName").Substring(0, 16))"
                    $defaultClause = " CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $temporaryDefaultName) DEFAULT $(Get-CymBuildBackfillExpression -Column $sourceColumn)"
                    $withValues = " WITH VALUES"
                }
                [void]$apply.Add("    IF COL_LENGTH($tableLiteral, $columnLiteral) IS NULL")
                [void]$apply.Add("        ALTER TABLE $tableIdentifier ADD $declaration$defaultClause$withValues;")
                if (-not [string]::IsNullOrWhiteSpace($temporaryDefaultName)) {
                    [void]$apply.Add("    IF OBJECT_ID($(Quote-CymBuildSqlStringLiteral -Value "[$schemaName].[$temporaryDefaultName]"), N'D') IS NOT NULL")
                    [void]$apply.Add("        ALTER TABLE $tableIdentifier DROP CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $temporaryDefaultName);")
                }
                continue
            }

            $targetColumn = $targetByName[$columnName]
            if (Test-CymBuildColumnPropertyDifference -SourceColumn $sourceColumn -TargetColumn $targetColumn -PropertyNames $fixedProperties) {
                throw "Column '$schemaName.$tableName.$columnName' changes identity, computed, ANSI_PADDING, ROWGUIDCOL, SPARSE, FILESTREAM, generated or encrypted characteristics and requires a dedicated migration."
            }

            $requiresAlter = Test-CymBuildColumnPropertyDifference -SourceColumn $sourceColumn -TargetColumn $targetColumn -PropertyNames $alterProperties
            $targetDefaultName = Get-CymBuildPropertyText -InputObject $targetColumn -PropertyName "DefaultConstraintName"
            $targetDefaultDefinition = Get-CymBuildPropertyText -InputObject $targetColumn -PropertyName "DefaultDefinition"
            $defaultDiffers = -not $sourceDefaultName.Equals($targetDefaultName, [System.StringComparison]::OrdinalIgnoreCase) -or
                -not $sourceDefaultDefinition.Equals($targetDefaultDefinition, [System.StringComparison]::OrdinalIgnoreCase)

            if ($requiresAlter) {
                if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsUserDefined")) {
                    throw "Automatic conversion to user-defined type for '$schemaName.$tableName.$columnName' is not supported."
                }
                $sourceTypeName = (Get-CymBuildPropertyText -InputObject $sourceColumn -PropertyName "DataTypeName").ToLowerInvariant()
                if ($sourceTypeName -in @("rowversion", "timestamp", "text", "ntext", "image", "geometry", "geography")) {
                    throw "Automatic conversion to data type '$sourceTypeName' for '$schemaName.$tableName.$columnName' requires a dedicated migration."
                }
                $typeSql = Get-CymBuildColumnTypeSql -Column $sourceColumn
                $escapedLabel = ("$schemaName.$tableName.$columnName").Replace("'", "''")
                [void]$preflight.Add("IF EXISTS (SELECT 1 FROM $tableIdentifier WHERE $columnIdentifier IS NOT NULL AND TRY_CONVERT($typeSql, $columnIdentifier) IS NULL) THROW 51421, 'Table convergence conversion failed for $escapedLabel.', 1;")
                Add-CymBuildDropDefaultConstraintByColumnSql -Lines $apply -TableIdentifier $tableIdentifier -TableLiteral $tableLiteral -ColumnLiteral $columnLiteral
                $sourceNullable = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsNullable")
                if (-not $sourceNullable) {
                    [void]$apply.Add("    UPDATE $tableIdentifier SET $columnIdentifier = $(Get-CymBuildBackfillExpression -Column $sourceColumn) WHERE $columnIdentifier IS NULL;")
                }
                [void]$apply.Add("    ALTER TABLE $tableIdentifier ALTER COLUMN $(Get-CymBuildColumnDeclarationSql -Column $sourceColumn -ForAlter);")
                $defaultDiffers = $true
            }

            if ($defaultDiffers) {
                if (-not $requiresAlter) {
                    Add-CymBuildDropDefaultConstraintByColumnSql -Lines $apply -TableIdentifier $tableIdentifier -TableLiteral $tableLiteral -ColumnLiteral $columnLiteral
                }
                if (-not [string]::IsNullOrWhiteSpace($sourceDefaultDefinition)) {
                    if (Test-CymBuildForbiddenSqlFragment -Value $sourceDefaultDefinition) { throw "Column '$columnName' has an invalid source default." }
                    if ([string]::IsNullOrWhiteSpace($sourceDefaultName)) {
                        $sourceDefaultName = Get-CymBuildDeterministicDefaultConstraintName -SchemaName $schemaName -TableName $tableName -ColumnName $columnName
                    }
                    Add-CymBuildDefaultConstraintNamePreflightSql -Lines $preflight -SchemaName $schemaName -TableLiteral $tableLiteral -ColumnLiteral $columnLiteral -ConstraintName $sourceDefaultName
                    [void]$apply.Add("    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID($tableLiteral, N'U') AND c.name = $columnLiteral) ALTER TABLE $tableIdentifier ADD CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $sourceDefaultName) DEFAULT $sourceDefaultDefinition FOR $columnIdentifier;")
                }
            }
        }

        foreach ($targetColumn in $targetColumns) {
            $columnName = Get-CymBuildPropertyText -InputObject $targetColumn -PropertyName "ColumnName"
            if ($sourceByName.ContainsKey($columnName)) { continue }
            $columnIdentifier = Quote-CymBuildSqlIdentifier -Value $columnName
            $columnLiteral = Quote-CymBuildSqlStringLiteral -Value $columnName
            Add-CymBuildDropDefaultConstraintByColumnSql -Lines $apply -TableIdentifier $tableIdentifier -TableLiteral $tableLiteral -ColumnLiteral $columnLiteral
            [void]$apply.Add("    IF COL_LENGTH($tableLiteral, $columnLiteral) IS NOT NULL ALTER TABLE $tableIdentifier DROP COLUMN $columnIdentifier;")
        }

        $sourceLockEscalation = Get-CymBuildPropertyText -InputObject $source -PropertyName "LockEscalation"
        $targetLockEscalation = Get-CymBuildPropertyText -InputObject $target -PropertyName "LockEscalation"
        if (-not $sourceLockEscalation.Equals($targetLockEscalation, [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($sourceLockEscalation -notin @("AUTO", "TABLE", "DISABLE")) { throw "Unsupported LOCK_ESCALATION value '$sourceLockEscalation'." }
            [void]$apply.Add("    ALTER TABLE $tableIdentifier SET (LOCK_ESCALATION = $sourceLockEscalation);")
        }

        [void]$apply.Add("    COMMIT TRANSACTION;")
        [void]$apply.Add("END TRY")
        [void]$apply.Add("BEGIN CATCH")
        [void]$apply.Add("    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;")
        [void]$apply.Add("    THROW;")
        [void]$apply.Add("END CATCH;")

        $definitionSha256 = Get-TextSha256 -Text ("$sourceDefinition`n$targetDefinition")
        $headerArguments = @{
            ObjectDescription = "Table $schemaName.$tableName"
            ComparisonGuid = $comparisonGuid
            DifferenceType = $differenceType
            ComparisonHash = $sourceHash
            DefinitionSha256 = $definitionSha256
        }
        $preflightContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Read-only preflight for declarative existing-table convergence.") + ([string]::Join("`r`n", $preflight)) + "`r`nGO`r`n"
        $applyContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Apply guarded, idempotent column and table-option convergence.") + ([string]::Join("`r`n", $apply)) + "`r`nGO`r`n"
        $createdFiles = New-Object System.Collections.Generic.List[string]
        if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) { [void]$createdFiles.Add($paths.PreflightFile) }
        if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) { [void]$createdFiles.Add($paths.ApplyFile) }
        foreach ($requiredFile in @($paths.PreflightFile, $paths.ApplyFile)) {
            if (-not (Test-ApprovedSchemaSourcePath -Path $requiredFile) -or -not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Required table convergence source file '$requiredFile' is unavailable." }
        }
        $result.Succeeded = $true
        $result.WasCreated = $createdFiles.Count -gt 0
        $result.MaterializedFiles = [string[]]$createdFiles.ToArray()
        $result.DefinitionSha256 = $definitionSha256
        $result.ApplyFile = $paths.ApplyFile
        $result.PreflightFile = $paths.PreflightFile
        $result.Reason = if ($result.WasCreated) { "Table convergence SQL was materialized from the accepted declarative snapshots." } else { "Source-controlled table convergence SQL files were resolved." }
        return [pscustomobject]$result
    }
    catch {
        $result.Reason = $_.Exception.Message
        return [pscustomobject]$result
    }
}

function Get-CymBuildIndexMigrationPaths {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [string]$IndexName
    )

    $root = Join-Path $RepoRoot "Database\CymBuild_DB\Schema\Indexes"
    $baseName = "{0}.{1}.{2}" -f (ConvertTo-CymBuildFileNamePart -Value $SchemaName), (ConvertTo-CymBuildFileNamePart -Value $TableName), (ConvertTo-CymBuildFileNamePart -Value $IndexName)
    return [pscustomobject]@{
        ApplyFile = Join-Path $root "$baseName.sql"
        PrepareFile = Join-Path $root "$baseName.prepare.sql"
        PreflightFile = Join-Path $root "$baseName.preflight.sql"
    }
}

function Get-CymBuildNewTableIntegerSentinelTypes {
    return @("bigint", "int", "smallint")
}

function New-MaterializedNewTableSourceFile {
    <#
        CYB-566: a selected table that is MissingInTarget used to be unsupported - -SyncSource never
        wrote a CREATE TABLE, so the run failed and the table's own constraint/index rows could not
        be deployed. This generates the canonical create file at Schema\Tables\<Schema>.<Table>.sql
        from the accepted declarative source snapshot plus the selection's NewTableCaptureJson
        (captured read-only from the source by the API at selection save):

          1. CREATE TABLE - columns and their named defaults only, in source column order. Keys,
             unique constraints, indexes and foreign keys stay as their own plan rows, which the
             runner applies after this file.
          2. The -1 sentinel row, always: ID -1, zero Guid, every other column its default. A
             NOT NULL integer column with no default takes -1 (the CymBuild FK sentinel); any
             other NOT NULL column with no default stops generation rather than guessing.
          3. The captured source rows, only when "Copy reference data" was ticked, keyed on the
             Guid column and inserted with their source identity values (safe only because the
             table is brand new and empty).
          4. SCore.DataObjects rows for seeded rows, with EntityTypeId resolved from
             SCore.EntityHobts on the target. If the table has no registration yet, it warns and
             skips; the EntityTypeId is never guessed.

        A hand-written canonical create file already at that path is left untouched and used as
        before, unless reference data was requested, which it cannot carry.
    #>
    param(
        [System.Data.DataRow]$Row,
        [bool]$AllowCreate = $true,
        [bool]$RequireDefinitionMatch = $false
    )

    $schemaName = Get-DataRowText -Row $Row -ColumnName "SchemaName"
    $tableName = Get-DataRowText -Row $Row -ColumnName "ObjectName"
    $differenceType = Get-DataRowText -Row $Row -ColumnName "DifferenceType"
    $comparisonGuid = Get-DataRowText -Row $Row -ColumnName "ComparisonGuid"
    $sourceHash = Get-DataRowText -Row $Row -ColumnName "SourceHash"
    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"
    $captureJson = Get-DataRowText -Row $Row -ColumnName "NewTableCaptureJson"
    $copyReferenceDataText = Get-DataRowText -Row $Row -ColumnName "CopyReferenceData"
    $copyReferenceData = -not [string]::IsNullOrWhiteSpace($copyReferenceDataText) -and (ConvertTo-CymBuildBoolean -Value $copyReferenceDataText)
    $path = [System.IO.Path]::GetFullPath((Get-SourceSqlFile -ObjectType "Table" -SchemaName $schemaName -ObjectName $tableName -ParentObjectName ""))
    $result = [ordered]@{ Succeeded = $false; UseExistingFile = $false; WasCreated = $false; SourceFile = $path; MaterializedFiles = @(); DefinitionSha256 = ""; Reason = "" }

    try {
        if (-not $differenceType.Equals("MissingInTarget", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "New-table generation is valid only for a MissingInTarget table row."
        }

        if (-not (Test-ApprovedSchemaSourcePath -Path $path)) {
            throw "Resolved source path is outside Database/CymBuild_DB/Schema."
        }

        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $existingContent = Get-Content -LiteralPath $path -Raw
            if (-not $existingContent.Contains("CymBuild generated canonical schema source.")) {
                if ($copyReferenceData) {
                    throw "A hand-written canonical create file already exists at '$path'. It cannot carry generated reference data; add the rows to it through review, or remove it so the runner can generate it, then untick or re-save ""Copy reference data""."
                }

                $result.Succeeded = $true
                $result.UseExistingFile = $true
                $result.Reason = "Existing hand-written canonical create file was resolved."
                return [pscustomobject]$result
            }
        }

        if ([string]::IsNullOrWhiteSpace($captureJson)) {
            throw "Selection for new table '$schemaName.$tableName' has no captured source column order. Save the selection again in CymBuild (it captures the new table from the source), revalidate, accept, then re-run."
        }

        try {
            $capture = $captureJson | ConvertFrom-Json
        }
        catch {
            throw "Captured source data for new table '$schemaName.$tableName' is not valid JSON. Save the selection again. $($_.Exception.Message)"
        }

        $source = Get-CymBuildDeclarativePayload -Definition $sourceDefinition -Prefix "CYB_TABLE_V2|" -ObjectDescription "Table $schemaName.$tableName source definition"
        if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $source -PropertyName "IsMemoryOptimized")) {
            throw "Memory-optimized table '$schemaName.$tableName' requires a dedicated migration."
        }
        $temporalType = Get-CymBuildPropertyText -InputObject $source -PropertyName "TemporalType"
        if (-not [string]::IsNullOrWhiteSpace($temporalType) -and -not $temporalType.Equals("NON_TEMPORAL_TABLE", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Temporal table '$schemaName.$tableName' requires a dedicated migration."
        }
        $durability = Get-CymBuildPropertyText -InputObject $source -PropertyName "Durability"
        if (-not [string]::IsNullOrWhiteSpace($durability) -and -not $durability.Equals("SCHEMA_AND_DATA", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "SCHEMA_ONLY table '$schemaName.$tableName' requires a dedicated migration."
        }

        $sourceColumns = @((Get-CymBuildObjectProperty -InputObject $source -PropertyName "Columns" -Required))
        $columnsByName = @{}
        foreach ($column in $sourceColumns) {
            $name = Get-CymBuildPropertyText -InputObject $column -PropertyName "ColumnName"
            if ([string]::IsNullOrWhiteSpace($name) -or $columnsByName.ContainsKey($name)) { throw "The source table snapshot contains a missing or duplicate column name." }
            $columnsByName[$name] = $column
        }

        # The declarative snapshot is ordered by name (ordinal is deliberately outside the hash),
        # so the physical order comes from the capture. It must describe exactly the same columns.
        $columnOrder = @($capture.ColumnOrder | ForEach-Object { [string]$_ })
        $orderedNames = @($columnOrder | Sort-Object)
        $snapshotNames = @($columnsByName.Keys | Sort-Object)
        if ($orderedNames.Count -ne $snapshotNames.Count -or (Compare-Object -ReferenceObject $orderedNames -DifferenceObject $snapshotNames -CaseSensitive)) {
            throw "The captured source columns for '$schemaName.$tableName' no longer match the compared definition. Run Compare again and re-save the selection."
        }

        $tableIdentifier = "$(Quote-CymBuildSqlIdentifier -Value $schemaName).$(Quote-CymBuildSqlIdentifier -Value $tableName)"
        $tableLiteral = Quote-CymBuildSqlStringLiteral -Value $tableIdentifier

        $identityColumn = $null
        $guidColumn = $null
        $columnLines = New-Object System.Collections.Generic.List[string]
        $insertableColumns = New-Object System.Collections.Generic.List[object]
        foreach ($columnName in $columnOrder) {
            $column = $columnsByName[$columnName]
            $declaration = Get-CymBuildColumnDeclarationSql -Column $column
            $defaultDefinition = Get-CymBuildPropertyText -InputObject $column -PropertyName "DefaultDefinition"
            if (-not [string]::IsNullOrWhiteSpace($defaultDefinition)) {
                if (Test-CymBuildForbiddenSqlFragment -Value $defaultDefinition) {
                    throw "The source default for '$schemaName.$tableName.$columnName' contains a forbidden batch or database-context statement."
                }
                $defaultName = Get-CymBuildPropertyText -InputObject $column -PropertyName "DefaultConstraintName"
                if ([string]::IsNullOrWhiteSpace($defaultName)) {
                    $defaultName = Get-CymBuildDeterministicDefaultConstraintName -SchemaName $schemaName -TableName $tableName -ColumnName $columnName
                }
                $declaration += " CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $defaultName) DEFAULT $defaultDefinition"
            }
            [void]$columnLines.Add("        $declaration")

            $dataTypeName = (Get-CymBuildPropertyText -InputObject $column -PropertyName "DataTypeName").ToLowerInvariant()
            $isComputed = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $column -PropertyName "IsComputed")
            if ($isComputed -or $dataTypeName -in @("timestamp", "rowversion")) { continue }

            if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $column -PropertyName "IsIdentity")) { $identityColumn = $columnName }
            if (ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $column -PropertyName "IsRowGuidCol")) { $guidColumn = $columnName }
            [void]$insertableColumns.Add([pscustomobject]@{
                Name = $columnName
                Column = $column
                DataTypeName = $dataTypeName
                HasDefault = -not [string]::IsNullOrWhiteSpace($defaultDefinition)
                IsNullable = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $column -PropertyName "IsNullable")
            })
        }

        if ($null -eq $guidColumn -and $columnsByName.ContainsKey("Guid") -and
            (Get-CymBuildPropertyText -InputObject $columnsByName["Guid"] -PropertyName "DataTypeName").Equals("uniqueidentifier", [System.StringComparison]::OrdinalIgnoreCase)) {
            $guidColumn = "Guid"
        }

        $sentinelKeyColumn = if ($null -ne $identityColumn) { $identityColumn } elseif ($columnsByName.ContainsKey("ID")) { "ID" } else { $null }

        $lines = New-Object System.Collections.Generic.List[string]
        [void]$lines.Add("SET NOCOUNT ON;")
        [void]$lines.Add("IF OBJECT_ID($tableLiteral, N'U') IS NULL")
        [void]$lines.Add("BEGIN")
        [void]$lines.Add("    CREATE TABLE $tableIdentifier")
        [void]$lines.Add("    (")
        [void]$lines.Add([string]::Join(",`r`n", $columnLines))
        [void]$lines.Add("    );")
        $lockEscalation = Get-CymBuildPropertyText -InputObject $source -PropertyName "LockEscalation"
        if (-not [string]::IsNullOrWhiteSpace($lockEscalation) -and -not $lockEscalation.Equals("TABLE", [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($lockEscalation -notin @("AUTO", "DISABLE")) { throw "Unsupported LOCK_ESCALATION value '$lockEscalation'." }
            [void]$lines.Add("    ALTER TABLE $tableIdentifier SET (LOCK_ESCALATION = $lockEscalation);")
        }
        [void]$lines.Add("END;")
        [void]$lines.Add("GO")
        [void]$lines.Add("")

        # ---- seed: reference rows (optional), the -1 sentinel (always), DataObjects rows ----
        $seed = New-Object System.Collections.Generic.List[string]
        [void]$seed.Add("SET NOCOUNT ON;")
        [void]$seed.Add("SET XACT_ABORT ON;")
        [void]$seed.Add("BEGIN TRY")
        [void]$seed.Add("    BEGIN TRANSACTION;")
        if ($null -ne $identityColumn) {
            [void]$seed.Add("    SET IDENTITY_INSERT $tableIdentifier ON;")
        }

        $rows = $capture.Rows
        $hasRows = $copyReferenceData -and $null -ne $rows
        if ($copyReferenceData -and $null -eq $rows) {
            throw "Reference data was requested for '$schemaName.$tableName' but no rows were captured. Save the selection again."
        }

        if ($hasRows) {
            # Embed the captured rows exactly as the source produced them (FOR JSON). Round-tripping
            # through ConvertFrom-Json/ConvertTo-Json would reformat dates and decimals.
            $rowsMarker = ',"Rows":'
            $rowsStart = $captureJson.IndexOf($rowsMarker, [System.StringComparison]::Ordinal)
            if ($rowsStart -lt 0 -or -not $captureJson.EndsWith("}")) {
                throw "Captured source data for new table '$schemaName.$tableName' is not in the expected format. Save the selection again."
            }
            $rowsJson = $captureJson.Substring($rowsStart + $rowsMarker.Length, $captureJson.Length - $rowsStart - $rowsMarker.Length - 1)
            $columnListSql = [string]::Join(", ", @($insertableColumns | ForEach-Object { Quote-CymBuildSqlIdentifier -Value $_.Name }))
            $withClauses = @($insertableColumns | ForEach-Object {
                $jsonPath = '$."' + $_.Name.Replace('"', '\"') + '"'
                "        $(Quote-CymBuildSqlIdentifier -Value $_.Name) $(Get-CymBuildColumnTypeSql -Column $_.Column) $(Quote-CymBuildSqlStringLiteral -Value $jsonPath)"
            })
            $duplicateGuards = New-Object System.Collections.Generic.List[string]
            foreach ($keyColumn in @($guidColumn, $sentinelKeyColumn) | Where-Object { $null -ne $_ } | Select-Object -Unique) {
                $keyIdentifier = Quote-CymBuildSqlIdentifier -Value $keyColumn
                [void]$duplicateGuards.Add("NOT EXISTS (SELECT 1 FROM $tableIdentifier AS existingRow WHERE existingRow.$keyIdentifier = sourceRow.$keyIdentifier)")
            }
            $whereSql = if ($duplicateGuards.Count -gt 0) { "    WHERE " + [string]::Join("`r`n      AND ", $duplicateGuards) } else { "" }

            [void]$seed.Add("")
            [void]$seed.Add("    -- Reference data captured from the source (""Copy reference data"" was ticked).")
            [void]$seed.Add("    DECLARE @CymBuildReferenceRows NVARCHAR(MAX) = $(Quote-CymBuildSqlStringLiteral -Value $rowsJson);")
            [void]$seed.Add("    INSERT INTO $tableIdentifier ($columnListSql)")
            [void]$seed.Add("    SELECT $([string]::Join(', ', @($insertableColumns | ForEach-Object { 'sourceRow.' + (Quote-CymBuildSqlIdentifier -Value $_.Name) })))")
            [void]$seed.Add("    FROM OPENJSON(@CymBuildReferenceRows)")
            [void]$seed.Add("    WITH")
            [void]$seed.Add("    (")
            [void]$seed.Add([string]::Join(",`r`n", $withClauses))
            [void]$seed.Add("    ) AS sourceRow")
            if (-not [string]::IsNullOrWhiteSpace($whereSql)) { [void]$seed.Add($whereSql) }
            [void]$seed.Add("    ;")
        }

        if ($null -ne $sentinelKeyColumn) {
            $sentinelColumns = New-Object System.Collections.Generic.List[string]
            $sentinelValues = New-Object System.Collections.Generic.List[string]
            foreach ($insertable in $insertableColumns) {
                if ($insertable.Name -eq $sentinelKeyColumn) {
                    [void]$sentinelColumns.Add((Quote-CymBuildSqlIdentifier -Value $insertable.Name)); [void]$sentinelValues.Add("-1"); continue
                }
                if ($null -ne $guidColumn -and $insertable.Name -eq $guidColumn) {
                    [void]$sentinelColumns.Add((Quote-CymBuildSqlIdentifier -Value $insertable.Name)); [void]$sentinelValues.Add("'00000000-0000-0000-0000-000000000000'"); continue
                }
                if ($insertable.HasDefault -or $insertable.IsNullable) { continue }
                if ($insertable.DataTypeName -in (Get-CymBuildNewTableIntegerSentinelTypes)) {
                    [void]$sentinelColumns.Add((Quote-CymBuildSqlIdentifier -Value $insertable.Name)); [void]$sentinelValues.Add("-1"); continue
                }
                throw "Cannot create the -1 row for '$schemaName.$tableName': NOT NULL column '$($insertable.Name)' ($($insertable.DataTypeName)) has no default. Give it a default in DEV, or make it nullable, then Compare and save the selection again."
            }

            $sentinelKeyIdentifier = Quote-CymBuildSqlIdentifier -Value $sentinelKeyColumn
            $sentinelGuard = "NOT EXISTS (SELECT 1 FROM $tableIdentifier WHERE $sentinelKeyIdentifier = -1)"
            if ($null -ne $guidColumn) {
                $sentinelGuard += " AND NOT EXISTS (SELECT 1 FROM $tableIdentifier WHERE $(Quote-CymBuildSqlIdentifier -Value $guidColumn) = '00000000-0000-0000-0000-000000000000')"
            }
            [void]$seed.Add("")
            [void]$seed.Add("    -- The -1 sentinel row: ID -1, zero Guid, every other column its default.")
            [void]$seed.Add("    IF $sentinelGuard")
            [void]$seed.Add("        INSERT INTO $tableIdentifier ($([string]::Join(', ', $sentinelColumns))) VALUES ($([string]::Join(', ', $sentinelValues)));")
        }
        else {
            [void]$seed.Add("")
            [void]$seed.Add("    -- No identity or ID column: the -1 sentinel convention does not apply to this table.")
        }

        if ($null -ne $identityColumn) {
            [void]$seed.Add("")
            [void]$seed.Add("    SET IDENTITY_INSERT $tableIdentifier OFF;")
        }

        if ($hasRows -and $null -ne $guidColumn) {
            $guidIdentifier = Quote-CymBuildSqlIdentifier -Value $guidColumn
            [void]$seed.Add("")
            [void]$seed.Add("    -- Every managed row needs its SCore.DataObjects row with the correct EntityTypeId.")
            [void]$seed.Add("    DECLARE @CymBuildEntityTypeId INT =")
            [void]$seed.Add("    (")
            [void]$seed.Add("        SELECT TOP (1) eh.[EntityTypeID]")
            [void]$seed.Add("        FROM [SCore].[EntityHobts] AS eh")
            [void]$seed.Add("        WHERE eh.[SchemaName] = $(Quote-CymBuildSqlStringLiteral -Value $schemaName)")
            [void]$seed.Add("          AND eh.[ObjectName] = $(Quote-CymBuildSqlStringLiteral -Value $tableName)")
            [void]$seed.Add("          AND eh.[RowStatus] NOT IN (0,254)")
            [void]$seed.Add("    );")
            [void]$seed.Add("    IF @CymBuildEntityTypeId IS NULL")
            [void]$seed.Add("        PRINT N'WARNING: $($tableIdentifier.Replace("'", "''")) has no SCore.EntityHobts registration; SCore.DataObjects rows were not created for its reference rows.';")
            [void]$seed.Add("    ELSE")
            [void]$seed.Add("        INSERT INTO [SCore].[DataObjects] ([Guid], [RowStatus], [EntityTypeId])")
            [void]$seed.Add("        SELECT t.$guidIdentifier, 1, @CymBuildEntityTypeId")
            [void]$seed.Add("        FROM $tableIdentifier AS t")
            [void]$seed.Add("        WHERE t.$guidIdentifier <> '00000000-0000-0000-0000-000000000000'")
            [void]$seed.Add("          AND NOT EXISTS (SELECT 1 FROM [SCore].[DataObjects] AS d WHERE d.[Guid] = t.$guidIdentifier);")
        }

        [void]$seed.Add("")
        [void]$seed.Add("    COMMIT TRANSACTION;")
        [void]$seed.Add("END TRY")
        [void]$seed.Add("BEGIN CATCH")
        [void]$seed.Add("    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;")
        if ($null -ne $identityColumn) {
            [void]$seed.Add("    SET IDENTITY_INSERT $tableIdentifier OFF;")
        }
        [void]$seed.Add("    THROW;")
        [void]$seed.Add("END CATCH;")
        [void]$seed.Add("GO")

        $definitionSha256 = Get-TextSha256 -Text ("CYB566_NEW_TABLE_V1`n$sourceDefinition`n$captureJson`n$([int]$copyReferenceData)")
        $purpose = if ($copyReferenceData) {
            "Create the new table (columns and named defaults), then its -1 row and the captured reference rows, before its keys, indexes and foreign keys."
        } else {
            "Create the new table (columns and named defaults), then its -1 row, before its keys, indexes and foreign keys."
        }
        $content = (New-CymBuildGeneratedSchemaHeader -ObjectDescription "Table $schemaName.$tableName" -ComparisonGuid $comparisonGuid -DifferenceType $differenceType -ComparisonHash $sourceHash -DefinitionSha256 $definitionSha256 -Purpose $purpose) +
            [string]::Join("`r`n", $lines) + "`r`n" + [string]::Join("`r`n", $seed) + "`r`n"

        $created = Write-CymBuildConstraintGeneratedFile -Path $path -Content $content -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required new-table source file '$path' is unavailable." }

        $result.Succeeded = $true
        $result.WasCreated = [bool]$created
        $result.MaterializedFiles = if ($created) { [string[]]@($path) } else { [string[]]@() }
        $result.DefinitionSha256 = $definitionSha256
        $result.Reason = if ($created) { "New-table create and seed SQL was materialized from the accepted declarative snapshot and selection capture." } else { "Source-controlled new-table create and seed SQL was resolved." }
        return [pscustomobject]$result
    }
    catch {
        $result.Reason = $_.Exception.Message
        return [pscustomobject]$result
    }
}

function New-MaterializedIndexSourceFiles {
    param(
        [System.Data.DataRow]$Row,
        [bool]$AllowCreate = $true,
        [bool]$RequireDefinitionMatch = $false
    )

    $schemaName = Get-DataRowText -Row $Row -ColumnName "SchemaName"
    $tableName = Get-DataRowText -Row $Row -ColumnName "ParentObjectName"
    $differenceType = Get-DataRowText -Row $Row -ColumnName "DifferenceType"
    $comparisonGuid = Get-DataRowText -Row $Row -ColumnName "ComparisonGuid"
    $sourceHash = Get-DataRowText -Row $Row -ColumnName "SourceHash"
    $targetHash = Get-DataRowText -Row $Row -ColumnName "TargetHash"
    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"
    $targetDefinition = Get-DataRowText -Row $Row -ColumnName "TargetDefinition"
    $definition = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { $targetDefinition } else { $sourceDefinition }
    $comparisonHash = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { $targetHash } else { $sourceHash }
    $result = [ordered]@{ Succeeded = $false; WasCreated = $false; ApplyFile = ""; PrepareFile = ""; PreflightFile = ""; MaterializedFiles = @(); DefinitionSha256 = ""; Reason = "" }

    try {
        if ([string]::IsNullOrWhiteSpace($tableName)) { throw "Index row is missing its parent table name." }
        $payload = Get-CymBuildDeclarativePayload -Definition $definition -Prefix "CYB_INDEX_V2|" -ObjectDescription "Index $schemaName.$tableName"
        $indexName = Get-CymBuildPropertyText -InputObject $payload -PropertyName "IndexName"
        if ([string]::IsNullOrWhiteSpace($indexName)) { throw "Index definition is missing IndexName." }
        $indexTypeId = [int](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "IndexTypeId" -Required)
        $indexType = (Get-CymBuildPropertyText -InputObject $payload -PropertyName "IndexType").ToUpperInvariant()
        if ($indexTypeId -notin @(1, 2) -or $indexType -notin @("CLUSTERED", "NONCLUSTERED")) {
            throw "Index '$schemaName.$tableName.$indexName' uses specialist type '$indexType' and requires a dedicated migration."
        }
        $dataSpaceType = Get-CymBuildPropertyText -InputObject $payload -PropertyName "DataSpaceType"
        if (-not [string]::IsNullOrWhiteSpace($dataSpaceType) -and -not $dataSpaceType.Equals("ROWS_FILEGROUP", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Partitioned or specialist data space '$dataSpaceType' requires a dedicated index migration."
        }

        $paths = Get-CymBuildIndexMigrationPaths -SchemaName $schemaName -TableName $tableName -IndexName $indexName
        $tableIdentifier = "$(Quote-CymBuildSqlIdentifier -Value $schemaName).$(Quote-CymBuildSqlIdentifier -Value $tableName)"
        $tableLiteral = Quote-CymBuildSqlStringLiteral -Value $tableIdentifier
        $indexIdentifier = Quote-CymBuildSqlIdentifier -Value $indexName
        $indexNameLiteral = Quote-CymBuildSqlStringLiteral -Value $indexName
        $definitionSha256 = Get-TextSha256 -Text $definition
        $createdFiles = New-Object System.Collections.Generic.List[string]
        $headerArguments = @{
            ObjectDescription = "Index $schemaName.$tableName.$indexName"
            ComparisonGuid = $comparisonGuid
            DifferenceType = $differenceType
            ComparisonHash = $comparisonHash
            DefinitionSha256 = $definitionSha256
        }

        if ($differenceType -in @("Different", "MissingInSource")) {
            $prepareSql = if ($differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) {
@"
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
"@
            }
            else {
@"
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID($tableLiteral, N'U') AND name = $indexNameLiteral)
        DROP INDEX $indexIdentifier ON $tableIdentifier;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@
            }
            $preparePurpose = if ($differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) {
                "Prepare phase: preserve the target index for atomic replacement during finalize."
            }
            else {
                "Prepare phase: remove the selected target index."
            }
            $prepareContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose $preparePurpose) + $prepareSql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PrepareFile -Content $prepareContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) { [void]$createdFiles.Add($paths.PrepareFile) }
            $result.PrepareFile = $paths.PrepareFile
        }

        if (-not $differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) {
            $columns = @((Get-CymBuildObjectProperty -InputObject $payload -PropertyName "Columns" -Required))
            $keyColumns = @($columns | Where-Object { -not (ConvertTo-CymBuildBoolean -Value $_.IsIncluded) -and [int]$_.KeyOrdinal -gt 0 } | Sort-Object { [int]$_.KeyOrdinal })
            $includedColumns = @($columns | Where-Object { ConvertTo-CymBuildBoolean -Value $_.IsIncluded } | Sort-Object { [int]$_.IndexColumnId })
            if ($keyColumns.Count -eq 0) { throw "Index '$indexName' has no key columns." }
            $keySql = @($keyColumns | ForEach-Object { "$(Quote-CymBuildSqlIdentifier -Value ([string]$_.ColumnName))$(if (ConvertTo-CymBuildBoolean -Value $_.IsDescending) { ' DESC' } else { ' ASC' })" }) -join ", "
            $keyGroupSql = @($keyColumns | ForEach-Object { Quote-CymBuildSqlIdentifier -Value ([string]$_.ColumnName) }) -join ", "
            $includeSql = if ($includedColumns.Count -gt 0) { " INCLUDE (" + ((@($includedColumns | ForEach-Object { Quote-CymBuildSqlIdentifier -Value ([string]$_.ColumnName) })) -join ", ") + ")" } else { "" }
            $preflight = New-Object System.Collections.Generic.List[string]
            [void]$preflight.Add("SET NOCOUNT ON;")
            [void]$preflight.Add("IF OBJECT_ID($tableLiteral, N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;")
            foreach ($column in $columns) {
                $columnName = [string]$column.ColumnName
                [void]$preflight.Add("IF COL_LENGTH($tableLiteral, $(Quote-CymBuildSqlStringLiteral -Value $columnName)) IS NULL THROW 51431, 'Index column does not exist.', 1;")
            }

            $dataSpaceName = Get-CymBuildPropertyText -InputObject $payload -PropertyName "DataSpaceName"
            $dataSpaceSql = ""
            if (-not [string]::IsNullOrWhiteSpace($dataSpaceName)) {
                [void]$preflight.Add("IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = $(Quote-CymBuildSqlStringLiteral -Value $dataSpaceName)) THROW 51432, 'Index data space does not exist in the target.', 1;")
                $dataSpaceSql = " ON $(Quote-CymBuildSqlIdentifier -Value $dataSpaceName)"
            }

            $partitions = @((Get-CymBuildObjectProperty -InputObject $payload -PropertyName "Partitions"))
            if ($partitions.Count -gt 1) { throw "Partitioned index '$indexName' requires a dedicated migration." }
            $compression = if ($partitions.Count -eq 1) { ([string]$partitions[0].DataCompression).ToUpperInvariant() } else { "NONE" }
            if ($compression -notin @("NONE", "ROW", "PAGE")) { throw "Index compression '$compression' is unsupported." }

            $options = New-Object System.Collections.Generic.List[string]
            [void]$options.Add("PAD_INDEX = $(if (ConvertTo-CymBuildBoolean -Value $payload.IsPadded) { 'ON' } else { 'OFF' })")
            $fillFactor = [int]$payload.FillFactor
            if ($fillFactor -lt 0 -or $fillFactor -gt 100) { throw "Index fill factor must be between 0 and 100." }
            # SQL Server's CREATE/ALTER INDEX only accepts an explicit FILLFACTOR literal of 1-100;
            # it rejects FILLFACTOR = 0 outright ("Fillfactor 0 is not a valid percentage"). Omitting
            # the option instead is NOT equivalent: it makes the index inherit the target server's
            # configured default fill factor, which is not guaranteed to be 0 (proven on
            # SOC-SQLDEVBRE01\GENERAL, whose server-level default is 80, causing deployed indexes to
            # persist fill_factor = 80 against an accepted source hash captured at 0 and failing
            # post-deployment verification). SQL Server treats an explicit FILLFACTOR = 100 as
            # equivalent to "no reserved free space" and persists it in sys.indexes.fill_factor as 0,
            # the same catalog value a captured 0 represents - so emit 100 explicitly to reproduce
            # the captured source value independent of the target server's default. This mirrors the
            # equivalent PRIMARY KEY/UNIQUE constraint path.
            [void]$options.Add("FILLFACTOR = $(if ($fillFactor -gt 0) { $fillFactor } else { 100 })")
            [void]$options.Add("IGNORE_DUP_KEY = $(if (ConvertTo-CymBuildBoolean -Value $payload.IgnoreDuplicateKey) { 'ON' } else { 'OFF' })")
            [void]$options.Add("ALLOW_ROW_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value $payload.AllowRowLocks) { 'ON' } else { 'OFF' })")
            [void]$options.Add("ALLOW_PAGE_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value $payload.AllowPageLocks) { 'ON' } else { 'OFF' })")
            if ($compression -ne "NONE") { [void]$options.Add("DATA_COMPRESSION = $compression") }
            $isReplacement = $differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)
            if ($isReplacement) { [void]$options.Add("DROP_EXISTING = ON") }
            $optionsSql = " WITH (" + ([string]::Join(", ", $options)) + ")"
            $filterDefinition = Get-CymBuildPropertyText -InputObject $payload -PropertyName "FilterDefinition"
            if (Test-CymBuildForbiddenSqlFragment -Value $filterDefinition) { throw "Index filter contains a forbidden batch or database-context statement." }
            $hasFilter = ConvertTo-CymBuildBoolean -Value $payload.HasFilter
            if ($hasFilter -and [string]::IsNullOrWhiteSpace($filterDefinition)) { throw "Filtered index '$indexName' is missing its filter definition." }
            $filterSql = if ([string]::IsNullOrWhiteSpace($filterDefinition)) { "" } else { " WHERE $filterDefinition" }
            $isUnique = ConvertTo-CymBuildBoolean -Value $payload.IsUnique
            if ($isUnique) {
                [void]$preflight.Add("IF EXISTS (SELECT $keyGroupSql FROM $tableIdentifier$filterSql GROUP BY $keyGroupSql HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;")
            }
            $uniqueSql = if ($isUnique) { "UNIQUE " } else { "" }
            $disableSql = if (ConvertTo-CymBuildBoolean -Value $payload.IsDisabled) { "`r`n    ALTER INDEX $indexIdentifier ON $tableIdentifier DISABLE;" } else { "" }
            $createSql = "CREATE $uniqueSql$indexType INDEX $indexIdentifier ON $tableIdentifier ($keySql)$includeSql$filterSql$optionsSql$dataSpaceSql;"
            $applySql = if ($isReplacement) {
@"
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    $createSql$disableSql
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@
            }
            else {
@"
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID($tableLiteral, N'U') AND name = $indexNameLiteral)
    BEGIN
        $createSql
    END;$disableSql
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@
            }
            $preflightContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Read-only preflight for the selected index operation.") + ([string]::Join("`r`n", $preflight)) + "`r`nGO`r`n"
            $applyContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Finalize phase: create the source index from the declarative snapshot.") + $applySql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) { [void]$createdFiles.Add($paths.PreflightFile) }
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate -RequireDefinitionMatch $RequireDefinitionMatch) { [void]$createdFiles.Add($paths.ApplyFile) }
            $result.PreflightFile = $paths.PreflightFile
            $result.ApplyFile = $paths.ApplyFile
        }

        $requiredFiles = @($result.PrepareFile, $result.PreflightFile, $result.ApplyFile) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        foreach ($requiredFile in $requiredFiles) {
            if (-not (Test-ApprovedSchemaSourcePath -Path $requiredFile) -or -not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Required index convergence source file '$requiredFile' is unavailable." }
        }
        $result.Succeeded = $true
        $result.WasCreated = $createdFiles.Count -gt 0
        $result.MaterializedFiles = [string[]]$createdFiles.ToArray()
        $result.DefinitionSha256 = $definitionSha256
        $result.Reason = if ($result.WasCreated) { "Index SQL was materialized from the accepted declarative snapshot." } else { "Source-controlled index SQL files were resolved." }
        return [pscustomobject]$result
    }
    catch {
        $result.Reason = $_.Exception.Message
        return [pscustomobject]$result
    }
}


function ConvertTo-CymBuildNormalizedSchemaDefinition {
    param(
        [string]$Definition,
        [switch]$IgnoreOperationalSchemaBinding
    )

    if ([string]::IsNullOrWhiteSpace($Definition)) {
        return ""
    }

    # The optional mode is used only for the explicit Function/View lifecycle
    # contract. It removes the executable clause, while the normal comment
    # handling already removes the prepared --WITH SCHEMABINDING marker.
    $builder = New-Object System.Text.StringBuilder $Definition.Length
    $inString = $false
    $inBracketIdentifier = $false
    $inQuotedIdentifier = $false
    $index = 0
    $schemaBindingPattern = if ($IgnoreOperationalSchemaBinding) {
        [regex]::new(
            '\GWITH\s+SCHEMABINDING\b',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    }
    else {
        $null
    }

    while ($index -lt $Definition.Length) {
        $character = $Definition[$index]

        if ($IgnoreOperationalSchemaBinding -and -not $inString) {
            if (-not $inBracketIdentifier -and $character -eq '"') {
                $inQuotedIdentifier = -not $inQuotedIdentifier
            }

            if (-not $inBracketIdentifier -and -not $inQuotedIdentifier -and $character -eq '[') {
                $inBracketIdentifier = $true
                $index++
                continue
            }

            if ($inBracketIdentifier) {
                if ($character -eq ']' -and
                    $index + 1 -lt $Definition.Length -and
                    $Definition[$index + 1] -eq ']') {
                    $index += 2
                    continue
                }
                elseif ($character -eq ']') {
                    $inBracketIdentifier = $false
                }
                elseif (-not [char]::IsWhiteSpace($character)) {
                    [void]$builder.Append([char]::ToUpperInvariant($character))
                }

                $index++
                continue
            }
        }

        if (-not $inString -and
            $character -eq '-' -and
            $index + 1 -lt $Definition.Length -and
            $Definition[$index + 1] -eq '-') {
            $index += 2
            while ($index -lt $Definition.Length -and
                $Definition[$index] -ne "`r" -and
                $Definition[$index] -ne "`n") {
                $index++
            }
            continue
        }

        if (-not $inString -and
            $character -eq '/' -and
            $index + 1 -lt $Definition.Length -and
            $Definition[$index + 1] -eq '*') {
            $index += 2
            while ($index + 1 -lt $Definition.Length -and
                -not ($Definition[$index] -eq '*' -and $Definition[$index + 1] -eq '/')) {
                $index++
            }

            $index = [Math]::Min($index + 2, $Definition.Length)
            continue
        }

        if ($IgnoreOperationalSchemaBinding -and -not $inString -and -not $inQuotedIdentifier) {
            $previousCharacterIsIdentifier = $index -gt 0 -and
                ([char]::IsLetterOrDigit($Definition[$index - 1]) -or
                 $Definition[$index - 1] -in @('_', '@', '#', '$'))
            if (-not $previousCharacterIsIdentifier) {
                $schemaBindingMatch = $schemaBindingPattern.Match($Definition, $index)
                if ($schemaBindingMatch.Success) {
                    $index += $schemaBindingMatch.Length
                    continue
                }
            }
        }

        if ($character -eq "'") {
            [void]$builder.Append($character)
            if ($inString -and
                $index + 1 -lt $Definition.Length -and
                $Definition[$index + 1] -eq "'") {
                [void]$builder.Append($Definition[$index + 1])
                $index += 2
                continue
            }

            $inString = -not $inString
            $index++
            continue
        }

        if ($inString) {
            [void]$builder.Append($character)
            $index++
            continue
        }

        if ([char]::IsWhiteSpace($character) -or $character -eq '[' -or $character -eq ']') {
            $index++
            continue
        }

        [void]$builder.Append([char]::ToUpperInvariant($character))
        $index++
    }

    $normalized = $builder.ToString()
    return [regex]::Replace(
        $normalized,
        '\A(?:CREATEORALTER|ALTER)(FUNCTION|VIEW|PROCEDURE|PROC|TRIGGER)',
        'CREATE$1',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Get-CymBuildProgrammableDefinitionFromFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }

    $content = (Get-Content -LiteralPath $Path -Raw).TrimStart([char]0xFEFF)
    $declaration = [regex]::Match(
        $content,
        '(?im)^\s*CREATE\s+(?:OR\s+ALTER\s+)?(?:FUNCTION|VIEW|PROCEDURE|PROC|TRIGGER)\b')
    if (-not $declaration.Success) {
        return ""
    }

    $definition = $content.Substring($declaration.Index)
    $batchSeparator = [regex]::Match($definition, '(?im)^\s*GO\s*(?:--.*)?$')
    if ($batchSeparator.Success) {
        $definition = $definition.Substring(0, $batchSeparator.Index)
    }

    return $definition.Trim()
}

function Test-CymBuildProgrammableDefinitionIsIdempotent {
    param([string]$Definition)

    return [regex]::IsMatch(
        $Definition,
        '(?im)^\s*CREATE\s+OR\s+ALTER\s+(?:FUNCTION|VIEW|PROCEDURE|PROC|TRIGGER)\b')
}

function Get-CymBuildSchemaDefinitionHash {
    param(
        [string]$Definition,
        [switch]$IgnoreOperationalSchemaBinding
    )

    $normalizedDefinition = ConvertTo-CymBuildNormalizedSchemaDefinition -Definition $Definition `
        -IgnoreOperationalSchemaBinding:$IgnoreOperationalSchemaBinding
    return (Get-TextSha256 -Text $normalizedDefinition)
}

function New-MaterializedSchemaSourceFile {
    param(
        [System.Data.DataRow]$Row,
        [string]$DestinationPath,
        [bool]$AllowWrite = $true,
        [bool]$RequireMatch = $false
    )

    $objectType = Get-DataRowText -Row $Row -ColumnName "ObjectType"
    $schemaName = Get-DataRowText -Row $Row -ColumnName "SchemaName"
    $objectName = Get-DataRowText -Row $Row -ColumnName "ObjectName"
    $differenceType = Get-DataRowText -Row $Row -ColumnName "DifferenceType"
    $comparisonGuid = Get-DataRowText -Row $Row -ColumnName "ComparisonGuid"
    $sourceHash = Get-DataRowText -Row $Row -ColumnName "SourceHash"
    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"

    $result = [ordered]@{
        Succeeded = $false
        WasCreated = $false
        DestinationPath = $DestinationPath
        DefinitionSha256 = ""
        Reason = ""
    }

    if (-not (Test-CanMaterializeProgrammableObject -ObjectType $objectType)) {
        $result.Reason = "Object type '$objectType' is not eligible for automatic source materialization."
        return [pscustomobject]$result
    }

    if ([string]::IsNullOrWhiteSpace($sourceDefinition)) {
        $result.Reason = "The accepted deployment plan does not contain a source definition for $objectType '$schemaName.$objectName'. Re-run Stage & Compare before accepting the plan."
        return [pscustomobject]$result
    }

    if ([regex]::IsMatch($sourceDefinition, '(?im)^\s*GO\s*(?:--.*)?$')) {
        $result.Reason = "The captured source definition for $objectType '$schemaName.$objectName' contains a batch separator and cannot be materialized safely."
        return [pscustomobject]$result
    }

    if ([regex]::IsMatch($sourceDefinition, '(?im)^\s*USE\s+')) {
        $result.Reason = "The captured source definition for $objectType '$schemaName.$objectName' contains a database-context statement and cannot be materialized safely."
        return [pscustomobject]$result
    }

    $headerText = [regex]::Replace($sourceDefinition, '\[([^\]]+)\]', '$1')
    $headerText = [regex]::Replace($headerText, '"([^"]+)"', '$1')
    $headerText = [regex]::Replace($headerText, '\s+', ' ')

    $kindPattern = switch ($objectType) {
        "Function" { "FUNCTION" }
        "View" { "VIEW" }
        "StoredProcedure" { "(?:PROCEDURE|PROC)" }
        "Trigger" { "TRIGGER" }
        default { "" }
    }

    $identityPattern = (
        '(?i)\b(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)' +
        $kindPattern +
        '\s+' +
        [regex]::Escape($schemaName) +
        '\s*\.\s*' +
        [regex]::Escape($objectName) +
        '(?:\s|\(|$)'
    )

    if (-not [regex]::IsMatch($headerText, $identityPattern)) {
        $result.Reason = "The captured source definition does not declare the expected $objectType '$schemaName.$objectName'."
        return [pscustomobject]$result
    }

    if (-not (Test-ApprovedSchemaSourcePath -Path $DestinationPath)) {
        $result.Reason = "The materialized source path is outside Database/CymBuild_DB/Schema."
        return [pscustomobject]$result
    }

    $definitionSha256 = Get-TextSha256 -Text $sourceDefinition
    $normalizedSourceHash = Get-CymBuildSchemaDefinitionHash -Definition $sourceDefinition
    if ([string]::IsNullOrWhiteSpace($sourceHash) -or
        -not $normalizedSourceHash.Equals($sourceHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = "The accepted source definition hash for $objectType '$schemaName.$objectName' is missing or does not match its persisted source definition. Run Stage & Compare again."
        return [pscustomobject]$result
    }

    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        $existingDefinition = Get-CymBuildProgrammableDefinitionFromFile -Path $DestinationPath
        $existingHash = Get-CymBuildSchemaDefinitionHash -Definition $existingDefinition
        if (-not [string]::IsNullOrWhiteSpace($existingDefinition) -and
            $existingHash.Equals($sourceHash, [System.StringComparison]::OrdinalIgnoreCase) -and
            (Test-CymBuildProgrammableDefinitionIsIdempotent -Definition $existingDefinition)) {
            $result.Succeeded = $true
            $result.DefinitionSha256 = $definitionSha256
            $result.Reason = "The canonical source file matches the immutable accepted source definition."
            return [pscustomobject]$result
        }

        if (-not $AllowWrite) {
            $result.Reason = "Canonical source file '$DestinationPath' is stale for selected $objectType '$schemaName.$objectName'. Create and accept a DEV / CymBuild_Dev source run, use -SyncSource, commit the reviewed diff, then run -VerifySource again."
            return [pscustomobject]$result
        }
    }
    elseif (-not $AllowWrite) {
        $result.Reason = "Canonical source file '$DestinationPath' is missing for selected $objectType '$schemaName.$objectName'. Create and accept a DEV / CymBuild_Dev source run, use -SyncSource, commit the reviewed file, then run -VerifySource again."
        return [pscustomobject]$result
    }

    $header = @"
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : $objectType $schemaName.$objectName
    Source schema hash : $sourceHash
    Definition SHA-256 : $definitionSha256

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

"@

    $canonicalSourceDefinition = Convert-SchemaScriptForDeployment `
        -Sql $sourceDefinition `
        -ObjectType $objectType `
        -SchemaName $schemaName `
        -ObjectName $objectName `
        -DifferenceType $differenceType
    if (-not (Test-CymBuildProgrammableDefinitionIsIdempotent -Definition $canonicalSourceDefinition)) {
        $result.Reason = "The selected $objectType '$schemaName.$objectName' could not be normalized to CREATE OR ALTER."
        return [pscustomobject]$result
    }

    $fileContent = $header + $canonicalSourceDefinition.Trim() + "`r`nGO`r`n"
    Write-CymBuildTextFile -Path $DestinationPath -Content $fileContent

    $writtenDefinition = Get-CymBuildProgrammableDefinitionFromFile -Path $DestinationPath
    $writtenHash = Get-CymBuildSchemaDefinitionHash -Definition $writtenDefinition
    if (-not $writtenHash.Equals($sourceHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = "Canonical source verification failed immediately after writing '$DestinationPath'."
        return [pscustomobject]$result
    }

    $result.Succeeded = $true
    $result.WasCreated = $true
    $result.DefinitionSha256 = $definitionSha256
    $result.Reason = if ($RequireMatch) {
        "Canonical source SQL was synchronized to the selected CymBuild_Dev definition."
    }
    else {
        "Canonical source SQL matches the accepted source-definition snapshot."
    }
    return [pscustomobject]$result
}

function Resolve-DeploymentItem {
    param([System.Data.DataRow]$Row)

    $objectType = [string]$Row["ObjectType"]
    $schemaName = [string]$Row["SchemaName"]
    $objectName = [string]$Row["ObjectName"]
    $parentObjectName = [string]$Row["ParentObjectName"]
    $differenceType = [string]$Row["DifferenceType"]
    $sourceHash = if ($Row.Table.Columns.Contains("SourceHash") -and $Row["SourceHash"] -ne [DBNull]::Value) { [string]$Row["SourceHash"] } else { "" }
    $targetHash = if ($Row.Table.Columns.Contains("TargetHash") -and $Row["TargetHash"] -ne [DBNull]::Value) { [string]$Row["TargetHash"] } else { "" }

    $result = [ordered]@{
        ComparisonGuid = [string]$Row["ComparisonGuid"]
        ObjectType = $objectType
        SchemaName = $schemaName
        ObjectName = $objectName
        ParentObjectName = $parentObjectName
        DifferenceType = $differenceType
        SourceHash = $sourceHash
        TargetHash = $targetHash
        SupportsOperationalSchemaBindingLifecycle = ($objectType.Equals("Function", [System.StringComparison]::OrdinalIgnoreCase) -or $objectType.Equals("View", [System.StringComparison]::OrdinalIgnoreCase))
        OperationalSourceHash = ""
        OperationalTargetHash = ""
        SourceFile = ""
        PrepareFile = ""
        PreflightFile = ""
        SupportFiles = @()
        DeploymentMode = ""
        IsSupported = $false
        WasMaterialized = $false
        MaterializedDefinitionSha256 = ""
        MaterializedFiles = @()
        ConstraintKind = ""
        Reason = ""
    }

    # Repository writes are an explicit DEV-source synchronization action only.
    # WhatIf, Apply and VerifySource all fail closed when a selected artefact is
    # missing or stale relative to the immutable accepted SourceHash.
    $sourceWriteAllowed = [bool]$SyncSource
    $sourceMatchRequired = $true

    $sourceDefinition = Get-DataRowText -Row $Row -ColumnName "SourceDefinition"
    $targetDefinition = Get-DataRowText -Row $Row -ColumnName "TargetDefinition"
    if ($result.SupportsOperationalSchemaBindingLifecycle) {
        if (-not [string]::IsNullOrWhiteSpace($sourceDefinition)) {
            $result.OperationalSourceHash = Get-CymBuildSchemaDefinitionHash `
                -Definition $sourceDefinition `
                -IgnoreOperationalSchemaBinding
        }
        if (-not [string]::IsNullOrWhiteSpace($targetDefinition)) {
            $result.OperationalTargetHash = Get-CymBuildSchemaDefinitionHash `
                -Definition $targetDefinition `
                -IgnoreOperationalSchemaBinding
        }
    }
    $definitionChecks = New-Object System.Collections.Generic.List[object]
    if (-not [string]::IsNullOrWhiteSpace($sourceDefinition)) {
        [void]$definitionChecks.Add([pscustomobject]@{
            Label = "source"
            Definition = $sourceDefinition
            ExpectedHash = $sourceHash
        })
    }
    if (($differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase) -or
         $differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) -and
        -not [string]::IsNullOrWhiteSpace($targetDefinition)) {
        [void]$definitionChecks.Add([pscustomobject]@{
            Label = "target"
            Definition = $targetDefinition
            ExpectedHash = $targetHash
        })
    }

    foreach ($definitionCheck in $definitionChecks) {
        $actualHash = Get-CymBuildSchemaDefinitionHash -Definition ([string]$definitionCheck.Definition)
        $expectedHash = [string]$definitionCheck.ExpectedHash
        if ([string]::IsNullOrWhiteSpace($expectedHash) -or
            -not $actualHash.Equals($expectedHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result.Reason = "The persisted $($definitionCheck.Label) definition hash for $objectType '$schemaName.$objectName' is missing or invalid. Run Stage & Compare and accept the refreshed selection before source sync or deployment."
            return [pscustomobject]$result
        }
    }

    $dedicatedMigration = Get-DedicatedMigrationDescriptor -ObjectType $objectType -SchemaName $schemaName -ObjectName $objectName -DifferenceType $differenceType
    if ($null -ne $dedicatedMigration) {
        if (-not [string]::IsNullOrWhiteSpace([string]$dedicatedMigration.ExpectedSourceHash) -and
            -not $sourceHash.Equals([string]$dedicatedMigration.ExpectedSourceHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result.Reason = "A dedicated migration exists for $objectType '$schemaName.$objectName', but its approved source hash does not match the current comparison. Re-stage and review the source-controlled migration."
            return [pscustomobject]$result
        }

        $sourceFile = [System.IO.Path]::GetFullPath([string]$dedicatedMigration.SourceFile)
        $preflightFile = [System.IO.Path]::GetFullPath([string]$dedicatedMigration.PreflightFile)
        $supportFileList = New-Object System.Collections.Generic.List[string]

        if ($dedicatedMigration.PSObject.Properties.Name -contains "SupportFiles") {
            foreach ($supportFileValue in $dedicatedMigration.SupportFiles) {
                if ([string]::IsNullOrWhiteSpace([string]$supportFileValue)) {
                    continue
                }

                [void]$supportFileList.Add([System.IO.Path]::GetFullPath([string]$supportFileValue))
            }
        }

        if (-not (Test-ApprovedSchemaSourcePath -Path $sourceFile) -or
            -not (Test-ApprovedSchemaSourcePath -Path $preflightFile)) {
            $result.Reason = "Dedicated migration paths must remain under Database/CymBuild_DB/Schema."
            return [pscustomobject]$result
        }

        foreach ($supportFile in $supportFileList) {
            if (-not (Test-ApprovedSchemaSourcePath -Path $supportFile)) {
                $result.Reason = "Dedicated migration support paths must remain under Database/CymBuild_DB/Schema."
                return [pscustomobject]$result
            }
        }

        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            $result.Reason = "Dedicated source-controlled migration file not found for $objectType '$schemaName.$objectName'."
            return [pscustomobject]$result
        }

        if (-not (Test-Path -LiteralPath $preflightFile -PathType Leaf)) {
            $result.Reason = "Dedicated source-controlled preflight file not found for $objectType '$schemaName.$objectName'."
            return [pscustomobject]$result
        }

        foreach ($supportFile in $supportFileList) {
            if (-not (Test-Path -LiteralPath $supportFile -PathType Leaf)) {
                $result.Reason = "Dedicated source-controlled support file not found for $objectType '$schemaName.$objectName'."
                return [pscustomobject]$result
            }
        }

        $result.SourceFile = $sourceFile
        $result.PreflightFile = $preflightFile
        $result.SupportFiles = [string[]]$supportFileList.ToArray()
        $result.DeploymentMode = [string]$dedicatedMigration.DeploymentMode
        $result.IsSupported = $true
        $result.Reason = [string]$dedicatedMigration.Description
        return [pscustomobject]$result
    }

    if ($objectType.Equals("Constraint", [System.StringComparison]::OrdinalIgnoreCase)) {
        # A system-named key constraint can only be recreated under an explicit copy of the
        # source's generated name (is_system_named = 0), which never passes post-deployment
        # verification, and a target-only one may just be the source's constraint under a
        # different generated name. Validation fails these; refuse them here too.
        if ((Test-CymBuildSystemNamedKeyConstraintDefinition -Definition $sourceDefinition) -or
            (Test-CymBuildSystemNamedKeyConstraintDefinition -Definition $targetDefinition)) {
            $result.Reason = "System-named key constraint '$schemaName.$parentObjectName.$objectName' cannot be deployed faithfully because its name is generated per database. Give it an explicit name in source (or remove the duplicate at source), then run Stage & Compare again, or deselect the row."
            return [pscustomobject]$result
        }

        $constraintMaterialization = New-MaterializedConstraintSourceFiles -Row $Row -AllowCreate $sourceWriteAllowed -RequireDefinitionMatch $sourceMatchRequired
        if (-not $constraintMaterialization.Succeeded) {
            $result.Reason = $constraintMaterialization.Reason
            return [pscustomobject]$result
        }

        $result.SourceFile = [string]$constraintMaterialization.ApplyFile
        $result.PrepareFile = [string]$constraintMaterialization.PrepareFile
        $result.PreflightFile = [string]$constraintMaterialization.PreflightFile
        $result.DeploymentMode = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { "ConstraintRemove" } elseif ($differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) { "ConstraintReplace" } else { "ConstraintCreate" }
        $result.IsSupported = $true
        $result.WasMaterialized = [bool]$constraintMaterialization.WasCreated
        $result.MaterializedDefinitionSha256 = [string]$constraintMaterialization.DefinitionSha256
        $result.MaterializedFiles = [string[]]$constraintMaterialization.MaterializedFiles
        $result.ConstraintKind = [string]$constraintMaterialization.ConstraintKind
        $result.Reason = [string]$constraintMaterialization.Reason
        return [pscustomobject]$result
    }

    if ($objectType.Equals("Index", [System.StringComparison]::OrdinalIgnoreCase)) {
        $indexMaterialization = New-MaterializedIndexSourceFiles -Row $Row -AllowCreate $sourceWriteAllowed -RequireDefinitionMatch $sourceMatchRequired
        if (-not $indexMaterialization.Succeeded) {
            $result.Reason = $indexMaterialization.Reason
            return [pscustomobject]$result
        }

        $result.SourceFile = [string]$indexMaterialization.ApplyFile
        $result.PrepareFile = [string]$indexMaterialization.PrepareFile
        $result.PreflightFile = [string]$indexMaterialization.PreflightFile
        $result.DeploymentMode = if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) { "IndexRemove" } elseif ($differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) { "IndexReplace" } else { "IndexCreate" }
        $result.IsSupported = $true
        $result.WasMaterialized = [bool]$indexMaterialization.WasCreated
        $result.MaterializedDefinitionSha256 = [string]$indexMaterialization.DefinitionSha256
        $result.MaterializedFiles = [string[]]$indexMaterialization.MaterializedFiles
        $result.Reason = [string]$indexMaterialization.Reason
        return [pscustomobject]$result
    }

    if ($objectType.Equals("Table", [System.StringComparison]::OrdinalIgnoreCase) -and
        $differenceType.Equals("Different", [System.StringComparison]::OrdinalIgnoreCase)) {
        $tableMaterialization = New-MaterializedTableSourceFiles -Row $Row -AllowCreate $sourceWriteAllowed -RequireDefinitionMatch $sourceMatchRequired
        if (-not $tableMaterialization.Succeeded) {
            $result.Reason = $tableMaterialization.Reason
            return [pscustomobject]$result
        }

        $result.SourceFile = [string]$tableMaterialization.ApplyFile
        $result.PreflightFile = [string]$tableMaterialization.PreflightFile
        $result.DeploymentMode = "DeclarativeTableAlter"
        $result.IsSupported = $true
        $result.WasMaterialized = [bool]$tableMaterialization.WasCreated
        $result.MaterializedDefinitionSha256 = [string]$tableMaterialization.DefinitionSha256
        $result.MaterializedFiles = [string[]]$tableMaterialization.MaterializedFiles
        $result.Reason = [string]$tableMaterialization.Reason
        return [pscustomobject]$result
    }

    if ($objectType.Equals("Table", [System.StringComparison]::OrdinalIgnoreCase) -and
        $differenceType.Equals("MissingInTarget", [System.StringComparison]::OrdinalIgnoreCase)) {
        # CYB-566: a brand-new table is generated (CREATE + -1 row + optional reference data)
        # rather than refused. A hand-written canonical create file, if present, is used as before.
        $newTableMaterialization = New-MaterializedNewTableSourceFile -Row $Row -AllowCreate $sourceWriteAllowed -RequireDefinitionMatch $sourceMatchRequired
        if (-not $newTableMaterialization.Succeeded) {
            $result.Reason = $newTableMaterialization.Reason
            return [pscustomobject]$result
        }

        if (-not $newTableMaterialization.UseExistingFile) {
            $result.SourceFile = [string]$newTableMaterialization.SourceFile
            $result.DeploymentMode = "CanonicalCreate"
            $result.IsSupported = $true
            $result.WasMaterialized = [bool]$newTableMaterialization.WasCreated
            $result.MaterializedDefinitionSha256 = [string]$newTableMaterialization.DefinitionSha256
            $result.MaterializedFiles = [string[]]$newTableMaterialization.MaterializedFiles
            $result.Reason = [string]$newTableMaterialization.Reason
            return [pscustomobject]$result
        }
    }

    if ($differenceType.Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = "$objectType '$schemaName.$objectName' is absent from CymBuild_Dev. Source sync never deletes or reuses an old canonical create script; add an explicitly reviewed source-controlled removal migration."
        return [pscustomobject]$result
    }

    if ($objectType -in @("TableType", "Sequence") -and $differenceType -ne "MissingInTarget") {
        $result.Reason = "$objectType '$schemaName.$objectName' exists in the target but differs. A dedicated source-controlled migration is required for this specialist object."
        return [pscustomobject]$result
    }

    $sourceFile = Get-SourceSqlFile -ObjectType $objectType -SchemaName $schemaName -ObjectName $objectName -ParentObjectName $parentObjectName
    if ([string]::IsNullOrWhiteSpace($sourceFile)) {
        $result.Reason = "No source-controlled SQL mapping exists for object type '$objectType'."
        return [pscustomobject]$result
    }

    $sourceFile = [System.IO.Path]::GetFullPath($sourceFile)
    if (-not (Test-ApprovedSchemaSourcePath -Path $sourceFile)) {
        $result.Reason = "Resolved source path is outside Database/CymBuild_DB/Schema."
        return [pscustomobject]$result
    }

    $result.SourceFile = $sourceFile

    $isProgrammableObject = Test-CanMaterializeProgrammableObject -ObjectType $objectType
    $shouldEvaluateProgrammableSource = $isProgrammableObject
    if ($shouldEvaluateProgrammableSource) {
        if ($sourceWriteAllowed -or $sourceMatchRequired) {
            $materialization = New-MaterializedSchemaSourceFile `
                -Row $Row `
                -DestinationPath $sourceFile `
                -AllowWrite $sourceWriteAllowed `
                -RequireMatch $sourceMatchRequired
            if (-not $materialization.Succeeded) {
                $result.Reason = $materialization.Reason
                return [pscustomobject]$result
            }

            $result.WasMaterialized = [bool]$materialization.WasCreated
            $result.MaterializedDefinitionSha256 = [string]$materialization.DefinitionSha256
        }
    }

    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        $result.Reason = "Source-controlled SQL file not found for $objectType '$schemaName.$objectName'."
        return [pscustomobject]$result
    }

    $result.DeploymentMode = if ($objectType -in @("Table", "TableType", "Sequence")) { "CanonicalCreate" } elseif ($result.WasMaterialized) { "MaterializedCanonicalAlter" } else { "CanonicalAlter" }
    $result.IsSupported = $true
    $result.Reason = if ($result.WasMaterialized) { "Source definition materialized to canonical source-controlled SQL path." } else { "Source-controlled SQL file resolved." }
    return [pscustomobject]$result
}

function Get-RunAndPlan {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    $runTable = Invoke-SqlQuery -Connection $Connection -Sql @"
SELECT TOP (1)
    sr.Guid,
    sr.RunStatus,
    sr.IsReviewed,
    sr.SourceEnvironment,
    sr.TargetEnvironment,
    sr.SourceServerName,
    sr.SourceDatabaseName,
    sr.TargetServerName,
    sr.TargetDatabaseName,
    sr.ReleaseReference,
    sr.DeploymentReference,
    sr.CreatedOnUtc,
    sr.ReviewedOnUtc,
    sr.SummaryJson,
    sr.RowStatus,
    sr.ComparedOnUtc,
    sr.SourceSyncedOnUtc,
    sr.SourceSyncCommit
FROM [SMigration].[Schema_Run] AS sr
WHERE sr.Guid = @RunGuid
  AND sr.RowStatus <> 0
  AND sr.RowStatus <> 254;
"@ -Parameters @{ "@RunGuid" = $RunGuid }

    if ($runTable.Rows.Count -ne 1) {
        throw "Schema migration run $RunGuid was not found in $TargetDatabase."
    }

    $planTable = Invoke-SqlQuery -Connection $Connection -Sql @"
EXEC [SMigration].[SchemaDeploymentPlan_Get]
    @RunGuid = @RunGuid;
"@ -Parameters @{ "@RunGuid" = $RunGuid } -TimeoutSeconds 600

    return [pscustomobject]@{
        RunRow = $runTable.Rows[0]
        PlanTable = $planTable
    }
}

function Test-LiveTargetName {
    param(
        [string]$EnvironmentName,
        [string]$ServerName,
        [string]$DatabaseName
    )

    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and
        $EnvironmentName.Trim().Equals("LIVE", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

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

function Test-DevTarget {
    param(
        [System.Data.DataRow]$RunRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    $targetEnvironment = ([string]$RunRow["TargetEnvironment"]).Trim()
    $runTargetDatabase = ([string]$RunRow["TargetDatabaseName"]).Trim()
    $actualDatabase = $Connection.Database

    $actualIsDev = $actualDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase) -or
        $actualDatabase.Equals("Concursus_Dev", [System.StringComparison]::OrdinalIgnoreCase) -or
        $actualDatabase -match '(?i)(^|[_\-])dev([_\-]|$)'

    $runDatabaseIsDev = $runTargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase) -or
        $runTargetDatabase.Equals("Concursus_Dev", [System.StringComparison]::OrdinalIgnoreCase) -or
        $runTargetDatabase -match '(?i)(^|[_\-])dev([_\-]|$)'

    return $actualIsDev -and
        ($runDatabaseIsDev -or $targetEnvironment.Equals("DEV", [System.StringComparison]::OrdinalIgnoreCase))
}

function Assert-RunCanDeploy {
    param(
        [System.Data.DataRow]$RunRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    $runTargetDatabase = ([string]$RunRow["TargetDatabaseName"]).Trim()
    $runTargetServer = ([string]$RunRow["TargetServerName"]).Trim()
    $actualTargetDatabase = $Connection.Database
    $actualTargetServer = $Connection.DataSource

    if (-not $IgnoreTargetMismatch) {
        if (-not $runTargetDatabase.Equals($TargetDatabase, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Run target database '$runTargetDatabase' does not match requested target database '$TargetDatabase'. Use -IgnoreTargetMismatch only when deliberately using an equivalent alias."
        }

        if (-not $actualTargetDatabase.Equals($TargetDatabase, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "The SQL connection opened database '$actualTargetDatabase', which does not match requested target database '$TargetDatabase'."
        }

        if (-not [string]::IsNullOrWhiteSpace($actualTargetServer) -and
            -not $actualTargetServer.Equals($TargetServer, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "The SQL connection opened server '$actualTargetServer', which does not match requested target server '$TargetServer'. Use -IgnoreTargetMismatch only for an approved equivalent alias."
        }

        if (-not [string]::IsNullOrWhiteSpace($runTargetServer) -and
            -not $runTargetServer.Equals($TargetServer, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Run target server '$runTargetServer' does not match requested target server '$TargetServer'. Use -IgnoreTargetMismatch only when deliberately using an equivalent alias."
        }
    }

    $runStatus = ([string]$RunRow["RunStatus"]).Trim()
    $isReviewedRun = $runStatus.Equals("Reviewed", [System.StringComparison]::OrdinalIgnoreCase)
    $isApprovedFailedRetry = $RetryFailedDeployment -and
        $runStatus.Equals("DeploymentFailed", [System.StringComparison]::OrdinalIgnoreCase)

    # -SyncSource and -VerifySource never preflight or write the target database; they only
    # materialize the explicitly selected plan rows (enforced separately, below) into repository
    # source files for review. Requiring formal Reviewed acceptance before that review artefact
    # can even be generated is backwards, so those two modes are exempt from this gate. -Apply and
    # -WhatIf still require the same accepted deployable state as before.
    if (-not $SkipAcceptanceCheck -and
        -not $SyncSource -and
        -not $VerifySource -and
        (-not [bool]$RunRow["IsReviewed"] -or
         (-not $isReviewedRun -and -not $isApprovedFailedRetry))) {
        throw "Run $RunGuid is not in an accepted deployable state. Validate and accept the current plan in CymBuild, or use -RetryFailedDeployment only to resume an unchanged reviewed run whose status is DeploymentFailed."
    }

    if ($SkipAcceptanceCheck -and $Apply -and -not (Test-DevTarget -RunRow $RunRow -Connection $Connection)) {
        throw "-SkipAcceptanceCheck is restricted to DEV apply diagnostics."
    }

    if ($WhatIf -or $Apply) {
        $comparedOnUtcValue = $RunRow["ComparedOnUtc"]
        if ($null -eq $comparedOnUtcValue -or $comparedOnUtcValue -eq [DBNull]::Value) {
            throw "Run $RunGuid has never been compared. Compare, Validate and Accept the plan for this run in CymBuild, then retry -WhatIf/-Apply."
        }

        $comparedOnUtc = [datetime]$comparedOnUtcValue
        $comparisonAgeMinutes = ([datetime]::UtcNow - $comparedOnUtc).TotalMinutes
        if ($comparisonAgeMinutes -gt 30) {
            throw "Run $RunGuid was last compared $([math]::Round($comparisonAgeMinutes, 1)) minute(s) ago (ComparedOnUtc = $($comparedOnUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z), which exceeds the 30-minute staleness limit for -WhatIf/-Apply. Redo Compare, Validate and Accept for this run in CymBuild, then retry."
        }
    }

    $isLiveTarget =
        (Test-LiveTargetName -EnvironmentName ([string]$RunRow["TargetEnvironment"]) -ServerName $runTargetServer -DatabaseName $runTargetDatabase) -or
        (Test-LiveTargetName -EnvironmentName "" -ServerName $TargetServer -DatabaseName $TargetDatabase) -or
        (Test-LiveTargetName -EnvironmentName "" -ServerName $actualTargetServer -DatabaseName $actualTargetDatabase)

    if ($Apply -and $isLiveTarget -and -not $AllowLive) {
        throw "Target appears to be LIVE/production. Re-run with -AllowLive only under the approved LIVE release procedure."
    }
}

function Assert-RunCanSynchronizeSource {
    param([System.Data.DataRow]$RunRow)

    $sourceEnvironment = ([string]$RunRow["SourceEnvironment"]).Trim()
    $sourceDatabase = ([string]$RunRow["SourceDatabaseName"]).Trim()

    $isAcceptedDevSource = $sourceEnvironment.Equals("DEV", [System.StringComparison]::OrdinalIgnoreCase) -and
        $sourceDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)

    if (-not $isAcceptedDevSource) {
        if (-not $AllowNonDevSource) {
            throw "Schema source synchronization is restricted to an accepted run whose source is exactly DEV / CymBuild_Dev. This run records '$sourceEnvironment / $sourceDatabase'. Re-run with -AllowNonDevSource only for a deliberate, reviewed cross-environment reconciliation."
        }

        Write-Warning "Schema source synchronization source override in effect (-AllowNonDevSource): run $RunGuid records source '$sourceEnvironment / $sourceDatabase', not DEV / CymBuild_Dev. Review the generated Database\CymBuild_DB diff especially carefully before committing."
    }
}

function Assert-RunUsesR7C4SnapshotContract {
    param([System.Data.DataRow]$RunRow)

    $summaryJson = [string]$RunRow["SummaryJson"]
    try {
        $summary = $summaryJson | ConvertFrom-Json
        $snapshotContract = [string](Get-CymBuildObjectProperty -InputObject $summary -PropertyName "SchemaSnapshotContract")
    }
    catch {
        throw "Run $RunGuid has invalid Schema comparison summary JSON. Create, compare, select, validate and accept a fresh DEV-to-target run after installing R7C4."
    }

    if (-not $snapshotContract.Equals("R7C4", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Run $RunGuid was not compared with the R7C4 Schema snapshot contract. Earlier accepted runs cannot be reused; create, compare, select, validate and accept a fresh run."
    }
}

function Get-CymBuildFileSha256 {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($stream)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

function Get-CymBuildGitExecutable {
    if (-not [string]::IsNullOrWhiteSpace($env:CYMBUILD_GIT_EXE)) {
        $configuredGit = $env:CYMBUILD_GIT_EXE.Trim()
        if (-not (Test-Path -LiteralPath $configuredGit -PathType Leaf)) {
            throw "CYMBUILD_GIT_EXE points to a missing Git executable: '$configuredGit'."
        }

        return (Resolve-Path -LiteralPath $configuredGit).Path
    }

    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $gitCommand) {
        throw "Git is required to prove that selected schema artefacts are tracked and unchanged at repository HEAD. Install Git or set CYMBUILD_GIT_EXE to the approved executable."
    }

    return [string]$gitCommand.Source
}

function Invoke-CymBuildGitCommand {
    param(
        [string]$GitExecutable,
        [string[]]$Arguments
    )

    $output = @(& $GitExecutable @Arguments 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = [string[]]$output
    }
}

function Get-CymBuildSelectedSourceFiles {
    param([object[]]$SupportedItems)

    $uniquePaths = @{}
    foreach ($item in $SupportedItems) {
        foreach ($candidatePath in @($item.SourceFile, $item.PrepareFile, $item.PreflightFile) + @($item.SupportFiles)) {
            if ([string]::IsNullOrWhiteSpace([string]$candidatePath)) {
                continue
            }

            $fullPath = [System.IO.Path]::GetFullPath([string]$candidatePath)
            if (-not (Test-ApprovedSchemaSourcePath -Path $fullPath)) {
                throw "Selected schema artefact resolved outside Database/CymBuild_DB/Schema: '$fullPath'."
            }

            $uniquePaths[$fullPath.ToUpperInvariant()] = $fullPath
        }
    }

    return @($uniquePaths.Values | Sort-Object)
}

function Assert-CymBuildSelectedSourceControlState {
    param(
        [object[]]$SupportedItems,
        [string]$ExpectedFingerprint = ""
    )

    $gitExecutable = Get-CymBuildGitExecutable
    $topLevelResult = Invoke-CymBuildGitCommand -GitExecutable $gitExecutable -Arguments @(
        "-C", $RepoRoot, "rev-parse", "--show-toplevel"
    )
    if ($topLevelResult.ExitCode -ne 0 -or $topLevelResult.Output.Count -eq 0) {
        throw "The schema runner must execute from a valid Git worktree so selected source provenance can be verified."
    }

    $gitTopLevel = [System.IO.Path]::GetFullPath($topLevelResult.Output[-1].Trim())
    if (-not $gitTopLevel.TrimEnd([char[]]@('\', '/')).Equals(
        $RepoRoot.TrimEnd([char[]]@('\', '/')),
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "RepoRoot '$RepoRoot' is not the Git worktree root '$gitTopLevel'."
    }

    $commitResult = Invoke-CymBuildGitCommand -GitExecutable $gitExecutable -Arguments @(
        "-C", $RepoRoot, "rev-parse", "HEAD"
    )
    if ($commitResult.ExitCode -ne 0 -or $commitResult.Output.Count -ne 1) {
        throw "The current source commit could not be resolved."
    }
    $commit = $commitResult.Output[0].Trim()

    $failures = New-Object System.Collections.Generic.List[object]
    $fingerprintLines = New-Object System.Collections.Generic.List[string]
    foreach ($path in @(Get-CymBuildSelectedSourceFiles -SupportedItems $SupportedItems)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            [void]$failures.Add([pscustomobject]@{
                RelativePath = $path
                GitStatus = "Missing"
                Message = "The selected schema artefact is missing."
            })
            continue
        }

        $relativePath = $path.Substring($RepoRoot.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
        $trackedResult = Invoke-CymBuildGitCommand -GitExecutable $gitExecutable -Arguments @(
            "-C", $RepoRoot, "ls-files", "--error-unmatch", "--", $relativePath
        )
        if ($trackedResult.ExitCode -ne 0) {
            [void]$failures.Add([pscustomobject]@{
                RelativePath = $relativePath
                GitStatus = "Untracked"
                Message = "The selected schema artefact is not tracked at repository HEAD."
            })
            continue
        }

        $statusResult = Invoke-CymBuildGitCommand -GitExecutable $gitExecutable -Arguments @(
            "-C", $RepoRoot, "status", "--porcelain=v1", "--untracked-files=all", "--", $relativePath
        )
        if ($statusResult.ExitCode -ne 0) {
            throw "Git status failed while verifying selected schema artefact '$relativePath'."
        }
        if ($statusResult.Output.Count -gt 0) {
            [void]$failures.Add([pscustomobject]@{
                RelativePath = $relativePath
                GitStatus = [string]::Join(" | ", $statusResult.Output)
                Message = "The selected schema artefact is modified, staged or otherwise differs from repository HEAD."
            })
            continue
        }

        [void]$fingerprintLines.Add("$relativePath|$(Get-CymBuildFileSha256 -Path $path)")
    }

    if ($failures.Count -gt 0) {
        $failurePath = Join-Path $OutputDirectory "selected-source-control-failures.csv"
        Write-CymBuildTextFile -Path $failurePath -Content (ConvertTo-CymBuildCsvText -Rows $failures.ToArray())
        throw "Selected schema source is not fully tracked and unchanged at repository HEAD. No target preflight or schema lifecycle SQL was run. Commit the reviewed source artefacts, then run -VerifySource and -WhatIf again. Evidence: $failurePath"
    }

    $fingerprint = Get-TextSha256 -Text ([string]::Join("`n", @($fingerprintLines | Sort-Object)))
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFingerprint) -and
        -not $fingerprint.Equals($ExpectedFingerprint, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Selected schema source changed after the deployment plan was resolved. No target pre-deployment script or selected DDL was run. Re-run -VerifySource and -WhatIf from the unchanged reviewed commit."
    }

    $script:sourceCommit = $commit
    $script:selectedSourceFingerprint = $fingerprint
    return [pscustomobject]@{
        Commit = $commit
        Fingerprint = $fingerprint
        FileCount = $fingerprintLines.Count
    }
}

function Write-SourceSyncManifest {
    param(
        [System.Data.DataRow]$RunRow,
        [object[]]$ResolvedItems
    )

    $artifactRows = New-Object System.Collections.Generic.List[object]
    foreach ($item in $ResolvedItems) {
        $paths = New-Object System.Collections.Generic.List[string]
        foreach ($candidatePath in @($item.SourceFile, $item.PrepareFile, $item.PreflightFile)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$candidatePath) -and
                -not $paths.Contains([string]$candidatePath)) {
                [void]$paths.Add([string]$candidatePath)
            }
        }
        foreach ($supportPath in @($item.SupportFiles)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$supportPath) -and
                -not $paths.Contains([string]$supportPath)) {
                [void]$paths.Add([string]$supportPath)
            }
        }

        foreach ($path in $paths) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                continue
            }

            $relativePath = $path.Substring($RepoRoot.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
            [void]$artifactRows.Add([pscustomobject]@{
                ComparisonGuid = [string]$item.ComparisonGuid
                ObjectType = [string]$item.ObjectType
                SchemaName = [string]$item.SchemaName
                ObjectName = [string]$item.ObjectName
                ParentObjectName = [string]$item.ParentObjectName
                DifferenceType = [string]$item.DifferenceType
                SourceHash = [string]$item.SourceHash
                RelativePath = $relativePath
                FileSha256 = Get-CymBuildFileSha256 -Path $path
                WasSynchronized = [bool]$item.WasMaterialized
            })
        }
    }

    [object[]]$orderedArtifacts = $artifactRows.ToArray()
    $manifest = [ordered]@{
        Contract = "CYB_SCHEMA_SOURCE_SYNC_V1"
        SchemaSnapshotContract = "R7C4"
        RunGuid = $RunGuid.ToString()
        SourceEnvironment = [string]$RunRow["SourceEnvironment"]
        SourceServerName = [string]$RunRow["SourceServerName"]
        SourceDatabaseName = [string]$RunRow["SourceDatabaseName"]
        PlanDatabase = $TargetDatabase
        Mode = if ($SyncSource) { "SyncSource" } else { "VerifySource" }
        NonDevSourceOverrideApplied = [bool]$AllowNonDevSource
        SelectedObjectCount = $ResolvedItems.Count
        ArtifactCount = $orderedArtifacts.Count
        GeneratedOnUtc = [DateTime]::UtcNow.ToString("O")
        Artifacts = $orderedArtifacts
    }

    $manifestPath = Join-Path $OutputDirectory "source-sync-manifest.json"
    Write-CymBuildTextFile -Path $manifestPath -Content (($manifest | ConvertTo-Json -Depth 8) + "`r`n")
    return $manifestPath
}

function Write-PlanOutputs {
    param(
        [System.Data.DataRow]$RunRow,
        [System.Data.DataTable]$PlanTable,
        [object[]]$ResolvedItems,
        [object[]]$UnsupportedItems
    )

    $planCsv = Join-Path $OutputDirectory "deployment-plan.csv"
    $resolvedCsv = Join-Path $OutputDirectory "resolved-items.csv"
    $unsupportedCsv = Join-Path $OutputDirectory "unsupported-items.csv"
    $materializedCsv = Join-Path $OutputDirectory "materialized-source-items.csv"
    $summaryJson = Join-Path $OutputDirectory "summary.json"

    $planRows = foreach ($row in $PlanTable.Rows) {
        [pscustomobject]@{
            ComparisonGuid = [string]$row["ComparisonGuid"]
            ObjectType = [string]$row["ObjectType"]
            SchemaName = [string]$row["SchemaName"]
            ObjectName = [string]$row["ObjectName"]
            ParentObjectName = [string]$row["ParentObjectName"]
            DifferenceType = [string]$row["DifferenceType"]
            IsDeployable = [bool]$row["IsDeployable"]
            IsDestructiveRisk = [bool]$row["IsDestructiveRisk"]
            IsSelected = [bool]$row["IsSelected"]
            HasExplicitSelection = [bool]$row["HasExplicitSelection"]
        }
    }

    [object[]]$planRowArray = @($planRows)
    [object[]]$materializedItems = @($ResolvedItems | Where-Object { $_.WasMaterialized })

    Write-CymBuildTextFile -Path $planCsv -Content (ConvertTo-CymBuildCsvText -Rows $planRowArray)
    Write-CymBuildTextFile -Path $resolvedCsv -Content (ConvertTo-CymBuildCsvText -Rows $ResolvedItems)
    Write-CymBuildTextFile -Path $unsupportedCsv -Content (ConvertTo-CymBuildCsvText -Rows $UnsupportedItems)
    Write-CymBuildTextFile -Path $materializedCsv -Content (ConvertTo-CymBuildCsvText -Rows $materializedItems)

    $supportedCount = @($ResolvedItems | Where-Object { $_.IsSupported }).Count

    $summary = [ordered]@{
        SchemaSnapshotContract = "R7C4"
        RunGuid = $RunGuid.ToString()
        TargetServer = $TargetServer
        TargetDatabase = $TargetDatabase
        ReleaseReference = $ReleaseReference
        DeploymentReference = $DeploymentReference
        IsApply = [bool]$Apply
        IsWhatIf = [bool]$WhatIf
        IsSourceSync = [bool]$SyncSource
        IsSourceVerify = [bool]$VerifySource
        PlanCount = $PlanTable.Rows.Count
        SupportedCount = $supportedCount
        UnsupportedCount = $UnsupportedItems.Count
        MaterializedSourceCount = $materializedItems.Count
        RetryFailedDeployment = [bool]$RetryFailedDeployment
        SourceCommit = $script:sourceCommit
        SelectedSourceFingerprint = $script:selectedSourceFingerprint
        GeneratedOnUtc = [DateTime]::UtcNow.ToString("O")
        ExecutionId = $executionId
        ExecutionMode = $executionMode
        RunOutputRoot = $runOutputRoot
        OutputDirectory = $OutputDirectory
    }

    $summaryText = $summary | ConvertTo-Json -Depth 12
    Write-CymBuildTextFile -Path $summaryJson -Content ($summaryText + "`r`n")
}

function Get-CymBuildApplyItemRank {
    param([object]$Item)

    if ($Item.ObjectType -eq "Constraint") {
        switch ($Item.ConstraintKind) {
            "PRIMARY_KEY" { return 1000 }
            "UNIQUE" { return 1000 }
            "DEFAULT" { return 1010 }
            "CHECK" { return 1020 }
            "FOREIGN_KEY" { return 1030 }
            default { return 1090 }
        }
    }
    elseif ($Item.ObjectType -eq "Table") { return 100 }
    elseif ($Item.ObjectType -eq "TableType") { return 110 }
    elseif ($Item.ObjectType -eq "Sequence") { return 120 }
    elseif ($Item.ObjectType -eq "Index") { return 900 }
    elseif ($Item.ObjectType -eq "Trigger") { return 1100 }
    elseif ($Item.ObjectType -eq "Function") { return 490 }
    elseif ($Item.ObjectType -eq "StoredProcedure") { return 510 }
    return 500
}

function Get-CymBuildSqlTwoPartReferenceKeys {
    param([string]$Sql)

    $text = [regex]::Replace([string]$Sql, '/\*[\s\S]*?\*/', ' ')
    $text = [regex]::Replace($text, '--[^\r\n]*', ' ')

    # Lookahead so that every dotted pair is seen, including the schema.object tail of a
    # three-part name.
    $identifier = '(?:\[([^\]]+)\]|([A-Za-z_][\w@$#]*))'
    $pattern = '(?<![\w@$#\[])(?=' + $identifier + '\s*\.\s*' + $identifier + ')'
    $keys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($text, $pattern)) {
        $schemaName = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        $objectName = if ($match.Groups[3].Success) { $match.Groups[3].Value } else { $match.Groups[4].Value }
        [void]$keys.Add("$schemaName.$objectName")
    }

    return ,$keys
}

# 2026-10-10, UAT_Test run 99bdd9e8: the type rank applied every Function before every View, so
# SJob.tvf_JobFeeDrawdown (reading the new SJob.Job_FeeDrawdown.Variation column) failed with
# "Invalid column name 'Variation'" before the view was deployed. Views can read functions and
# functions can read views, so within the Function/View/StoredProcedure band each module is
# applied after the selected modules its committed source references. The type rank still breaks
# ties, and a reference cycle falls back to type rank for the modules involved.
function Get-CymBuildOrderedApplyItems {
    param([object[]]$Items)

    $ranked = @(
        $Items |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) } |
            Sort-Object @{ Expression = { Get-CymBuildApplyItemRank -Item $_ } }, SchemaName, ParentObjectName, ObjectName
    )

    $moduleIndexes = @(for ($i = 0; $i -lt $ranked.Count; $i++) {
        $rank = Get-CymBuildApplyItemRank -Item $ranked[$i]
        if ($rank -ge 490 -and $rank -le 510) { $i }
    })
    if ($moduleIndexes.Count -lt 2) {
        return $ranked
    }

    $modules = @($moduleIndexes | ForEach-Object { $ranked[$_] })
    $indexesByKey = @{}
    for ($i = 0; $i -lt $modules.Count; $i++) {
        $key = ("$($modules[$i].SchemaName).$($modules[$i].ObjectName)").ToLowerInvariant()
        if (-not $indexesByKey.ContainsKey($key)) { $indexesByKey[$key] = New-Object System.Collections.Generic.List[int] }
        $indexesByKey[$key].Add($i)
    }

    $dependencies = @{}
    for ($i = 0; $i -lt $modules.Count; $i++) {
        $dependencies[$i] = New-Object System.Collections.Generic.HashSet[int]
        $sql = Get-Content -LiteralPath $modules[$i].SourceFile -Raw
        foreach ($reference in (Get-CymBuildSqlTwoPartReferenceKeys -Sql $sql)) {
            $key = $reference.ToLowerInvariant()
            if (-not $indexesByKey.ContainsKey($key)) { continue }
            foreach ($dependencyIndex in $indexesByKey[$key]) {
                if ($dependencyIndex -ne $i) { [void]$dependencies[$i].Add($dependencyIndex) }
            }
        }
    }

    $emitted = New-Object System.Collections.Generic.HashSet[int]
    $orderedModules = New-Object System.Collections.Generic.List[object]
    while ($orderedModules.Count -lt $modules.Count) {
        $next = -1
        for ($i = 0; $i -lt $modules.Count; $i++) {
            if ($emitted.Contains($i)) { continue }
            $ready = $true
            foreach ($dependencyIndex in $dependencies[$i]) {
                if (-not $emitted.Contains($dependencyIndex)) { $ready = $false; break }
            }
            if ($ready) { $next = $i; break }
        }

        if ($next -lt 0) {
            for ($i = 0; $i -lt $modules.Count; $i++) {
                if (-not $emitted.Contains($i)) { $next = $i; break }
            }
            Write-Warning "Module reference cycle involving $($modules[$next].ObjectType) $($modules[$next].SchemaName).$($modules[$next].ObjectName); applying it in type-rank order."
        }

        [void]$emitted.Add($next)
        $orderedModules.Add($modules[$next])
    }

    $result = New-Object System.Collections.Generic.List[object]
    $moduleCursor = 0
    for ($i = 0; $i -lt $ranked.Count; $i++) {
        if ($moduleIndexes -contains $i) {
            $result.Add($orderedModules[$moduleCursor])
            $moduleCursor++
        }
        else {
            $result.Add($ranked[$i])
        }
    }

    return $result.ToArray()
}

function New-PreviewDeploymentScript {
    param([object[]]$SupportedItems)

    $scriptPath = Join-Path $OutputDirectory "manual-preview-deployment.sql"
    $content = New-Object System.Text.StringBuilder
    $hasSelectedTableDeployment = @($SupportedItems | Where-Object { $_.ObjectType -eq "Table" -and -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) }).Count -gt 0
    $deferredPreflightItems = @($SupportedItems | Where-Object {
        $hasSelectedTableDeployment -and
        $_.ObjectType -in @("Constraint", "Index") -and
        -not [string]::IsNullOrWhiteSpace([string]$_.PreflightFile)
    })

    [void]$content.AppendLine("/*")
    [void]$content.AppendLine("    CYB-361 generated manual preview deployment script")
    [void]$content.AppendLine("    Target server   : $TargetServer")
    [void]$content.AppendLine("    Target database : $TargetDatabase")
    [void]$content.AppendLine("    Run Guid        : $RunGuid")
    [void]$content.AppendLine("    Generated UTC   : $([DateTime]::UtcNow.ToString("O"))")
    [void]$content.AppendLine("")
    [void]$content.AppendLine("    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.")
    [void]$content.AppendLine("    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.")
    [void]$content.AppendLine("*/")
    [void]$content.AppendLine("USE [$($TargetDatabase.Replace("]", "]]"))];")
    [void]$content.AppendLine("GO")
    [void]$content.AppendLine("EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = $([int](-not $SkipPreDeployment)), @read_only = 0;")
    [void]$content.AppendLine("GO")

    foreach ($item in $SupportedItems) {
        foreach ($supportFile in $item.SupportFiles) {
            $supportSql = Get-Content -LiteralPath $supportFile -Raw
            [void]$content.AppendLine("")
            [void]$content.AppendLine("/* Prepare shared migration support for $($item.ObjectType) $($item.SchemaName).$($item.ObjectName) from $supportFile */")
            [void]$content.AppendLine($supportSql)
            [void]$content.AppendLine("GO")
        }

        if ([string]::IsNullOrWhiteSpace([string]$item.PreflightFile)) {
            continue
        }
        if ($hasSelectedTableDeployment -and $item.ObjectType -in @("Constraint", "Index")) {
            continue
        }

        $preflightSql = Get-Content -LiteralPath $item.PreflightFile -Raw
        [void]$content.AppendLine("")
        [void]$content.AppendLine("/* Preflight $($item.ObjectType) $($item.SchemaName).$($item.ObjectName) from $($item.PreflightFile) */")
        [void]$content.AppendLine($preflightSql)
        [void]$content.AppendLine("GO")
    }

    if (-not $SkipPreDeployment) {
        [void]$content.AppendLine("EXEC [SCore].[PreDeploymentScript];")
        [void]$content.AppendLine("GO")
        [void]$content.AppendLine("EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;")
        [void]$content.AppendLine("GO")

        foreach ($item in $SupportedItems) {
            if ([string]::IsNullOrWhiteSpace([string]$item.PreflightFile)) {
                continue
            }
            if ($hasSelectedTableDeployment -and $item.ObjectType -in @("Constraint", "Index")) {
                continue
            }

            $strictPreflightSql = Get-Content -LiteralPath $item.PreflightFile -Raw
            [void]$content.AppendLine("")
            [void]$content.AppendLine("/* Strict post-pre-deployment preflight $($item.ObjectType) $($item.SchemaName).$($item.ObjectName) */")
            [void]$content.AppendLine($strictPreflightSql)
            [void]$content.AppendLine("GO")
        }
    }

    foreach ($item in @(
        $SupportedItems |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.PrepareFile) } |
            Sort-Object @{ Expression = {
                if ($_.ObjectType -eq "Index") { return 5 }
                switch ($_.ConstraintKind) {
                    "FOREIGN_KEY" { 10 }
                    "CHECK" { 20 }
                    "DEFAULT" { 20 }
                    "UNIQUE" { 30 }
                    "PRIMARY_KEY" { 30 }
                    default { 50 }
                }
            } }, SchemaName, ParentObjectName, ObjectName
    )) {
        $prepareSql = Get-Content -LiteralPath $item.PrepareFile -Raw
        [void]$content.AppendLine("")
        [void]$content.AppendLine("/* Prepare $($item.ObjectType) $($item.SchemaName).$($item.ParentObjectName).$($item.ObjectName) from $($item.PrepareFile) */")
        [void]$content.AppendLine($prepareSql)
        [void]$content.AppendLine("GO")
    }

    $orderedApplyItems = @(Get-CymBuildOrderedApplyItems -Items $SupportedItems)

    $deferredPreflightsWritten = $deferredPreflightItems.Count -eq 0
    foreach ($item in $orderedApplyItems) {
        if (-not $deferredPreflightsWritten -and $item.ObjectType -in @("Index", "Constraint")) {
            foreach ($deferredItem in $deferredPreflightItems) {
                $deferredSql = Get-Content -LiteralPath $deferredItem.PreflightFile -Raw
                [void]$content.AppendLine("")
                [void]$content.AppendLine("/* Post-structure preflight $($deferredItem.ObjectType) $($deferredItem.SchemaName).$($deferredItem.ObjectName) */")
                [void]$content.AppendLine($deferredSql)
                [void]$content.AppendLine("GO")
            }
            $deferredPreflightsWritten = $true
        }

        $sql = Get-Content -LiteralPath $item.SourceFile -Raw
        $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
        [void]$content.AppendLine("")
        [void]$content.AppendLine("/* Deploy $($item.ObjectType) $($item.SchemaName).$($item.ObjectName) using $($item.DeploymentMode) from $($item.SourceFile) */")
        [void]$content.AppendLine($sql)
        [void]$content.AppendLine("GO")
    }

    if (-not $SkipPostDeployment -and -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$content.AppendLine("DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();")
        [void]$content.AppendLine("EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;")
        [void]$content.AppendLine("GO")

        foreach ($item in @($SupportedItems | Where-Object {
            ([string]$_.ObjectType).Equals("Trigger", [System.StringComparison]::OrdinalIgnoreCase) -and
            ([string]$_.ObjectName) -match '(?i)^tg_.+_RecordHistory$' -and
            -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile)
        })) {
            $sql = Get-Content -LiteralPath $item.SourceFile -Raw
            $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
            [void]$content.AppendLine("")
            [void]$content.AppendLine("/* Reapply selected lifecycle-generated Trigger $($item.SchemaName).$($item.ObjectName) from canonical source */")
            [void]$content.AppendLine($sql)
            [void]$content.AppendLine("GO")
        }
    }

    Write-CymBuildTextFile -Path $scriptPath -Content $content.ToString()
    return $scriptPath
}

function Get-CymBuildPlanFingerprint {
    param([System.Data.DataTable]$PlanTable)

    $lines = foreach ($row in $PlanTable.Rows) {
        @(
            (Get-DataRowText -Row $row -ColumnName "ComparisonGuid"),
            (Get-DataRowText -Row $row -ColumnName "ObjectType"),
            (Get-DataRowText -Row $row -ColumnName "SchemaName"),
            (Get-DataRowText -Row $row -ColumnName "ObjectName"),
            (Get-DataRowText -Row $row -ColumnName "ParentObjectName"),
            (Get-DataRowText -Row $row -ColumnName "DifferenceType"),
            (Get-DataRowText -Row $row -ColumnName "SourceHash"),
            (Get-DataRowText -Row $row -ColumnName "TargetHash"),
            # CYB-566: a changed "Copy reference data" choice or re-captured new-table data is a
            # different plan, so it must invalidate a lock taken on the previous fingerprint.
            (Get-DataRowText -Row $row -ColumnName "CopyReferenceData"),
            (Get-TextSha256 -Text (Get-DataRowText -Row $row -ColumnName "NewTableCaptureJson"))
        ) -join "|"
    }

    $canonicalPlan = [string]::Join("`n", @($lines | Sort-Object))
    return (Get-TextSha256 -Text $canonicalPlan)
}

function Assert-R7DExecutionInfrastructure {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    $table = Invoke-SqlQuery -Connection $Connection -Sql @"
SELECT
    CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_DeploymentAttempts]', N'U') IS NOT NULL THEN 1 ELSE 0 END) AS HasAttempts,
    CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_DeploymentObjectCheckpoints]', N'U') IS NOT NULL THEN 1 ELSE 0 END) AS HasCheckpoints,
    CONVERT(BIT, CASE WHEN EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        INNER JOIN [SCore].[EntityTypes] AS entityType
            ON entityType.[ID] = entityHobt.[EntityTypeID]
        WHERE entityHobt.[Guid] = 'D7A10001-3610-47D0-A002-000000000001'
          AND entityHobt.[SchemaName] = N'SMigration'
          AND entityHobt.[ObjectName] = N'Schema_DeploymentAttempts'
          AND entityHobt.[ObjectType] = N'U'
          AND entityHobt.[IsMainHoBT] = 1
          AND entityHobt.[RowStatus] <> 0
          AND entityHobt.[RowStatus] <> 254
          AND entityType.[Guid] = 'D7A10001-3610-47D0-A001-000000000001'
          AND entityType.[RowStatus] <> 0
          AND entityType.[RowStatus] <> 254
    ) THEN 1 ELSE 0 END) AS HasAttemptOwnership,
    CONVERT(BIT, CASE WHEN EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        INNER JOIN [SCore].[EntityTypes] AS entityType
            ON entityType.[ID] = entityHobt.[EntityTypeID]
        WHERE entityHobt.[Guid] = 'D7A10002-3610-47D0-A002-000000000002'
          AND entityHobt.[SchemaName] = N'SMigration'
          AND entityHobt.[ObjectName] = N'Schema_DeploymentObjectCheckpoints'
          AND entityHobt.[ObjectType] = N'U'
          AND entityHobt.[IsMainHoBT] = 1
          AND entityHobt.[RowStatus] <> 0
          AND entityHobt.[RowStatus] <> 254
          AND entityType.[Guid] = 'D7A10002-3610-47D0-A001-000000000002'
          AND entityType.[RowStatus] <> 0
          AND entityType.[RowStatus] <> 254
    ) THEN 1 ELSE 0 END) AS HasCheckpointOwnership,
    CONVERT(BIT, CASE WHEN NOT EXISTS
    (
        SELECT 1
        FROM [SMigration].[Schema_DeploymentAttempts] AS attempt
        INNER JOIN [SCore].[EntityHobts] AS entityHobt
            ON entityHobt.[SchemaName] = N'SMigration'
           AND entityHobt.[ObjectName] = N'Schema_DeploymentAttempts'
           AND entityHobt.[RowStatus] <> 0
           AND entityHobt.[RowStatus] <> 254
        LEFT JOIN [SCore].[DataObjects] AS dataObject
            ON dataObject.[Guid] = attempt.[Guid]
        WHERE attempt.[RowStatus] <> 0
          AND attempt.[RowStatus] <> 254
          AND
          (
              dataObject.[Guid] IS NULL
              OR dataObject.[RowStatus] = 0
              OR dataObject.[RowStatus] = 254
              OR dataObject.[EntityTypeId] <> entityHobt.[EntityTypeID]
          )
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM [SMigration].[Schema_DeploymentObjectCheckpoints] AS [checkpoint]
        INNER JOIN [SCore].[EntityHobts] AS entityHobt
            ON entityHobt.[SchemaName] = N'SMigration'
           AND entityHobt.[ObjectName] = N'Schema_DeploymentObjectCheckpoints'
           AND entityHobt.[RowStatus] <> 0
           AND entityHobt.[RowStatus] <> 254
        LEFT JOIN [SCore].[DataObjects] AS dataObject
            ON dataObject.[Guid] = [checkpoint].[Guid]
        WHERE [checkpoint].[RowStatus] <> 0
          AND [checkpoint].[RowStatus] <> 254
          AND
          (
              dataObject.[Guid] IS NULL
              OR dataObject.[RowStatus] = 0
              OR dataObject.[RowStatus] = 254
              OR dataObject.[EntityTypeId] <> entityHobt.[EntityTypeID]
          )
    ) THEN 1 ELSE 0 END) AS HasAuditDataObjectCompliance;
"@

    if ($table.Rows.Count -ne 1 -or
        -not [bool]$table.Rows[0]["HasAttempts"] -or
        -not [bool]$table.Rows[0]["HasCheckpoints"] -or
        -not [bool]$table.Rows[0]["HasAttemptOwnership"] -or
        -not [bool]$table.Rows[0]["HasCheckpointOwnership"] -or
        -not [bool]$table.Rows[0]["HasAuditDataObjectCompliance"]) {
        throw "CYB-361 R7D execution-audit tables, exact EntityType/EntityHoBT ownership or DataObject compliance are incomplete on the target. Restart the current R7D API and create a fresh Schema run so controlled bootstrap can converge the target before WhatIf or Apply."
    }
}

function Assert-RunUsesR7DBootstrapEvidence {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    $evidence = Invoke-SqlQuery -Connection $Connection -Sql @"
SELECT TOP (1) 1 AS HasR7DBootstrapEvidence
FROM [SMigration].[Schema_ExecutionLog]
WHERE [RunGuid] = @RunGuid
  AND [StepName] = N'BootstrapTarget'
  AND [StepStatus] = N'Applied'
  AND [DetailsJson] LIKE N'%SchemaR7D.ExecutionHardening.Bootstrap.sql%'
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254
ORDER BY [ID] DESC;
"@ -Parameters @{ "@RunGuid" = $RunGuid }

    if ($evidence.Rows.Count -ne 1) {
        throw "Run $RunGuid has no R7D target-bootstrap evidence. Restart the R7D API and create, compare, select, validate and accept a fresh DEV-to-target Schema run; earlier accepted runs cannot be reused."
    }
}

function Acquire-CymBuildSchemaDeploymentLock {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    $script:deploymentLockResource = "CymBuild.SchemaDeployment.Apply|$($Connection.Database.ToUpperInvariant())"
    $timeoutMilliseconds = [int64]$ApplyLockTimeoutSeconds * 1000
    $result = Invoke-SqlQuery -Connection $Connection -Sql @"
DECLARE @LockResult INT;
EXEC @LockResult = sys.sp_getapplock
    @Resource = @Resource,
    @LockMode = N'Exclusive',
    @LockOwner = N'Session',
    @LockTimeout = @LockTimeout;
SELECT @LockResult AS LockResult;
"@ -Parameters @{
        "@Resource" = $script:deploymentLockResource
        "@LockTimeout" = [int]$timeoutMilliseconds
    } -TimeoutSeconds ([Math]::Max(30, $ApplyLockTimeoutSeconds + 30))

    $lockResult = [int]$result.Rows[0]["LockResult"]
    if ($lockResult -lt 0) {
        throw "Another schema deployment apply is already active for target database '$($Connection.Database)'. The R7D application lock was not acquired (SQL result $lockResult). Wait for the active deployment to finish; do not bypass the lock."
    }

    $script:deploymentLockAcquired = $true
    Write-Host "Apply lock      : acquired ($($script:deploymentLockResource))" -ForegroundColor Green
}

function Release-CymBuildSchemaDeploymentLock {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    if (-not $script:deploymentLockAcquired) {
        return
    }

    $result = Invoke-SqlQuery -Connection $Connection -Sql @"
DECLARE @ReleaseResult INT;
EXEC @ReleaseResult = sys.sp_releaseapplock
    @Resource = @Resource,
    @LockOwner = N'Session';
SELECT @ReleaseResult AS ReleaseResult;
"@ -Parameters @{ "@Resource" = $script:deploymentLockResource }

    $releaseResult = [int]$result.Rows[0]["ReleaseResult"]
    if ($releaseResult -lt 0) {
        throw "R7D could not explicitly release schema deployment lock '$($script:deploymentLockResource)' (SQL result $releaseResult)."
    }

    $script:deploymentLockAcquired = $false
}

function Start-CymBuildSchemaDeploymentAttempt {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [int]$ExpectedObjectCount
    )

    $attemptGuidValue = [Guid]::NewGuid()
    $attempt = Invoke-SqlQuery -Connection $Connection -Sql @"
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @AttemptNumber INT;
SELECT @AttemptNumber = ISNULL(MAX([AttemptNumber]), 0) + 1
FROM [SMigration].[Schema_DeploymentAttempts] WITH (UPDLOCK, HOLDLOCK)
WHERE [RunGuid] = @RunGuid
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;

EXEC [SMigration].[SchemaDataObject_Ensure]
    @Guid = @AttemptGuid,
    @SchemeName = N'SMigration',
    @ObjectName = N'Schema_DeploymentAttempts',
    @RequireExactEntityType = 1;

INSERT INTO [SMigration].[Schema_DeploymentAttempts]
(
    [Guid], [RowStatus], [RunGuid], [AttemptNumber], [ExecutionId],
    [TargetServerName], [TargetDatabaseName], [ReleaseReference],
    [DeploymentReference], [LockResource], [PlanFingerprint],
    [ExpectedObjectCount], [AttemptStatus], [StartedOnUtc],
    [CompletedOnUtc], [FailureMessage], [SummaryJson]
)
VALUES
(
    @AttemptGuid, 1, @RunGuid, @AttemptNumber, @ExecutionId,
    @TargetServerName, @TargetDatabaseName, @ReleaseReference,
    @DeploymentReference, @LockResource, @PlanFingerprint,
    @ExpectedObjectCount, N'Started', SYSUTCDATETIME(),
    NULL, N'', N'{"contract":"CYB_SCHEMA_DEPLOYMENT_R7D"}'
);

COMMIT TRANSACTION;
SELECT @AttemptGuid AS AttemptGuid, @AttemptNumber AS AttemptNumber;
"@ -Parameters @{
        "@AttemptGuid" = $attemptGuidValue
        "@RunGuid" = $RunGuid
        "@ExecutionId" = $executionId
        "@TargetServerName" = $TargetServer
        "@TargetDatabaseName" = $TargetDatabase
        "@ReleaseReference" = $ReleaseReference
        "@DeploymentReference" = $DeploymentReference
        "@LockResource" = $script:deploymentLockResource
        "@PlanFingerprint" = $script:planFingerprint
        "@ExpectedObjectCount" = $ExpectedObjectCount
    }

    $script:deploymentAttemptGuid = [Guid]$attempt.Rows[0]["AttemptGuid"]
    $script:deploymentAttemptNumber = [int]$attempt.Rows[0]["AttemptNumber"]
    $script:deploymentAuditStarted = $true
    Write-Host "Attempt          : $($script:deploymentAttemptNumber) ($($script:deploymentAttemptGuid))" -ForegroundColor Green
}

function Complete-CymBuildSchemaDeploymentAttempt {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Status,
        [string]$FailureMessage = "",
        [object]$Summary = $null
    )

    if ($script:deploymentAttemptGuid -eq [Guid]::Empty) {
        return
    }

    $safeFailure = if ($FailureMessage.Length -gt 2000) { $FailureMessage.Substring(0, 2000) } else { $FailureMessage }
    Invoke-SqlNonQuery -Connection $Connection -Sql @"
UPDATE [SMigration].[Schema_DeploymentAttempts]
SET
    [AttemptStatus] = @AttemptStatus,
    [CompletedOnUtc] = SYSUTCDATETIME(),
    [FailureMessage] = @FailureMessage,
    [SummaryJson] = @SummaryJson
WHERE [Guid] = @AttemptGuid
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;
"@ -Parameters @{
        "@AttemptGuid" = $script:deploymentAttemptGuid
        "@AttemptStatus" = $Status
        "@FailureMessage" = $safeFailure
        "@SummaryJson" = (ConvertTo-JsonSafe -Value $Summary)
    }
}

function Set-CymBuildSchemaObjectCheckpoint {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object]$Item,
        [string]$Phase,
        [string]$Status,
        [string]$ExpectedHash = "",
        [string]$ObservedHash = "",
        [string]$Message = "",
        [object]$Details = $null
    )

    if ($script:deploymentAttemptGuid -eq [Guid]::Empty) {
        return
    }

    $checkpointGuid = [Guid]::NewGuid()
    $safeMessage = if ($Message.Length -gt 2000) { $Message.Substring(0, 2000) } else { $Message }
    Invoke-SqlNonQuery -Connection $Connection -Sql @"
SET XACT_ABORT ON;
BEGIN TRANSACTION;

UPDATE [SMigration].[Schema_DeploymentObjectCheckpoints] WITH (UPDLOCK, HOLDLOCK)
SET
    [CheckpointStatus] = @CheckpointStatus,
    [ExpectedHash] = @ExpectedHash,
    [ObservedHash] = @ObservedHash,
    [Message] = @Message,
    [DetailsJson] = @DetailsJson,
    [UpdatedOnUtc] = SYSUTCDATETIME()
WHERE [AttemptGuid] = @AttemptGuid
  AND [ComparisonGuid] = @ComparisonGuid
  AND [CheckpointPhase] = @CheckpointPhase
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;

IF @@ROWCOUNT = 0
BEGIN
    EXEC [SMigration].[SchemaDataObject_Ensure]
        @Guid = @CheckpointGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Schema_DeploymentObjectCheckpoints',
        @RequireExactEntityType = 1;

    INSERT INTO [SMigration].[Schema_DeploymentObjectCheckpoints]
    (
        [Guid], [RowStatus], [RunGuid], [AttemptGuid], [ComparisonGuid],
        [ObjectType], [SchemaName], [ObjectName], [ParentObjectName],
        [CheckpointPhase], [CheckpointStatus], [ExpectedHash], [ObservedHash],
        [Message], [DetailsJson], [CreatedOnUtc], [UpdatedOnUtc]
    )
    VALUES
    (
        @CheckpointGuid, 1, @RunGuid, @AttemptGuid, @ComparisonGuid,
        @ObjectType, @SchemaName, @ObjectName, @ParentObjectName,
        @CheckpointPhase, @CheckpointStatus, @ExpectedHash, @ObservedHash,
        @Message, @DetailsJson, SYSUTCDATETIME(), SYSUTCDATETIME()
    );
END;

COMMIT TRANSACTION;
"@ -Parameters @{
        "@CheckpointGuid" = $checkpointGuid
        "@RunGuid" = $RunGuid
        "@AttemptGuid" = $script:deploymentAttemptGuid
        "@ComparisonGuid" = [Guid]$Item.ComparisonGuid
        "@ObjectType" = [string]$Item.ObjectType
        "@SchemaName" = [string]$Item.SchemaName
        "@ObjectName" = [string]$Item.ObjectName
        "@ParentObjectName" = [string]$Item.ParentObjectName
        "@CheckpointPhase" = $Phase
        "@CheckpointStatus" = $Status
        "@ExpectedHash" = $ExpectedHash
        "@ObservedHash" = $ObservedHash
        "@Message" = $safeMessage
        "@DetailsJson" = (ConvertTo-JsonSafe -Value $Details)
    }
}

function Get-CymBuildSnapshotKey {
    param(
        [string]$ObjectType,
        [string]$SchemaName,
        [string]$ObjectName,
        [string]$ParentObjectName
    )

    return ("{0}|{1}|{2}|{3}" -f $ObjectType, $SchemaName, $ObjectName, $ParentObjectName).ToUpperInvariant()
}

function Get-CymBuildTargetSchemaSnapshot {
    param([System.Data.SqlClient.SqlConnection]$Connection)

    $snapshotPath = Join-Path $PSScriptRoot "SchemaTargetSnapshot.R7D.sql"
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        throw "R7D target snapshot SQL is missing: '$snapshotPath'."
    }

    $snapshotSql = Get-Content -LiteralPath $snapshotPath -Raw
    $batches = @(Split-SqlBatches -Sql $snapshotSql)
    if ($batches.Count -ne 10) {
        throw "R7D target snapshot contract expected 10 catalogue batches but found $($batches.Count)."
    }

    $snapshot = @{}
    foreach ($batch in $batches) {
        $marker = [regex]::Match($batch, '(?im)^\s*--\s*CYMBUILD SNAPSHOT QUERY:\s*(?<Name>[A-Za-z]+)\s*$')
        if (-not $marker.Success) {
            throw "R7D target snapshot batch is missing its contract marker."
        }

        $rows = Invoke-SqlQuery -Connection $Connection -Sql $batch -TimeoutSeconds 900
        foreach ($row in $rows.Rows) {
            $objectType = Get-DataRowText -Row $row -ColumnName "ObjectType"
            $schemaName = Get-DataRowText -Row $row -ColumnName "SchemaName"
            $objectName = Get-DataRowText -Row $row -ColumnName "ObjectName"
            $parentObjectName = Get-DataRowText -Row $row -ColumnName "ParentObjectName"
            $definition = Get-DataRowText -Row $row -ColumnName "Definition"
            $key = Get-CymBuildSnapshotKey -ObjectType $objectType -SchemaName $schemaName -ObjectName $objectName -ParentObjectName $parentObjectName
            if ($snapshot.ContainsKey($key)) {
                throw "R7D target snapshot returned duplicate object key '$key'."
            }

            $snapshot[$key] = [pscustomobject]@{
                ObjectType = $objectType
                SchemaName = $schemaName
                ObjectName = $objectName
                ParentObjectName = $parentObjectName
                Definition = $definition
                Hash = Get-CymBuildSchemaDefinitionHash -Definition $definition
                QueryName = $marker.Groups["Name"].Value
            }
        }
    }

    return $snapshot
}

function Assert-CymBuildTargetBaseline {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object[]]$SupportedItems,
        [bool]$RecordCheckpoints
    )

    Write-Host "Re-snapshotting selected target objects before pre-deployment..." -ForegroundColor Cyan
    $snapshot = Get-CymBuildTargetSchemaSnapshot -Connection $Connection
    $failures = New-Object System.Collections.Generic.List[object]

    foreach ($item in $SupportedItems) {
        $key = Get-CymBuildSnapshotKey -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -ParentObjectName $item.ParentObjectName
        $current = if ($snapshot.ContainsKey($key)) { $snapshot[$key] } else { $null }
        $expectedHash = ([string]$item.TargetHash).Trim()
        $acceptedSourceHash = ([string]$item.SourceHash).Trim()
        $acceptedOperationalTargetHash = ([string]$item.OperationalTargetHash).Trim()
        $acceptedOperationalSourceHash = ([string]$item.OperationalSourceHash).Trim()
        $observedHash = if ($null -eq $current) { "" } else { [string]$current.Hash }
        $observedOperationalHash = if ($null -eq $current -or
            -not [bool]$item.SupportsOperationalSchemaBindingLifecycle) {
            ""
        }
        else {
            Get-CymBuildSchemaDefinitionHash `
                -Definition ([string]$current.Definition) `
                -IgnoreOperationalSchemaBinding
        }
        # A normal run remains strictly bound to the accepted TargetHash, EXCEPT for
        # objects whose accepted comparison recorded SupportsOperationalSchemaBindingLifecycle:
        # Compare itself runs every comparison through SCore.PreDeploymentScript (strips
        # WITH SCHEMABINDING) -> snapshot capture -> SCore.PostDeploymentScript (restores
        # it), so a schema-bound Function/View's live target is routinely back in its bound
        # "operational" shape by the time WhatIf/Apply re-snapshots it, and its accepted
        # OperationalTargetHash (normalized the same way) is what actually reflects that.
        # Treating that as drift on every ordinary run made every such object permanently
        # undeployable. A failed-run retry may additionally observe the exact accepted
        # source state from already-applied work.
        $matchesOriginalTarget = if ([string]::IsNullOrWhiteSpace($expectedHash)) {
            $null -eq $current
        }
        else {
            $null -ne $current -and $observedHash.Equals($expectedHash, [System.StringComparison]::OrdinalIgnoreCase)
        }
        $matchesAcceptedSourceOnRetry = if (-not $RetryFailedDeployment) {
            $false
        }
        elseif ([string]::IsNullOrWhiteSpace($acceptedSourceHash)) {
                $null -eq $current
        }
        else {
            $null -ne $current -and $observedHash.Equals($acceptedSourceHash, [System.StringComparison]::OrdinalIgnoreCase)
        }
        $matchesOperationalTarget = [bool]$item.SupportsOperationalSchemaBindingLifecycle -and
            $null -ne $current -and
            -not [string]::IsNullOrWhiteSpace($acceptedOperationalTargetHash) -and
            $observedOperationalHash.Equals($acceptedOperationalTargetHash, [System.StringComparison]::OrdinalIgnoreCase)
        $matchesOperationalSourceOnRetry = $RetryFailedDeployment -and
            [bool]$item.SupportsOperationalSchemaBindingLifecycle -and
            $null -ne $current -and
            -not [string]::IsNullOrWhiteSpace($acceptedOperationalSourceHash) -and
            $observedOperationalHash.Equals($acceptedOperationalSourceHash, [System.StringComparison]::OrdinalIgnoreCase)
        $succeeded = $matchesOriginalTarget -or
            $matchesAcceptedSourceOnRetry -or
            $matchesOperationalTarget -or
            $matchesOperationalSourceOnRetry
        $matchKind = if ($matchesOriginalTarget) {
            "AcceptedTarget"
        }
        elseif ($matchesAcceptedSourceOnRetry) {
            "AcceptedSourceFromPriorAttempt"
        }
        elseif ($matchesOperationalTarget) {
            "AcceptedTargetOperationalSchemaBinding"
        }
        elseif ($matchesOperationalSourceOnRetry) {
            "AcceptedSourceOperationalSchemaBinding"
        }
        else {
            "None"
        }
        $message = if ($succeeded) {
            switch ($matchKind) {
                "AcceptedTarget" { "Persisted target baseline matches the current target catalogue." }
                "AcceptedSourceFromPriorAttempt" { "Retry target already matches the immutable accepted source state from a prior failed attempt." }
                "AcceptedTargetOperationalSchemaBinding" { "Target matches the accepted target baseline after normalizing only the controlled WITH SCHEMABINDING lifecycle clause restored by SCore.PostDeploymentScript." }
                "AcceptedSourceOperationalSchemaBinding" { "Retry target matches the immutable accepted source state after normalizing only the controlled WITH SCHEMABINDING lifecycle clause." }
            }
        }
        elseif ([string]::IsNullOrWhiteSpace($expectedHash)) {
            "The accepted plan expected the target object to be absent, but it now exists."
        }
        elseif ($null -eq $current) {
            "The accepted plan expected the target object to exist, but it is now absent."
        }
        else {
            "The target object changed after the accepted comparison was staged."
        }

        if ($RecordCheckpoints) {
            $checkpointExpectedHash = if ($matchesOperationalTarget) {
                $acceptedOperationalTargetHash
            }
            elseif ($matchesOperationalSourceOnRetry) {
                $acceptedOperationalSourceHash
            }
            elseif ($matchesAcceptedSourceOnRetry) {
                $acceptedSourceHash
            }
            else {
                $expectedHash
            }
            $checkpointObservedHash = if ($matchesOperationalTarget -or $matchesOperationalSourceOnRetry) { $observedOperationalHash } else { $observedHash }
            Set-CymBuildSchemaObjectCheckpoint -Connection $Connection -Item $item -Phase "TargetBaseline" -Status $(if ($succeeded) { "Succeeded" } else { "Failed" }) -ExpectedHash $checkpointExpectedHash -ObservedHash $checkpointObservedHash -Message $message -Details @{
                SnapshotKey = $key
                MatchKind = $matchKind
                RetryFailedDeployment = [bool]$RetryFailedDeployment
                AcceptedTargetHash = $expectedHash
                AcceptedSourceHash = $acceptedSourceHash
                AcceptedOperationalTargetHash = $acceptedOperationalTargetHash
                AcceptedOperationalSourceHash = $acceptedOperationalSourceHash
                ObservedRawHash = $observedHash
                ObservedOperationalHash = $observedOperationalHash
            }
        }

        if (-not $succeeded) {
            [void]$failures.Add([pscustomobject]@{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                ParentObjectName = $item.ParentObjectName
                ExpectedTargetHash = $expectedHash
                AcceptedSourceHash = $acceptedSourceHash
                AcceptedOperationalTargetHash = $acceptedOperationalTargetHash
                AcceptedOperationalSourceHash = $acceptedOperationalSourceHash
                ObservedTargetHash = $observedHash
                ObservedOperationalHash = $observedOperationalHash
                RetryFailedDeployment = [bool]$RetryFailedDeployment
                Message = $message
            })
        }
    }

    if ($failures.Count -gt 0) {
        $failurePath = Join-Path $OutputDirectory "target-drift-failures.csv"
        Write-CymBuildTextFile -Path $failurePath -Content (ConvertTo-CymBuildCsvText -Rows $failures.ToArray())
        throw "Target drift detected for $($failures.Count) selected object(s). No pre-deployment script or selected DDL was run. Create a fresh comparison and accepted selection. Evidence: $failurePath"
    }

    Write-Host "Target drift check: passed for $($SupportedItems.Count) selected object(s)." -ForegroundColor Green
}

function Assert-CymBuildDeploymentVerification {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object[]]$SupportedItems,
        [string]$CheckpointPhase,
        [string]$StageLabel,
        [string]$FailureFileName,
        [bool]$AllowOperationalSchemaBinding
    )

    Write-Host "Re-snapshotting selected target objects for $StageLabel verification..." -ForegroundColor Cyan
    $snapshot = Get-CymBuildTargetSchemaSnapshot -Connection $Connection
    $failures = New-Object System.Collections.Generic.List[object]

    foreach ($item in $SupportedItems) {
        $key = Get-CymBuildSnapshotKey -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -ParentObjectName $item.ParentObjectName
        $current = if ($snapshot.ContainsKey($key)) { $snapshot[$key] } else { $null }
        $isRemoval = ([string]$item.DifferenceType).Equals("MissingInSource", [System.StringComparison]::OrdinalIgnoreCase)
        $expectedHash = if ($isRemoval) { "" } else { ([string]$item.SourceHash).Trim() }
        $expectedOperationalHash = if ($isRemoval) { "" } else { ([string]$item.OperationalSourceHash).Trim() }
        $observedHash = if ($null -eq $current) { "" } else { [string]$current.Hash }
        $observedOperationalHash = if ($null -eq $current -or
            -not [bool]$item.SupportsOperationalSchemaBindingLifecycle) {
            ""
        }
        else {
            Get-CymBuildSchemaDefinitionHash `
                -Definition ([string]$current.Definition) `
                -IgnoreOperationalSchemaBinding
        }
        $matchesAcceptedSource = -not [string]::IsNullOrWhiteSpace($expectedHash) -and
            $null -ne $current -and
            $observedHash.Equals($expectedHash, [System.StringComparison]::OrdinalIgnoreCase)
        $matchesOperationalSource = $AllowOperationalSchemaBinding -and
            -not [string]::IsNullOrWhiteSpace($expectedHash) -and
            [bool]$item.SupportsOperationalSchemaBindingLifecycle -and
            $null -ne $current -and
            -not [string]::IsNullOrWhiteSpace($expectedOperationalHash) -and
            $observedOperationalHash.Equals($expectedOperationalHash, [System.StringComparison]::OrdinalIgnoreCase)
        $succeeded = if ($isRemoval) {
            $null -eq $current
        }
        else {
            $matchesAcceptedSource -or $matchesOperationalSource
        }
        $message = if ($succeeded) {
            if ($matchesOperationalSource -and -not $matchesAcceptedSource) {
                "Current target definition matches the accepted source after normalizing only the controlled WITH SCHEMABINDING lifecycle clause."
            }
            else {
                "Current target definition matches the accepted source hash."
            }
        }
        elseif ($isRemoval) {
            "The accepted removal did not leave the target object absent."
        }
        elseif ([string]::IsNullOrWhiteSpace($expectedHash)) {
            "The accepted selected row has no source hash to verify."
        }
        elseif ($null -eq $current) {
            "The deployed target object is absent."
        }
        else {
            "The deployed target definition does not match the accepted source hash."
        }

        $checkpointExpectedHash = if ($matchesOperationalSource -and -not $matchesAcceptedSource) { $expectedOperationalHash } else { $expectedHash }
        $checkpointObservedHash = if ($matchesOperationalSource -and -not $matchesAcceptedSource) { $observedOperationalHash } else { $observedHash }
        Set-CymBuildSchemaObjectCheckpoint -Connection $Connection -Item $item -Phase $CheckpointPhase -Status $(if ($succeeded) { "Succeeded" } else { "Failed" }) -ExpectedHash $checkpointExpectedHash -ObservedHash $checkpointObservedHash -Message $message -Details @{
            SnapshotKey = $key
            MatchKind = $(if ($matchesAcceptedSource) { "AcceptedSource" } elseif ($matchesOperationalSource) { "AcceptedSourceOperationalSchemaBinding" } elseif ($isRemoval -and $null -eq $current) { "AcceptedRemoval" } else { "None" })
            AcceptedSourceHash = $expectedHash
            AcceptedOperationalSourceHash = $expectedOperationalHash
            ObservedRawHash = $observedHash
            ObservedOperationalHash = $observedOperationalHash
        }

        if (-not $succeeded) {
            [void]$failures.Add([pscustomobject]@{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                ParentObjectName = $item.ParentObjectName
                ExpectedSourceHash = $expectedHash
                ExpectedOperationalSourceHash = $expectedOperationalHash
                ObservedTargetHash = $observedHash
                ObservedOperationalHash = $observedOperationalHash
                Message = $message
            })
        }
    }

    if ($failures.Count -gt 0) {
        $failurePath = Join-Path $OutputDirectory $FailureFileName
        Write-CymBuildTextFile -Path $failurePath -Content (ConvertTo-CymBuildCsvText -Rows $failures.ToArray())
        throw "$StageLabel verification failed for $($failures.Count) selected object(s). The run will be marked DeploymentFailed. Evidence: $failurePath"
    }

    Write-Host "$StageLabel verification: passed for $($SupportedItems.Count) selected object(s)." -ForegroundColor Green
}

function Assert-CymBuildAppliedSourceVerification {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object[]]$SupportedItems
    )

    Assert-CymBuildDeploymentVerification `
        -Connection $Connection `
        -SupportedItems $SupportedItems `
        -CheckpointPhase "PrePostDeploymentVerification" `
        -StageLabel "Pre-post-deployment" `
        -FailureFileName "pre-post-deployment-verification-failures.csv" `
        -AllowOperationalSchemaBinding $false
}

function Assert-CymBuildPostDeploymentVerification {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object[]]$SupportedItems
    )

    Assert-CymBuildDeploymentVerification `
        -Connection $Connection `
        -SupportedItems $SupportedItems `
        -CheckpointPhase "Verification" `
        -StageLabel "Post-deployment" `
        -FailureFileName "post-apply-verification-failures.csv" `
        -AllowOperationalSchemaBinding $true
}

function Invoke-CymBuildSelectedPostDeploymentReapply {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [object[]]$SupportedItems
    )

    $recordHistoryTriggers = @($SupportedItems | Where-Object {
        ([string]$_.ObjectType).Equals("Trigger", [System.StringComparison]::OrdinalIgnoreCase) -and
        ([string]$_.ObjectName) -match '(?i)^tg_.+_RecordHistory$' -and
        -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile)
    })

    foreach ($item in $recordHistoryTriggers) {
        $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"
        Write-Host "Reapplying selected lifecycle-generated $objectLabel from canonical source" -ForegroundColor Cyan
        $sql = Get-Content -LiteralPath $item.SourceFile -Raw
        $sql = Convert-SchemaScriptForDeployment `
            -Sql $sql `
            -ObjectType $item.ObjectType `
            -SchemaName $item.SchemaName `
            -ObjectName $item.ObjectName `
            -DifferenceType $item.DifferenceType

        $script:activeCheckpointItem = $item
        $script:activeCheckpointPhase = "PostLifecycleReapply"
        Invoke-SqlScriptText `
            -Connection $Connection `
            -Sql $sql `
            -Description "$objectLabel post-deployment canonical reapply" `
            -TimeoutSeconds 1800
        Set-CymBuildSchemaObjectCheckpoint `
            -Connection $Connection `
            -Item $item `
            -Phase "PostLifecycleReapply" `
            -Status "Succeeded" `
            -ExpectedHash ([string]$item.SourceHash) `
            -Message "PostDeployment lifecycle generation completed, then the explicitly selected canonical trigger definition was reapplied." `
            -Details @{ SourceFile = $item.SourceFile; DeploymentMode = $item.DeploymentMode }
        $script:activeCheckpointItem = $null
        $script:activeCheckpointPhase = ""

        Add-SchemaExecutionLog `
            -Connection $Connection `
            -RunGuidValue $RunGuid `
            -StepName "ManualDeploymentPostLifecycleReapply" `
            -StepStatus "Applied" `
            -Message "$objectLabel was reapplied from committed canonical source after lifecycle generation." `
            -Details @{
                ComparisonGuid = $item.ComparisonGuid
                SourceFile = $item.SourceFile
                SourceHash = $item.SourceHash
            }
    }
}

function Write-CymBuildPostDeploymentIssueEvidence {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Guid]$PostDeploymentRunGuid
    )

    if ($PostDeploymentRunGuid -eq [Guid]::Empty) {
        return ""
    }

    $issues = Invoke-SqlQuery -Connection $Connection -Sql @"
SELECT
      [ID]
    , [RunGuid]
    , [StepName]
    , [ObjectName]
    , [Severity]
    , [Message]
    , [ErrorNumber]
    , [ErrorSeverity]
    , [ErrorState]
    , [ErrorLine]
    , [ErrorProcedure]
    , [CreatedUtc]
FROM [SCore].[PostDeploymentRunLog]
WHERE [RunGuid] = @PostDeploymentRunGuid
  AND [Severity] IN (N'Error', N'Warning')
ORDER BY [ID];
"@ -Parameters @{ "@PostDeploymentRunGuid" = $PostDeploymentRunGuid }

    $issueRows = foreach ($row in $issues.Rows) {
        [pscustomobject]@{
            ID = $row["ID"]
            RunGuid = $row["RunGuid"]
            StepName = $row["StepName"]
            ObjectName = $row["ObjectName"]
            Severity = $row["Severity"]
            Message = $row["Message"]
            ErrorNumber = $row["ErrorNumber"]
            ErrorSeverity = $row["ErrorSeverity"]
            ErrorState = $row["ErrorState"]
            ErrorLine = $row["ErrorLine"]
            ErrorProcedure = $row["ErrorProcedure"]
            CreatedUtc = $row["CreatedUtc"]
        }
    }

    $path = Join-Path $OutputDirectory "post-deployment-issues.csv"
    Write-CymBuildTextFile -Path $path -Content (ConvertTo-CymBuildCsvText -Rows @($issueRows))
    return $path
}

function Invoke-CymBuildSchemaDeployment {
    $preDeploymentCompleted = $false
    $postDeploymentCompleted = $false
    $postDeploymentInvoked = $false
    $postDeploymentRunGuid = [Guid]::Empty
    $postDeploymentIssueEvidencePath = ""

    $sqlConnectionString = New-CymBuildSqlConnectionString
    $connection = New-SqlConnection -SqlConnectionString $sqlConnectionString

    try {
        $runAndPlan = Get-RunAndPlan -Connection $connection
        $runRow = $runAndPlan.RunRow
        $planTable = $runAndPlan.PlanTable

        Assert-RunCanDeploy -RunRow $runRow -Connection $connection
        Assert-RunUsesR7C4SnapshotContract -RunRow $runRow
        Assert-RunUsesR7DBootstrapEvidence -Connection $connection

        if ($Apply -and
            ($SkipPreDeployment -or $SkipPostDeployment) -and
            -not (Test-DevTarget -RunRow $runRow -Connection $connection)) {
            throw "-SkipPreDeployment and -SkipPostDeployment are restricted to DEV apply diagnostics. QA, UAT and later-environment applies must execute the complete SCore schema lifecycle."
        }

        if ($SyncSource -or $VerifySource) {
            Assert-RunCanSynchronizeSource -RunRow $runRow
        }

        if ($planTable.Rows.Count -eq 0) {
            throw "The selected deployment plan is empty. Select deployable schema differences in CymBuild and save the selection before running deployment."
        }

        $script:planFingerprint = Get-CymBuildPlanFingerprint -PlanTable $planTable

        if ($SyncSource -or $VerifySource) {
            $unselectedPlanRows = @($planTable.Rows | Where-Object {
                -not [bool]$_["HasExplicitSelection"] -or -not [bool]$_["IsSelected"]
            })
            if ($unselectedPlanRows.Count -gt 0) {
                throw "Schema source synchronization requires an explicit saved selection and refuses any deployment-plan row that is not selected."
            }
        }

        $resolved = New-Object System.Collections.Generic.List[object]
        $unsupported = New-Object System.Collections.Generic.List[object]

        foreach ($row in $planTable.Rows) {
            $item = Resolve-DeploymentItem -Row $row
            [void]$resolved.Add($item)
            if (-not $item.IsSupported) {
                [void]$unsupported.Add($item)
            }
        }

        [object[]]$resolvedItems = $resolved.ToArray()
        [object[]]$unsupportedItems = $unsupported.ToArray()
        [object[]]$supported = @($resolvedItems | Where-Object { $_.IsSupported })
        [object[]]$materializedItems = @($resolvedItems | Where-Object { $_.WasMaterialized })

        if (-not $SyncSource -and $supported.Count -gt 0) {
            $sourceControlProof = Assert-CymBuildSelectedSourceControlState -SupportedItems $supported
            Write-Host "Selected source : $($sourceControlProof.FileCount) committed file(s) at $($sourceControlProof.Commit.Substring(0, 8))" -ForegroundColor Green
        }

        Write-PlanOutputs -RunRow $runRow -PlanTable $planTable -ResolvedItems $resolvedItems -UnsupportedItems $unsupportedItems
        $previewScriptPath = New-PreviewDeploymentScript -SupportedItems $supported

        Write-Host "CYB-361 R7D selected DEV source-sync and execution-hardened schema convergence runner" -ForegroundColor Cyan
        Write-Host "Repo root       : $RepoRoot"
        Write-Host "Target          : $TargetServer / $TargetDatabase"
        Write-Host "Run Guid        : $RunGuid"
        Write-Host "Plan rows       : $($planTable.Rows.Count)"
        Write-Host "Supported rows  : $($supported.Count)"
        Write-Host "Unsupported rows: $($unsupportedItems.Count)"
        Write-Host "Materialized SQL: $($materializedItems.Count)"
        Write-Host "Run output root : $runOutputRoot"
        Write-Host "Execution ID    : $executionId"
        Write-Host "Output folder   : $OutputDirectory"
        Write-Host "Preview SQL     : $previewScriptPath"

        if ($materializedItems.Count -gt 0) {
            Write-Host "Canonical source SQL was materialized from the accepted plan:" -ForegroundColor Green
            foreach ($materializedItem in $materializedItems) {
                $generatedFiles = @($materializedItem.MaterializedFiles)
                if ($generatedFiles.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$materializedItem.SourceFile)) {
                    $generatedFiles = @([string]$materializedItem.SourceFile)
                }
                foreach ($generatedFile in $generatedFiles) {
                    Write-Host "  $($materializedItem.ObjectType) $($materializedItem.SchemaName).$($materializedItem.ObjectName) -> $generatedFile" -ForegroundColor Green
                }
            }
            Write-Host "Review and commit the generated files through the normal source-control process." -ForegroundColor Yellow

            if ($Apply) {
                throw "The runner materialized new canonical source SQL during this apply attempt. No target deployment has started. Review the generated files, run -WhatIf, then re-run -Apply."
            }
        }

        if ($unsupportedItems.Count -gt 0) {
            Write-Host "Unsupported rows were found. See unsupported-items.csv." -ForegroundColor Yellow
            if (-not $AllowPartial) {
                throw "Deployment plan contains unsupported rows. Narrow the selection in CymBuild or re-run with -AllowPartial to deploy only supported rows."
            }
        }

        if ($supported.Count -eq 0) {
            throw "No supported source-controlled schema artefacts were resolved for this deployment plan."
        }

        if ($SyncSource -or $VerifySource) {
            $sourceSyncManifestPath = Write-SourceSyncManifest -RunRow $runRow -ResolvedItems $supported

            if ($SyncSource) {
                $gitExecutable = Get-CymBuildGitExecutable
                $syncCommitResult = Invoke-CymBuildGitCommand -GitExecutable $gitExecutable -Arguments @(
                    "-C", $RepoRoot, "rev-parse", "HEAD"
                )
                if ($syncCommitResult.ExitCode -ne 0 -or $syncCommitResult.Output.Count -ne 1) {
                    throw "The current source commit could not be resolved while stamping SourceSyncedOnUtc for run $RunGuid."
                }
                $syncCommit = $syncCommitResult.Output[0].Trim()
                $syncedOnUtc = [datetime]::UtcNow

                Invoke-SqlNonQuery -Connection $connection -Sql @"
UPDATE [SMigration].[Schema_Run]
SET
    [SourceSyncedOnUtc] = @SourceSyncedOnUtc,
    [SourceSyncCommit] = @SourceSyncCommit
WHERE [Guid] = @RunGuid
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;
"@ -Parameters @{
                    "@RunGuid" = $RunGuid
                    "@SourceSyncedOnUtc" = $syncedOnUtc
                    "@SourceSyncCommit" = $syncCommit
                }

                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualSourceSync" -StepStatus "Succeeded" -Message "Selected DEV schema source synchronized into source control." -Details @{
                    SourceSyncedOnUtc = $syncedOnUtc
                    SourceSyncCommit = $syncCommit
                }
            }

            $sourceAction = if ($SyncSource) { "synchronized" } else { "verified" }
            if ($AllowNonDevSource) {
                $sourceEnvironmentLabel = "$([string]$runRow["SourceEnvironment"]) / $([string]$runRow["SourceDatabaseName"])"
                Write-Host "Selected schema source $sourceAction successfully from a NON-DEV source ($sourceEnvironmentLabel) under -AllowNonDevSource." -ForegroundColor Yellow
            }
            else {
                Write-Host "Selected DEV schema source $sourceAction successfully." -ForegroundColor Green
            }
            Write-Host "Manifest        : $sourceSyncManifestPath"
            Write-Host "Target database was not preflighted or changed; review and commit the Database\CymBuild_DB diff before promotion." -ForegroundColor Yellow
            return
        }

        Assert-R7DExecutionInfrastructure -Connection $connection

        if ($Apply) {
            Acquire-CymBuildSchemaDeploymentLock -Connection $connection

            $lockedRunAndPlan = Get-RunAndPlan -Connection $connection
            Assert-RunCanDeploy -RunRow $lockedRunAndPlan.RunRow -Connection $connection
            $lockedPlanFingerprint = Get-CymBuildPlanFingerprint -PlanTable $lockedRunAndPlan.PlanTable
            if (-not $lockedPlanFingerprint.Equals($script:planFingerprint, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "The accepted selected deployment plan changed while R7D was acquiring the target apply lock. No deployment attempt or target DDL was started. Re-run WhatIf against the current accepted plan."
            }

            [void](Assert-CymBuildSelectedSourceControlState `
                -SupportedItems $supported `
                -ExpectedFingerprint $script:selectedSourceFingerprint)

            Start-CymBuildSchemaDeploymentAttempt -Connection $connection -ExpectedObjectCount $supported.Count
        }

        Assert-CymBuildTargetBaseline -Connection $connection -SupportedItems $supported -RecordCheckpoints ([bool]$Apply)

        Set-SchemaPreflightContext -Connection $connection -PreDeploymentWillRun (-not $SkipPreDeployment)

        $hasSelectedTableDeployment = @($supported | Where-Object { $_.ObjectType -eq "Table" -and -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) }).Count -gt 0
        $preflightedItemList = New-Object System.Collections.Generic.List[object]
        $deferredPreflightItemList = New-Object System.Collections.Generic.List[object]
        foreach ($item in $supported) {
            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"

            if ($Apply -and $item.SupportFiles.Count -gt 0) {
                $script:activeCheckpointItem = $item
                $script:activeCheckpointPhase = "Support"
            }
            foreach ($supportFile in $item.SupportFiles) {
                Write-Host "Preparing shared migration support for $objectLabel" -ForegroundColor DarkCyan
                $supportSql = Get-Content -LiteralPath $supportFile -Raw
                Invoke-SqlScriptText -Connection $connection -Sql $supportSql -Description "$objectLabel shared migration support" -TimeoutSeconds 600
            }
            if ($Apply -and $item.SupportFiles.Count -gt 0) {
                Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "Support" -Status "Succeeded" -Message "Shared migration support completed." -Details @{ SupportFiles = [string[]]$item.SupportFiles }
                $script:activeCheckpointItem = $null
                $script:activeCheckpointPhase = ""
            }

            if ([string]::IsNullOrWhiteSpace([string]$item.PreflightFile)) {
                continue
            }

            if ($hasSelectedTableDeployment -and $item.ObjectType -in @("Constraint", "Index")) {
                [void]$deferredPreflightItemList.Add($item)
                continue
            }

            Write-Host "Preflighting $objectLabel" -ForegroundColor Cyan
            $preflightSql = Get-Content -LiteralPath $item.PreflightFile -Raw
            if ($Apply) {
                $script:activeCheckpointItem = $item
                $script:activeCheckpointPhase = "Preflight"
            }
            Invoke-SqlScriptText -Connection $connection -Sql $preflightSql -Description "$objectLabel preflight" -TimeoutSeconds 600
            if ($Apply) {
                Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "Preflight" -Status "Succeeded" -Message "Source-controlled read-only preflight completed." -Details @{ PreflightFile = $item.PreflightFile }
                $script:activeCheckpointItem = $null
                $script:activeCheckpointPhase = ""
            }
            [void]$preflightedItemList.Add($item)
        }
        [object[]]$preflightedItems = $preflightedItemList.ToArray()
        [object[]]$deferredPreflightItems = $deferredPreflightItemList.ToArray()

        if ($WhatIf) {
            $materializationMessage = if ($materializedItems.Count -gt 0) { " Canonical source files were generated in the repository; review and commit them before promotion." } else { "" }
            $deferredMessage = if ($deferredPreflightItems.Count -gt 0) { " $($deferredPreflightItems.Count) constraint/index preflight(s) are intentionally deferred until after the selected table convergence during apply." } else { "" }
            $baselineMessage = if ($RetryFailedDeployment) {
                "matched an immutable accepted target/source state, allowing only the controlled Function/View WITH SCHEMABINDING lifecycle normalization"
            }
            else {
                "matched the accepted TargetHash values"
            }
            Write-Host "Dry-run only. The selected target baseline was re-snapshotted and $baselineMessage. Read-only target preflights completed, including eligibility validation for schema-bound dependencies scheduled for SCore.PreDeploymentScript;$deferredMessage no target schema, data, or SMigration audit rows were changed.$materializationMessage Re-run with -Apply to deploy." -ForegroundColor Yellow
            return
        }

        Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentRunner" -StepStatus "Started" -Message "Manual source-controlled schema deployment runner started." -Details @{
            TargetServer = $TargetServer
            TargetDatabase = $TargetDatabase
            ReleaseReference = $ReleaseReference
            DeploymentReference = $DeploymentReference
            PlanCount = $planTable.Rows.Count
            SupportedCount = $supported.Count
            UnsupportedCount = $unsupportedItems.Count
            MaterializedSourceCount = $materializedItems.Count
            AllowPartial = [bool]$AllowPartial
            RetryFailedDeployment = [bool]$RetryFailedDeployment
            AttemptGuid = $script:deploymentAttemptGuid
            AttemptNumber = $script:deploymentAttemptNumber
            PlanFingerprint = $script:planFingerprint
            SourceCommit = $script:sourceCommit
            SelectedSourceFingerprint = $script:selectedSourceFingerprint
            LockResource = $script:deploymentLockResource
        }

        foreach ($unsupportedItem in $unsupportedItems) {
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Skipped" -Message "$($unsupportedItem.ObjectType) $($unsupportedItem.SchemaName).$($unsupportedItem.ObjectName) is unsupported by the current manual runner and was skipped under -AllowPartial." -Details $unsupportedItem
        }

        foreach ($item in $preflightedItems) {
            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPreflight" -StepStatus "Succeeded" -Message "$objectLabel source-controlled preflight completed." -Details @{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                DifferenceType = $item.DifferenceType
                DeploymentMode = $item.DeploymentMode
                PreflightFile = $item.PreflightFile
                SupportFiles = [string[]]$item.SupportFiles
            }
        }

        if (-not $SkipPreDeployment) {
            Write-Host "Running SCore.PreDeploymentScript..." -ForegroundColor Cyan
            Invoke-SqlScriptText -Connection $connection -Sql (Get-CymBuildLifecycleLockedSql -Sql "EXEC [SCore].[PreDeploymentScript];") -Description "SCore.PreDeploymentScript" -TimeoutSeconds 1800
            $preDeploymentCompleted = $true
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPre" -StepStatus "Succeeded" -Message "SCore.PreDeploymentScript completed on the target database." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
            }

            Set-SchemaPreflightContext -Connection $connection -PreDeploymentWillRun $false

            foreach ($item in $preflightedItems) {
                $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"
                Write-Host "Re-preflighting $objectLabel after SCore.PreDeploymentScript" -ForegroundColor Cyan
                $strictPreflightSql = Get-Content -LiteralPath $item.PreflightFile -Raw
                $script:activeCheckpointItem = $item
                $script:activeCheckpointPhase = "PostPreflight"
                Invoke-SqlScriptText -Connection $connection -Sql $strictPreflightSql -Description "$objectLabel strict post-pre-deployment preflight" -TimeoutSeconds 600

                Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "PostPreflight" -Status "Succeeded" -Message "Strict preflight completed after SCore.PreDeploymentScript." -Details @{ PreflightFile = $item.PreflightFile }
                $script:activeCheckpointItem = $null
                $script:activeCheckpointPhase = ""

                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPostPreflight" -StepStatus "Succeeded" -Message "$objectLabel strict preflight confirmed that managed schema-bound dependencies were removed." -Details @{
                    ComparisonGuid = $item.ComparisonGuid
                    ObjectType = $item.ObjectType
                    SchemaName = $item.SchemaName
                    ObjectName = $item.ObjectName
                    PreflightFile = $item.PreflightFile
                }
            }
        }

        $appliedObjectKeys = @{}

        foreach ($item in @(
            $supported |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.PrepareFile) } |
                Sort-Object @{ Expression = {
                    if ($_.ObjectType -eq "Index") { return 5 }
                    switch ($_.ConstraintKind) {
                        "FOREIGN_KEY" { 10 }
                        "CHECK" { 20 }
                        "DEFAULT" { 20 }
                        "UNIQUE" { 30 }
                        "PRIMARY_KEY" { 30 }
                        default { 50 }
                    }
                } }, SchemaName, ParentObjectName, ObjectName
        )) {
            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ParentObjectName).$($item.ObjectName)"
            Write-Host "Preparing $objectLabel" -ForegroundColor Cyan
            $prepareSql = Get-Content -LiteralPath $item.PrepareFile -Raw
            $script:activeCheckpointItem = $item
            $script:activeCheckpointPhase = "Prepare"
            Invoke-SqlScriptText -Connection $connection -Sql $prepareSql -Description "$objectLabel prepare" -TimeoutSeconds 1800
            $itemKey = "$($item.ObjectType)|$($item.SchemaName)|$($item.ParentObjectName)|$($item.ObjectName)"
            $appliedObjectKeys[$itemKey] = $true

            Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "Prepare" -Status "Succeeded" -Message "Target preparation applied from source-controlled SQL." -Details @{ PrepareFile = $item.PrepareFile }
            $script:activeCheckpointItem = $null
            $script:activeCheckpointPhase = ""

            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPrepare" -StepStatus "Applied" -Message "$objectLabel target preparation applied from source-controlled SQL." -Details @{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                ParentObjectName = $item.ParentObjectName
                DifferenceType = $item.DifferenceType
                DeploymentMode = $item.DeploymentMode
                PrepareFile = $item.PrepareFile
                ConstraintKind = $item.ConstraintKind
            }
        }

        $orderedApplyItems = @(Get-CymBuildOrderedApplyItems -Items $supported)

        $deferredPreflightsCompleted = $deferredPreflightItems.Count -eq 0
        foreach ($item in $orderedApplyItems) {
            if (-not $deferredPreflightsCompleted -and $item.ObjectType -in @("Index", "Constraint")) {
                foreach ($deferredItem in $deferredPreflightItems) {
                    $deferredLabel = "$($deferredItem.ObjectType) $($deferredItem.SchemaName).$($deferredItem.ObjectName)"
                    Write-Host "Post-structure preflighting $deferredLabel" -ForegroundColor Cyan
                    $deferredSql = Get-Content -LiteralPath $deferredItem.PreflightFile -Raw
                    $script:activeCheckpointItem = $deferredItem
                    $script:activeCheckpointPhase = "Preflight"
                    Invoke-SqlScriptText -Connection $connection -Sql $deferredSql -Description "$deferredLabel post-structure preflight" -TimeoutSeconds 600
                    Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $deferredItem -Phase "Preflight" -Status "Succeeded" -Message "Deferred source-controlled preflight completed after table convergence." -Details @{ PreflightFile = $deferredItem.PreflightFile }
                    $script:activeCheckpointItem = $null
                    $script:activeCheckpointPhase = ""
                    Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPostStructurePreflight" -StepStatus "Succeeded" -Message "$deferredLabel source-controlled preflight completed after table convergence." -Details @{
                        ComparisonGuid = $deferredItem.ComparisonGuid
                        ObjectType = $deferredItem.ObjectType
                        SchemaName = $deferredItem.SchemaName
                        ObjectName = $deferredItem.ObjectName
                        DifferenceType = $deferredItem.DifferenceType
                        DeploymentMode = $deferredItem.DeploymentMode
                        PreflightFile = $deferredItem.PreflightFile
                    }
                }
                $deferredPreflightsCompleted = $true
            }

            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"
            Write-Host "Deploying $objectLabel" -ForegroundColor Cyan

            if ($item.DeploymentMode -eq "CanonicalCreate" -and
                (Test-SqlObjectExists -Connection $connection -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName)) {
                Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "Apply" -Status "Skipped" -Message "Canonical create was not attempted because the object already exists; verification remains mandatory." -Details @{ DeploymentMode = $item.DeploymentMode }
                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Skipped" -Message "$objectLabel already exists. Non-destructive recreate was not attempted." -Details $item
                continue
            }

            $sql = Get-Content -LiteralPath $item.SourceFile -Raw
            $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
            $script:activeCheckpointItem = $item
            $script:activeCheckpointPhase = "Apply"
            Invoke-SqlScriptText -Connection $connection -Sql $sql -Description $objectLabel -TimeoutSeconds 1800
            $itemKey = "$($item.ObjectType)|$($item.SchemaName)|$($item.ParentObjectName)|$($item.ObjectName)"
            $appliedObjectKeys[$itemKey] = $true

            Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $item -Phase "Apply" -Status "Succeeded" -ExpectedHash ([string]$item.SourceHash) -Message "Selected object SQL applied from the committed canonical source file." -Details @{ SourceFile = $item.SourceFile; DeploymentMode = $item.DeploymentMode }
            $script:activeCheckpointItem = $null
            $script:activeCheckpointPhase = ""

            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Applied" -Message "$objectLabel applied from source-controlled SQL." -Details @{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                ParentObjectName = $item.ParentObjectName
                DifferenceType = $item.DifferenceType
                DeploymentMode = $item.DeploymentMode
                SourceFile = $item.SourceFile
                PrepareFile = $item.PrepareFile
                PreflightFile = $item.PreflightFile
                SupportFiles = [string[]]$item.SupportFiles
                ConstraintKind = $item.ConstraintKind
            }
        }

        $appliedCount = $appliedObjectKeys.Count

        Assert-CymBuildAppliedSourceVerification -Connection $connection -SupportedItems $supported

        if (-not $SkipPostDeployment -and -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Running SCore.PostDeploymentScript..." -ForegroundColor Cyan
            $postDeploymentRunGuid = [Guid]::NewGuid()
            $postDeploymentInvoked = $true
            $postDeploymentSql = "DECLARE @CymBuildPostDeploymentRunGuid uniqueidentifier = N'$($postDeploymentRunGuid.ToString())'; EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;"
            Invoke-SqlScriptText -Connection $connection -Sql (Get-CymBuildLifecycleLockedSql -Sql $postDeploymentSql) -Description "SCore.PostDeploymentScript strict lifecycle" -TimeoutSeconds 1800
            $postDeploymentCompleted = $true
            $postDeploymentIssueEvidencePath = Write-CymBuildPostDeploymentIssueEvidence `
                -Connection $connection `
                -PostDeploymentRunGuid $postDeploymentRunGuid
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPost" -StepStatus "Succeeded" -Message "SCore.PostDeploymentScript completed on the target database." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
                PostDeploymentRunGuid = $postDeploymentRunGuid
                PostDeploymentIssueEvidencePath = $postDeploymentIssueEvidencePath
            }

            Invoke-CymBuildSelectedPostDeploymentReapply -Connection $connection -SupportedItems $supported
        }
        elseif ($TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPost" -StepStatus "Skipped" -Message "SCore.PostDeploymentScript skipped because target is CymBuild_Dev." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
            }
        }

        Assert-CymBuildPostDeploymentVerification -Connection $connection -SupportedItems $supported

        $finalStatus = "DeploymentApplied"
        $note = "R7D schema deployment applied $appliedCount source-controlled operation(s) and verified $($supported.Count) selected object(s) against immutable accepted source definitions, allowing only the controlled Function/View WITH SCHEMABINDING lifecycle normalization."

        Invoke-SqlNonQuery -Connection $connection -Sql @"
UPDATE [SMigration].[Schema_Run]
SET
    [RunStatus] = @RunStatus,
    [AppliedOnUtc] = SYSUTCDATETIME(),
    [DeploymentReference] = @DeploymentReference,
    [ReleaseReference] = CASE WHEN LEN(@ReleaseReference) > 0 THEN @ReleaseReference ELSE [ReleaseReference] END,
    [Notes] = LEFT(CONCAT(ISNULL([Notes], N''), CHAR(13), CHAR(10), @Note), 2000)
WHERE [Guid] = @RunGuid
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;
"@ -Parameters @{
            "@RunGuid" = $RunGuid
            "@RunStatus" = $finalStatus
            "@DeploymentReference" = $DeploymentReference
            "@ReleaseReference" = $ReleaseReference
            "@Note" = $note
        }

        Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentRunner" -StepStatus "Succeeded" -Message $note -Details @{
            AppliedCount = $appliedCount
            UnsupportedCount = $unsupportedItems.Count
            RunStatus = $finalStatus
            OutputDirectory = $OutputDirectory
            AttemptGuid = $script:deploymentAttemptGuid
            AttemptNumber = $script:deploymentAttemptNumber
            VerifiedCount = $supported.Count
            SourceCommit = $script:sourceCommit
            SelectedSourceFingerprint = $script:selectedSourceFingerprint
            PostDeploymentRunGuid = $postDeploymentRunGuid
        }

        Complete-CymBuildSchemaDeploymentAttempt -Connection $connection -Status "Succeeded" -Summary @{
            AppliedCount = $appliedCount
            VerifiedCount = $supported.Count
            RunStatus = $finalStatus
            OutputDirectory = $OutputDirectory
            PlanFingerprint = $script:planFingerprint
            SourceCommit = $script:sourceCommit
            SelectedSourceFingerprint = $script:selectedSourceFingerprint
            PostDeploymentRunGuid = $postDeploymentRunGuid
        }

        Write-Host "Schema deployment completed. Applied $appliedCount operation(s), verified $($supported.Count) selected object(s). Status: $finalStatus" -ForegroundColor Green
    }
    catch {
        $deploymentError = $_
        $failureMessage = $deploymentError.Exception.Message
        $recoveryAttempted = $false
        $recoverySucceeded = $false
        $recoveryError = ""

        if ($Apply -and
            $postDeploymentInvoked -and
            -not $postDeploymentCompleted -and
            $postDeploymentRunGuid -ne [Guid]::Empty -and
            $null -ne $connection -and
            $connection.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $postDeploymentIssueEvidencePath = Write-CymBuildPostDeploymentIssueEvidence `
                    -Connection $connection `
                    -PostDeploymentRunGuid $postDeploymentRunGuid
                Write-Warning "Strict SCore.PostDeploymentScript reported lifecycle errors. It will not be invoked a second time automatically. Evidence: $postDeploymentIssueEvidencePath"
            }
            catch {
                Write-Warning "Strict post-deployment issue evidence could not be exported: $($_.Exception.Message)"
            }
        }

        if ($SyncSource -and $sourceSyncBackups.Count -gt 0) {
            try {
                Restore-CymBuildSourceSyncFiles
            }
            catch {
                throw "Schema source synchronization failed: $failureMessage Rollback also failed: $($_.Exception.Message)"
            }
            Write-Warning "Schema source synchronization failed. Every schema source file written by this invocation was restored."
        }

        if ($Apply -and
            $preDeploymentCompleted -and
            -not $postDeploymentCompleted -and
            -not $postDeploymentInvoked -and
            -not $SkipPostDeployment -and
            -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase) -and
            $null -ne $connection -and
            $connection.State -eq [System.Data.ConnectionState]::Open) {
            $recoveryAttempted = $true
            Write-Warning "Deployment failed after SCore.PreDeploymentScript. Attempting SCore.PostDeploymentScript recovery before returning the original error."

            try {
                $recoveryPostDeploymentRunGuid = [Guid]::NewGuid()
                $recoveryPostDeploymentSql = "DECLARE @CymBuildRecoveryPostDeploymentRunGuid uniqueidentifier = N'$($recoveryPostDeploymentRunGuid.ToString())'; EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 0, @RunGuid = @CymBuildRecoveryPostDeploymentRunGuid;"
                Invoke-SqlScriptText -Connection $connection -Sql (Get-CymBuildLifecycleLockedSql -Sql $recoveryPostDeploymentSql) -Description "SCore.PostDeploymentScript failure recovery" -TimeoutSeconds 1800
                $postDeploymentCompleted = $true
                $recoverySucceeded = $true
            }
            catch {
                $recoveryError = $_.Exception.Message
                Write-Warning "SCore.PostDeploymentScript failure recovery did not complete: $recoveryError"
            }

            if ($recoverySucceeded -and $deploymentAuditStarted) {
                try {
                    Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentRecovery" -StepStatus "Succeeded" -Message "SCore.PostDeploymentScript completed as failure recovery after deployment stopped." -Details @{
                        OriginalError = $failureMessage
                        TargetServer = $TargetServer
                        TargetDatabase = $TargetDatabase
                        PostDeploymentRunGuid = $recoveryPostDeploymentRunGuid
                    }
                }
                catch {
                    Write-Warning "Post-deployment recovery completed, but its dedicated audit row could not be written: $($_.Exception.Message)"
                }
            }
        }

        if ($Apply -and
            $script:deploymentAttemptGuid -ne [Guid]::Empty -and
            $null -ne $connection -and
            $connection.State -eq [System.Data.ConnectionState]::Open) {
            if ($null -ne $script:activeCheckpointItem -and
                -not [string]::IsNullOrWhiteSpace($script:activeCheckpointPhase)) {
                try {
                    Set-CymBuildSchemaObjectCheckpoint -Connection $connection -Item $script:activeCheckpointItem -Phase $script:activeCheckpointPhase -Status "Failed" -Message $failureMessage -Details @{ Error = $failureMessage; ExecutionId = $executionId }
                }
                catch {
                    Write-Warning "Failed to persist the active R7D object checkpoint: $($_.Exception.Message)"
                }
                finally {
                    $script:activeCheckpointItem = $null
                    $script:activeCheckpointPhase = ""
                }
            }

            try {
                Complete-CymBuildSchemaDeploymentAttempt -Connection $connection -Status "Failed" -FailureMessage $failureMessage -Summary @{
                    Error = $failureMessage
                    PreDeploymentCompleted = $preDeploymentCompleted
                    RecoveryAttempted = $recoveryAttempted
                    RecoverySucceeded = $recoverySucceeded
                    RecoveryError = $recoveryError
                    PlanFingerprint = $script:planFingerprint
                    SourceCommit = $script:sourceCommit
                    SelectedSourceFingerprint = $script:selectedSourceFingerprint
                    PostDeploymentRunGuid = $postDeploymentRunGuid
                    PostDeploymentIssueEvidencePath = $postDeploymentIssueEvidencePath
                    OutputDirectory = $OutputDirectory
                }
            }
            catch {
                Write-Warning "Failed to complete the R7D deployment-attempt row: $($_.Exception.Message)"
            }
        }

        try {
            if ($Apply -and $deploymentAuditStarted -and $null -ne $connection -and $connection.State -eq [System.Data.ConnectionState]::Open) {
                Invoke-SqlNonQuery -Connection $connection -Sql @"
UPDATE [SMigration].[Schema_Run]
SET
    [RunStatus] = N'DeploymentFailed',
    [Notes] = LEFT(CONCAT(ISNULL([Notes], N''), CHAR(13), CHAR(10), N'Manual deployment failed: ', @FailureMessage), 2000)
WHERE [Guid] = @RunGuid
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;
"@ -Parameters @{
                    "@RunGuid" = $RunGuid
                    "@FailureMessage" = $failureMessage
                }

                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentRunner" -StepStatus "Failed" -Message "Manual source-controlled schema deployment runner failed." -Details @{
                    Error = $failureMessage
                    TargetServer = $TargetServer
                    TargetDatabase = $TargetDatabase
                    AuditStarted = $deploymentAuditStarted
                    PreDeploymentCompleted = $preDeploymentCompleted
                    RecoveryAttempted = $recoveryAttempted
                    RecoverySucceeded = $recoverySucceeded
                    RecoveryError = $recoveryError
                    SourceCommit = $script:sourceCommit
                    SelectedSourceFingerprint = $script:selectedSourceFingerprint
                    PostDeploymentRunGuid = $postDeploymentRunGuid
                    PostDeploymentIssueEvidencePath = $postDeploymentIssueEvidencePath
                }
            }
        }
        catch {
            Write-Warning "Failed to write SMigration execution state after deployment failure: $($_.Exception.Message)"
        }

        throw $deploymentError
    }
    finally {
        if ($script:deploymentLockAcquired -and
            $null -ne $connection -and
            $connection.State -eq [System.Data.ConnectionState]::Open) {
            try {
                Release-CymBuildSchemaDeploymentLock -Connection $connection
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

Invoke-CymBuildSchemaDeployment
