<#
.SYNOPSIS
    CYB-361 R41 declarative schema convergence runner.

.DESCRIPTION
    Reads an accepted SMigration schema deployment plan from the target database and applies the
    corresponding source-controlled SQL artefacts from the repository. When an accepted Function,
    View, StoredProcedure, Trigger, Constraint, existing Table or Index is missing its canonical
    repository file, the dry-run can materialize reviewed idempotent SQL from the accepted
    declarative snapshot.

    This is the manual version of the future release-pipeline step. It never executes captured DDL
    directly. Materialized definitions are written under Database/CymBuild_DB/Schema first, become
    reviewable source artefacts, and must be committed through the normal source-control process.

    Default behaviour is dry-run. Use -Apply to execute.
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
    [string]$OutputDirectory = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$deploymentAuditStarted = $false

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

if ([string]::IsNullOrWhiteSpace($DeploymentReference)) {
    if ([string]::IsNullOrWhiteSpace($ReleaseReference)) {
        $DeploymentReference = "ManualSchemaDeployment-$($RunGuid.ToString())"
    }
    else {
        $DeploymentReference = $ReleaseReference
    }
}

$outputDirectoryWasExplicit = -not [string]::IsNullOrWhiteSpace($OutputDirectory)
$executionMode = if ($Apply) { "apply" } else { "whatif" }
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
            ExpectedSourceHash = "6BB3BF24C7B4A3991239D04BD8F0726389DCDE6AE5BC4E0B71FBFB5B5FF9751C"
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
            return [regex]::Replace($sqlText, '(?im)^(\s*)CREATE\s+FUNCTION\b', '$1CREATE OR ALTER FUNCTION', 1)
        }
        "View" {
            return [regex]::Replace($sqlText, '(?im)^(\s*)CREATE\s+VIEW\b', '$1CREATE OR ALTER VIEW', 1)
        }
        "StoredProcedure" {
            $converted = [regex]::Replace($sqlText, '(?im)^(\s*)CREATE\s+PROCEDURE\b', '$1CREATE OR ALTER PROCEDURE', 1)
            if ($converted -eq $sqlText) {
                $converted = [regex]::Replace($sqlText, '(?im)^(\s*)CREATE\s+PROC\b', '$1CREATE OR ALTER PROC', 1)
            }
            return $converted
        }
        "Trigger" {
            return [regex]::Replace($sqlText, '(?im)^(\s*)CREATE\s+TRIGGER\b', '$1CREATE OR ALTER TRIGGER', 1)
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

    if ($null -eq $Row -or
        -not $Row.Table.Columns.Contains($ColumnName) -or
        $Row[$ColumnName] -eq [DBNull]::Value) {
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

    if ($null -eq $InputObject -or -not ($InputObject.PSObject.Properties.Name -contains $PropertyName)) {
        if ($Required) {
            throw "Constraint definition property '$PropertyName' is required."
        }

        return $null
    }

    $value = $InputObject.$PropertyName
    if ($Required -and ($null -eq $value -or ([string]$value).Length -eq 0)) {
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

    $generatedUtc = [DateTime]::UtcNow.ToString("O")
    return @"
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R41 schema deployment runner
    Run Guid           : $RunGuid
    Comparison Guid    : $ComparisonGuid
    Object             : $ObjectDescription
    Difference         : $DifferenceType
    Comparison hash    : $ComparisonHash
    Definition SHA-256 : $DefinitionSha256
    Purpose            : $Purpose
    Generated UTC      : $generatedUtc

    This file was generated from the accepted declarative schema snapshot. Review and commit it
    through the normal source-control process before promoting the release. It is never executed
    directly from captured database DDL.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

"@
}

function Write-CymBuildConstraintGeneratedFile {
    param(
        [string]$Path,
        [string]$Content,
        [string]$DefinitionSha256,
        [bool]$AllowCreate
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existingContent = Get-Content -LiteralPath $Path -Raw
        $isGeneratedFile = $existingContent.Contains("CymBuild generated canonical schema source.")
        if (-not $isGeneratedFile) {
            return $false
        }

        if ($existingContent.Contains("Definition SHA-256 : $DefinitionSha256")) {
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
        [bool]$AllowCreate = $true
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
        $constraintIdentifier = Quote-CymBuildSqlIdentifier -Value $objectName
        $constraintNameLiteral = Quote-CymBuildSqlStringLiteral -Value $objectName
        $objectDescription = "Constraint $schemaName.$parentObjectName.$objectName"
        $requiredFiles = New-Object System.Collections.Generic.List[string]
        $createdFiles = New-Object System.Collections.Generic.List[string]

        $constraintExistsPredicate = @"
EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID($tableNameLiteral, N'U')
      AND constraintObject.name = $constraintNameLiteral
)
"@

        if ($differenceType -in @("Different", "MissingInSource")) {
            $prepareHeader = New-CymBuildGeneratedSchemaHeader `
                -ObjectDescription $objectDescription `
                -ComparisonGuid $comparisonGuid `
                -DifferenceType $differenceType `
                -ComparisonHash $comparisonHash `
                -DefinitionSha256 $definitionSha256 `
                -Purpose "Prepare phase: remove the target constraint before structural deployment."
            $prepareSql = @"
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
            [void]$requiredFiles.Add($paths.PrepareFile)
            $prepareContent = $prepareHeader + $prepareSql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PrepareFile -Content $prepareContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) {
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
                    $parentColumnName = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "ParentColumnName" -Required)
                    $defaultDefinition = [string](Get-CymBuildObjectProperty -InputObject $payload -PropertyName "DefaultDefinition" -Required)
                    if ([regex]::IsMatch($defaultDefinition, '(?im)^\s*(?:GO|USE\s+)')) { throw "Default constraint definition contains a forbidden batch or database-context statement." }
                    [void]$preflightLines.Add("IF COL_LENGTH($tableNameLiteral, $(Quote-CymBuildSqlStringLiteral -Value $parentColumnName)) IS NULL")
                    [void]$preflightLines.Add("    THROW 51404, 'Default-constraint column $schemaName.$parentObjectName.$parentColumnName does not exist.', 1;")
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
                    if ($fillFactor -gt 0) {
                        if ($fillFactor -gt 100) { throw "Constraint fill factor must be between 1 and 100." }
                        [void]$options.Add("FILLFACTOR = $fillFactor")
                    }
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
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) {
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
"@
            [void]$requiredFiles.Add($paths.ApplyFile)
            $applyContent = $applyHeader + $applySql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) {
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
        $declaration += " COLLATE $(Quote-CymBuildSqlIdentifier -Value $collationName)"
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
        [bool]$AllowCreate = $true
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
                    if ([string]::IsNullOrWhiteSpace($sourceDefaultName)) { $sourceDefaultName = "DF_${tableName}_${columnName}" }
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
                if (-not [string]::IsNullOrWhiteSpace($targetDefaultName)) {
                    [void]$apply.Add("    IF OBJECT_ID($(Quote-CymBuildSqlStringLiteral -Value "[$schemaName].[$targetDefaultName]"), N'D') IS NOT NULL ALTER TABLE $tableIdentifier DROP CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $targetDefaultName);")
                }
                $sourceNullable = ConvertTo-CymBuildBoolean -Value (Get-CymBuildObjectProperty -InputObject $sourceColumn -PropertyName "IsNullable")
                if (-not $sourceNullable) {
                    [void]$apply.Add("    UPDATE $tableIdentifier SET $columnIdentifier = $(Get-CymBuildBackfillExpression -Column $sourceColumn) WHERE $columnIdentifier IS NULL;")
                }
                [void]$apply.Add("    ALTER TABLE $tableIdentifier ALTER COLUMN $(Get-CymBuildColumnDeclarationSql -Column $sourceColumn -ForAlter);")
                $defaultDiffers = $true
            }

            if ($defaultDiffers) {
                if (-not $requiresAlter -and -not [string]::IsNullOrWhiteSpace($targetDefaultName)) {
                    [void]$apply.Add("    IF OBJECT_ID($(Quote-CymBuildSqlStringLiteral -Value "[$schemaName].[$targetDefaultName]"), N'D') IS NOT NULL ALTER TABLE $tableIdentifier DROP CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $targetDefaultName);")
                }
                if (-not [string]::IsNullOrWhiteSpace($sourceDefaultDefinition)) {
                    if (Test-CymBuildForbiddenSqlFragment -Value $sourceDefaultDefinition) { throw "Column '$columnName' has an invalid source default." }
                    if ([string]::IsNullOrWhiteSpace($sourceDefaultName)) { $sourceDefaultName = "DF_${tableName}_${columnName}" }
                    [void]$apply.Add("    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID($tableLiteral, N'U') AND c.name = $columnLiteral) ALTER TABLE $tableIdentifier ADD CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $sourceDefaultName) DEFAULT $sourceDefaultDefinition FOR $columnIdentifier;")
                }
            }
        }

        foreach ($targetColumn in $targetColumns) {
            $columnName = Get-CymBuildPropertyText -InputObject $targetColumn -PropertyName "ColumnName"
            if ($sourceByName.ContainsKey($columnName)) { continue }
            $columnIdentifier = Quote-CymBuildSqlIdentifier -Value $columnName
            $columnLiteral = Quote-CymBuildSqlStringLiteral -Value $columnName
            $targetDefaultName = Get-CymBuildPropertyText -InputObject $targetColumn -PropertyName "DefaultConstraintName"
            if (-not [string]::IsNullOrWhiteSpace($targetDefaultName)) {
                [void]$apply.Add("    IF OBJECT_ID($(Quote-CymBuildSqlStringLiteral -Value "[$schemaName].[$targetDefaultName]"), N'D') IS NOT NULL ALTER TABLE $tableIdentifier DROP CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $targetDefaultName);")
            }
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
        if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) { [void]$createdFiles.Add($paths.PreflightFile) }
        if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) { [void]$createdFiles.Add($paths.ApplyFile) }
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

function New-MaterializedIndexSourceFiles {
    param(
        [System.Data.DataRow]$Row,
        [bool]$AllowCreate = $true
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
            $prepareSql = @"
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
            $prepareContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Prepare phase: remove the selected target index.") + $prepareSql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PrepareFile -Content $prepareContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) { [void]$createdFiles.Add($paths.PrepareFile) }
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
                [void]$preflight.Add("IF DATA_SPACE_ID($(Quote-CymBuildSqlStringLiteral -Value $dataSpaceName)) IS NULL THROW 51432, 'Index data space does not exist in the target.', 1;")
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
            if ($fillFactor -gt 0) { [void]$options.Add("FILLFACTOR = $fillFactor") }
            [void]$options.Add("IGNORE_DUP_KEY = $(if (ConvertTo-CymBuildBoolean -Value $payload.IgnoreDuplicateKey) { 'ON' } else { 'OFF' })")
            [void]$options.Add("ALLOW_ROW_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value $payload.AllowRowLocks) { 'ON' } else { 'OFF' })")
            [void]$options.Add("ALLOW_PAGE_LOCKS = $(if (ConvertTo-CymBuildBoolean -Value $payload.AllowPageLocks) { 'ON' } else { 'OFF' })")
            if ($compression -ne "NONE") { [void]$options.Add("DATA_COMPRESSION = $compression") }
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
            $applySql = @"
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
            $preflightContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Read-only preflight for the selected index operation.") + ([string]::Join("`r`n", $preflight)) + "`r`nGO`r`n"
            $applyContent = (New-CymBuildGeneratedSchemaHeader @headerArguments -Purpose "Finalize phase: create the source index from the declarative snapshot.") + $applySql + "`r`nGO`r`n"
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.PreflightFile -Content $preflightContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) { [void]$createdFiles.Add($paths.PreflightFile) }
            if (Write-CymBuildConstraintGeneratedFile -Path $paths.ApplyFile -Content $applyContent -DefinitionSha256 $definitionSha256 -AllowCreate $AllowCreate) { [void]$createdFiles.Add($paths.ApplyFile) }
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


function New-MaterializedSchemaSourceFile {
    param(
        [System.Data.DataRow]$Row,
        [string]$DestinationPath
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

    $canonicalSql = Convert-SchemaScriptForDeployment `
        -Sql $sourceDefinition `
        -ObjectType $objectType `
        -SchemaName $schemaName `
        -ObjectName $objectName `
        -DifferenceType $differenceType

    $headerText = [regex]::Replace($canonicalSql, '\[([^\]]+)\]', '$1')
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
        '(?i)\bCREATE\s+OR\s+ALTER\s+' +
        $kindPattern +
        '\s+' +
        [regex]::Escape($schemaName) +
        '\s*\.\s*' +
        [regex]::Escape($objectName) +
        '(?:\s|\(|$)'
    )

    if (-not [regex]::IsMatch($headerText, $identityPattern)) {
        $result.Reason = "The captured source definition does not declare the expected $objectType '$schemaName.$objectName' using CREATE OR ALTER."
        return [pscustomobject]$result
    }

    if (-not (Test-ApprovedSchemaSourcePath -Path $DestinationPath)) {
        $result.Reason = "The materialized source path is outside Database/CymBuild_DB/Schema."
        return [pscustomobject]$result
    }

    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        $result.Succeeded = $true
        $result.Reason = "The canonical source file was created by another process before materialization completed."
        return [pscustomobject]$result
    }

    $definitionSha256 = Get-TextSha256 -Text $sourceDefinition
    $generatedUtc = [DateTime]::UtcNow.ToString("O")
    $header = @"
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R41 schema deployment runner
    Run Guid           : $RunGuid
    Comparison Guid    : $comparisonGuid
    Object             : $objectType $schemaName.$objectName
    Difference         : $differenceType
    Comparison hash    : $sourceHash
    Definition SHA-256 : $definitionSha256
    Generated UTC      : $generatedUtc

    This file was materialized from the accepted source-definition snapshot. Review and commit it
    through the normal source-control process before promoting the release beyond the controlled
    environment in which it was generated.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

"@

    $fileContent = $header + $canonicalSql.Trim() + "`r`nGO`r`n"
    $destinationDirectory = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

    $temporaryPath = "$DestinationPath.tmp.$([Guid]::NewGuid().ToString('N'))"
    $utf8WithBom = [System.Text.UTF8Encoding]::new($true)

    try {
        [System.IO.File]::WriteAllText($temporaryPath, $fileContent, $utf8WithBom)

        if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
            $result.Succeeded = $true
            $result.Reason = "The canonical source file was created by another process before materialization completed."
            return [pscustomobject]$result
        }

        Move-Item -LiteralPath $temporaryPath -Destination $DestinationPath
        $result.Succeeded = $true
        $result.WasCreated = $true
        $result.DefinitionSha256 = $definitionSha256
        $result.Reason = "Canonical source SQL was materialized from the accepted source-definition snapshot."
        return [pscustomobject]$result
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
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
        $constraintMaterialization = New-MaterializedConstraintSourceFiles -Row $Row -AllowCreate (-not $SkipSourceMaterialization)
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
        $indexMaterialization = New-MaterializedIndexSourceFiles -Row $Row -AllowCreate (-not $SkipSourceMaterialization)
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
        $tableMaterialization = New-MaterializedTableSourceFiles -Row $Row -AllowCreate (-not $SkipSourceMaterialization)
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

    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        if (-not $SkipSourceMaterialization -and (Test-CanMaterializeProgrammableObject -ObjectType $objectType)) {
            $materialization = New-MaterializedSchemaSourceFile -Row $Row -DestinationPath $sourceFile
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
    sr.RowStatus
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

    if (-not $SkipAcceptanceCheck -and
        (-not [bool]$RunRow["IsReviewed"] -or
         (-not $isReviewedRun -and -not $isApprovedFailedRetry))) {
        throw "Run $RunGuid is not in an accepted deployable state. Validate and accept the current plan in CymBuild, or use -RetryFailedDeployment only to resume an unchanged reviewed run whose status is DeploymentFailed."
    }

    if ($SkipAcceptanceCheck -and $Apply -and -not (Test-DevTarget -RunRow $RunRow -Connection $Connection)) {
        throw "-SkipAcceptanceCheck is restricted to DEV apply diagnostics."
    }

    $isLiveTarget =
        (Test-LiveTargetName -EnvironmentName ([string]$RunRow["TargetEnvironment"]) -ServerName $runTargetServer -DatabaseName $runTargetDatabase) -or
        (Test-LiveTargetName -EnvironmentName "" -ServerName $TargetServer -DatabaseName $TargetDatabase) -or
        (Test-LiveTargetName -EnvironmentName "" -ServerName $actualTargetServer -DatabaseName $actualTargetDatabase)

    if ($Apply -and $isLiveTarget -and -not $AllowLive) {
        throw "Target appears to be LIVE/production. Re-run with -AllowLive only under the approved LIVE release procedure."
    }
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
        RunGuid = $RunGuid.ToString()
        TargetServer = $TargetServer
        TargetDatabase = $TargetDatabase
        ReleaseReference = $ReleaseReference
        DeploymentReference = $DeploymentReference
        IsApply = [bool]$Apply
        IsWhatIf = [bool]$WhatIf
        PlanCount = $PlanTable.Rows.Count
        SupportedCount = $supportedCount
        UnsupportedCount = $UnsupportedItems.Count
        MaterializedSourceCount = $materializedItems.Count
        RetryFailedDeployment = [bool]$RetryFailedDeployment
        GeneratedOnUtc = [DateTime]::UtcNow.ToString("O")
        ExecutionId = $executionId
        ExecutionMode = $executionMode
        RunOutputRoot = $runOutputRoot
        OutputDirectory = $OutputDirectory
    }

    $summaryText = $summary | ConvertTo-Json -Depth 12
    Write-CymBuildTextFile -Path $summaryJson -Content ($summaryText + "`r`n")
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

    $orderedApplyItems = @(
        $SupportedItems |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) } |
            Sort-Object @{ Expression = {
                if ($_.ObjectType -eq "Constraint") {
                    switch ($_.ConstraintKind) {
                        "PRIMARY_KEY" { 1000 }
                        "UNIQUE" { 1000 }
                        "DEFAULT" { 1010 }
                        "CHECK" { 1020 }
                        "FOREIGN_KEY" { 1030 }
                        default { 1090 }
                    }
                }
                elseif ($_.ObjectType -eq "Table") { 100 }
                elseif ($_.ObjectType -eq "TableType") { 110 }
                elseif ($_.ObjectType -eq "Sequence") { 120 }
                elseif ($_.ObjectType -eq "Index") { 900 }
                elseif ($_.ObjectType -eq "Trigger") { 1100 }
                else { 500 }
            } }, SchemaName, ParentObjectName, ObjectName
    )

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
        [void]$content.AppendLine("EXEC [SCore].[PostDeploymentScript];")
        [void]$content.AppendLine("GO")
    }

    Write-CymBuildTextFile -Path $scriptPath -Content $content.ToString()
    return $scriptPath
}

function Invoke-CymBuildSchemaDeployment {
    $preDeploymentCompleted = $false
    $postDeploymentCompleted = $false

    $sqlConnectionString = New-CymBuildSqlConnectionString
    $connection = New-SqlConnection -SqlConnectionString $sqlConnectionString

    try {
        $runAndPlan = Get-RunAndPlan -Connection $connection
        $runRow = $runAndPlan.RunRow
        $planTable = $runAndPlan.PlanTable

        Assert-RunCanDeploy -RunRow $runRow -Connection $connection

        if ($planTable.Rows.Count -eq 0) {
            throw "The selected deployment plan is empty. Select deployable schema differences in CymBuild and save the selection before running deployment."
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

        Write-PlanOutputs -RunRow $runRow -PlanTable $planTable -ResolvedItems $resolvedItems -UnsupportedItems $unsupportedItems
        $previewScriptPath = New-PreviewDeploymentScript -SupportedItems $supported

        Write-Host "CYB-361 R41 declarative schema convergence runner" -ForegroundColor Cyan
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

        Set-SchemaPreflightContext -Connection $connection -PreDeploymentWillRun (-not $SkipPreDeployment)

        $hasSelectedTableDeployment = @($supported | Where-Object { $_.ObjectType -eq "Table" -and -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) }).Count -gt 0
        $preflightedItemList = New-Object System.Collections.Generic.List[object]
        $deferredPreflightItemList = New-Object System.Collections.Generic.List[object]
        foreach ($item in $supported) {
            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"

            foreach ($supportFile in $item.SupportFiles) {
                Write-Host "Preparing shared migration support for $objectLabel" -ForegroundColor DarkCyan
                $supportSql = Get-Content -LiteralPath $supportFile -Raw
                Invoke-SqlScriptText -Connection $connection -Sql $supportSql -Description "$objectLabel shared migration support" -TimeoutSeconds 600
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
            Invoke-SqlScriptText -Connection $connection -Sql $preflightSql -Description "$objectLabel preflight" -TimeoutSeconds 600
            [void]$preflightedItemList.Add($item)
        }
        [object[]]$preflightedItems = $preflightedItemList.ToArray()
        [object[]]$deferredPreflightItems = $deferredPreflightItemList.ToArray()

        if ($WhatIf) {
            $materializationMessage = if ($materializedItems.Count -gt 0) { " Canonical source files were generated in the repository; review and commit them before promotion." } else { "" }
            $deferredMessage = if ($deferredPreflightItems.Count -gt 0) { " $($deferredPreflightItems.Count) constraint/index preflight(s) are intentionally deferred until after the selected table convergence during apply." } else { "" }
            Write-Host "Dry-run only. Read-only target preflights completed, including eligibility validation for schema-bound dependencies scheduled for SCore.PreDeploymentScript;$deferredMessage no target schema, data, or SMigration audit rows were changed.$materializationMessage Re-run with -Apply to deploy." -ForegroundColor Yellow
            return
        }

        $deploymentAuditStarted = $true

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
            Invoke-SqlScriptText -Connection $connection -Sql "EXEC [SCore].[PreDeploymentScript];" -Description "SCore.PreDeploymentScript" -TimeoutSeconds 1800
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
                Invoke-SqlScriptText -Connection $connection -Sql $strictPreflightSql -Description "$objectLabel strict post-pre-deployment preflight" -TimeoutSeconds 600

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
            Invoke-SqlScriptText -Connection $connection -Sql $prepareSql -Description "$objectLabel prepare" -TimeoutSeconds 1800
            $itemKey = "$($item.ObjectType)|$($item.SchemaName)|$($item.ParentObjectName)|$($item.ObjectName)"
            $appliedObjectKeys[$itemKey] = $true

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

        $orderedApplyItems = @(
            $supported |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.SourceFile) } |
            Sort-Object @{ Expression = {
                if ($_.ObjectType -eq "Constraint") {
                    switch ($_.ConstraintKind) {
                        "PRIMARY_KEY" { 1000 }
                        "UNIQUE" { 1000 }
                        "DEFAULT" { 1010 }
                        "CHECK" { 1020 }
                        "FOREIGN_KEY" { 1030 }
                        default { 1090 }
                    }
                }
                elseif ($_.ObjectType -eq "Table") { 100 }
                elseif ($_.ObjectType -eq "TableType") { 110 }
                elseif ($_.ObjectType -eq "Sequence") { 120 }
                elseif ($_.ObjectType -eq "Index") { 900 }
                elseif ($_.ObjectType -eq "Trigger") { 1100 }
                else { 500 }
            } }, SchemaName, ParentObjectName, ObjectName
        )

        $deferredPreflightsCompleted = $deferredPreflightItems.Count -eq 0
        foreach ($item in $orderedApplyItems) {
            if (-not $deferredPreflightsCompleted -and $item.ObjectType -in @("Index", "Constraint")) {
                foreach ($deferredItem in $deferredPreflightItems) {
                    $deferredLabel = "$($deferredItem.ObjectType) $($deferredItem.SchemaName).$($deferredItem.ObjectName)"
                    Write-Host "Post-structure preflighting $deferredLabel" -ForegroundColor Cyan
                    $deferredSql = Get-Content -LiteralPath $deferredItem.PreflightFile -Raw
                    Invoke-SqlScriptText -Connection $connection -Sql $deferredSql -Description "$deferredLabel post-structure preflight" -TimeoutSeconds 600
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
                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Skipped" -Message "$objectLabel already exists. Non-destructive recreate was not attempted." -Details $item
                continue
            }

            $sql = Get-Content -LiteralPath $item.SourceFile -Raw
            $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
            Invoke-SqlScriptText -Connection $connection -Sql $sql -Description $objectLabel -TimeoutSeconds 1800
            $itemKey = "$($item.ObjectType)|$($item.SchemaName)|$($item.ParentObjectName)|$($item.ObjectName)"
            $appliedObjectKeys[$itemKey] = $true

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

        if (-not $SkipPostDeployment -and -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Running SCore.PostDeploymentScript..." -ForegroundColor Cyan
            Invoke-SqlScriptText -Connection $connection -Sql "EXEC [SCore].[PostDeploymentScript];" -Description "SCore.PostDeploymentScript" -TimeoutSeconds 1800
            $postDeploymentCompleted = $true
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPost" -StepStatus "Succeeded" -Message "SCore.PostDeploymentScript completed on the target database." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
            }
        }
        elseif ($TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPost" -StepStatus "Skipped" -Message "SCore.PostDeploymentScript skipped because target is CymBuild_Dev." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
            }
        }

        $finalStatus = if ($unsupportedItems.Count -gt 0) { "DeploymentPartiallyApplied" } else { "DeploymentApplied" }
        $note = "Manual schema deployment runner applied $appliedCount source-controlled object(s)."
        if ($unsupportedItems.Count -gt 0) {
            $note += " Unsupported rows were skipped because -AllowPartial was used."
        }

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
        }

        Write-Host "Schema deployment completed. Applied $appliedCount object(s). Status: $finalStatus" -ForegroundColor Green
    }
    catch {
        $deploymentError = $_
        $failureMessage = $deploymentError.Exception.Message
        $recoveryAttempted = $false
        $recoverySucceeded = $false
        $recoveryError = ""

        if ($Apply -and
            $preDeploymentCompleted -and
            -not $postDeploymentCompleted -and
            -not $SkipPostDeployment -and
            -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase) -and
            $null -ne $connection -and
            $connection.State -eq [System.Data.ConnectionState]::Open) {
            $recoveryAttempted = $true
            Write-Warning "Deployment failed after SCore.PreDeploymentScript. Attempting SCore.PostDeploymentScript recovery before returning the original error."

            try {
                Invoke-SqlScriptText -Connection $connection -Sql "EXEC [SCore].[PostDeploymentScript];" -Description "SCore.PostDeploymentScript failure recovery" -TimeoutSeconds 1800
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
                    }
                }
                catch {
                    Write-Warning "Post-deployment recovery completed, but its dedicated audit row could not be written: $($_.Exception.Message)"
                }
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
                }
            }
        }
        catch {
            Write-Warning "Failed to write SMigration execution state after deployment failure: $($_.Exception.Message)"
        }

        throw $deploymentError
    }
    finally {
        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

Invoke-CymBuildSchemaDeployment
