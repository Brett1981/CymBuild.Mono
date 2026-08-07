<#
.SYNOPSIS
    CYB-361 R22 manual schema deployment runner.

.DESCRIPTION
    Reads an accepted SMigration schema deployment plan from the target database and applies the
    corresponding source-controlled SQL artefacts from the repository.

    This is the manual version of the future release-pipeline step. It intentionally does not copy
    ad-hoc DDL from a source database. Source-controlled files under Database/CymBuild_DB/Schema are
    the deployment source of truth.

    Default behaviour is dry-run. Use -Apply to execute.

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
    [switch]$SkipPreDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPostDeployment,

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

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoRoot "artifacts\schema-deployment\$($RunGuid.ToString())"
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
        default { return "" }
    }
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
        default {
            return $sqlText
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

    $result = [ordered]@{
        ComparisonGuid = [string]$Row["ComparisonGuid"]
        ObjectType = $objectType
        SchemaName = $schemaName
        ObjectName = $objectName
        ParentObjectName = $parentObjectName
        DifferenceType = $differenceType
        SourceFile = ""
        IsSupported = $false
        Reason = ""
    }

    if ($objectType -in @("Index", "Constraint", "Trigger")) {
        $result.Reason = "$objectType deployment requires a dedicated source-controlled migration script or future object extractor. It is not executed from captured database DDL."
        return [pscustomobject]$result
    }

    if ($objectType -in @("Table", "TableType", "Sequence") -and $differenceType -ne "MissingInTarget") {
        $result.Reason = "$objectType '$schemaName.$objectName' exists in the target but differs. Non-destructive ALTER migration SQL is required; table/type/sequence recreate is not allowed."
        return [pscustomobject]$result
    }

    $sourceFile = Get-SourceSqlFile -ObjectType $objectType -SchemaName $schemaName -ObjectName $objectName -ParentObjectName $parentObjectName
    if ([string]::IsNullOrWhiteSpace($sourceFile)) {
        $result.Reason = "No source-controlled SQL mapping exists for object type '$objectType'."
        return [pscustomobject]$result
    }

    $schemaRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot "Database\CymBuild_DB\Schema"))
    $sourceFile = [System.IO.Path]::GetFullPath($sourceFile)
    $schemaRootPrefix = $schemaRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $sourceFile.StartsWith($schemaRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.Reason = "Resolved source path is outside Database/CymBuild_DB/Schema."
        return [pscustomobject]$result
    }

    $result.SourceFile = $sourceFile

    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        $result.Reason = "Source-controlled SQL file not found for $objectType '$schemaName.$objectName'."
        return [pscustomobject]$result
    }

    $result.IsSupported = $true
    $result.Reason = "Source-controlled SQL file resolved."
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
    if (-not $SkipAcceptanceCheck -and
        (-not [bool]$RunRow["IsReviewed"] -or
         -not $runStatus.Equals("Reviewed", [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Run $RunGuid is not in the accepted Reviewed state. Validate the current selected plan and accept the run in CymBuild before deploying."
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
    $planRowArray | Export-Csv -Path $planCsv -NoTypeInformation
    $ResolvedItems | Export-Csv -Path $resolvedCsv -NoTypeInformation
    $UnsupportedItems | Export-Csv -Path $unsupportedCsv -NoTypeInformation

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
        GeneratedOnUtc = [DateTime]::UtcNow.ToString("O")
        OutputDirectory = $OutputDirectory
    }

    $summary | ConvertTo-Json -Depth 12 | Set-Content -Path $summaryJson -Encoding UTF8
}

function New-PreviewDeploymentScript {
    param([object[]]$SupportedItems)

    $scriptPath = Join-Path $OutputDirectory "manual-preview-deployment.sql"
    $content = New-Object System.Text.StringBuilder

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

    if (-not $SkipPreDeployment) {
        [void]$content.AppendLine("EXEC [SCore].[PreDeploymentScript];")
        [void]$content.AppendLine("GO")
    }

    foreach ($item in $SupportedItems) {
        $sql = Get-Content -Path $item.SourceFile -Raw
        $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
        [void]$content.AppendLine("")
        [void]$content.AppendLine("/* Deploy $($item.ObjectType) $($item.SchemaName).$($item.ObjectName) from $($item.SourceFile) */")
        [void]$content.AppendLine($sql)
        [void]$content.AppendLine("GO")
    }

    if (-not $SkipPostDeployment -and -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$content.AppendLine("EXEC [SCore].[PostDeploymentScript];")
        [void]$content.AppendLine("GO")
    }

    Set-Content -Path $scriptPath -Value $content.ToString() -Encoding UTF8
    return $scriptPath
}

function Invoke-CymBuildSchemaDeployment {
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

        Write-PlanOutputs -RunRow $runRow -PlanTable $planTable -ResolvedItems $resolvedItems -UnsupportedItems $unsupportedItems
        $previewScriptPath = New-PreviewDeploymentScript -SupportedItems $supported

        Write-Host "CYB-361 R22 schema deployment runner" -ForegroundColor Cyan
        Write-Host "Repo root       : $RepoRoot"
        Write-Host "Target          : $TargetServer / $TargetDatabase"
        Write-Host "Run Guid        : $RunGuid"
        Write-Host "Plan rows       : $($planTable.Rows.Count)"
        Write-Host "Supported rows  : $($supported.Count)"
        Write-Host "Unsupported rows: $($unsupportedItems.Count)"
        Write-Host "Output folder   : $OutputDirectory"
        Write-Host "Preview SQL     : $previewScriptPath"

        if ($unsupportedItems.Count -gt 0) {
            Write-Host "Unsupported rows were found. See unsupported-items.csv." -ForegroundColor Yellow
            if (-not $AllowPartial) {
                throw "Deployment plan contains unsupported rows. Narrow the selection in CymBuild or re-run with -AllowPartial to deploy only supported rows."
            }
        }

        if ($supported.Count -eq 0) {
            throw "No supported source-controlled schema artefacts were resolved for this deployment plan."
        }

        if ($WhatIf) {
            Write-Host "Dry-run only. No SQL was executed. Re-run with -Apply to deploy." -ForegroundColor Yellow
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
            AllowPartial = [bool]$AllowPartial
        }

        foreach ($unsupportedItem in $unsupportedItems) {
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Skipped" -Message "$($unsupportedItem.ObjectType) $($unsupportedItem.SchemaName).$($unsupportedItem.ObjectName) is unsupported by the current manual runner and was skipped under -AllowPartial." -Details $unsupportedItem
        }

        if (-not $SkipPreDeployment) {
            Write-Host "Running SCore.PreDeploymentScript..." -ForegroundColor Cyan
            Invoke-SqlScriptText -Connection $connection -Sql "EXEC [SCore].[PreDeploymentScript];" -Description "SCore.PreDeploymentScript" -TimeoutSeconds 1800
            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentPre" -StepStatus "Succeeded" -Message "SCore.PreDeploymentScript completed on the target database." -Details @{
                TargetServer = $TargetServer
                TargetDatabase = $TargetDatabase
            }
        }

        $appliedCount = 0
        foreach ($item in $supported) {
            $objectLabel = "$($item.ObjectType) $($item.SchemaName).$($item.ObjectName)"
            Write-Host "Deploying $objectLabel" -ForegroundColor Cyan

            if ($item.ObjectType -in @("Table", "TableType", "Sequence") -and (Test-SqlObjectExists -Connection $connection -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName)) {
                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Skipped" -Message "$objectLabel already exists. Non-destructive recreate was not attempted." -Details $item
                continue
            }

            $sql = Get-Content -Path $item.SourceFile -Raw
            $sql = Convert-SchemaScriptForDeployment -Sql $sql -ObjectType $item.ObjectType -SchemaName $item.SchemaName -ObjectName $item.ObjectName -DifferenceType $item.DifferenceType
            Invoke-SqlScriptText -Connection $connection -Sql $sql -Description $objectLabel -TimeoutSeconds 1800
            $appliedCount++

            Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentObject" -StepStatus "Applied" -Message "$objectLabel applied from source-controlled SQL." -Details @{
                ComparisonGuid = $item.ComparisonGuid
                ObjectType = $item.ObjectType
                SchemaName = $item.SchemaName
                ObjectName = $item.ObjectName
                ParentObjectName = $item.ParentObjectName
                DifferenceType = $item.DifferenceType
                SourceFile = $item.SourceFile
            }
        }

        if (-not $SkipPostDeployment -and -not $TargetDatabase.Equals("CymBuild_Dev", [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Running SCore.PostDeploymentScript..." -ForegroundColor Cyan
            Invoke-SqlScriptText -Connection $connection -Sql "EXEC [SCore].[PostDeploymentScript];" -Description "SCore.PostDeploymentScript" -TimeoutSeconds 1800
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
        try {
            if ($Apply -and $deploymentAuditStarted -and $null -ne $connection -and $connection.State -eq [System.Data.ConnectionState]::Open) {
                $failureMessage = $_.Exception.Message
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
                }
            }
        }
        catch {
            Write-Warning "Failed to write SMigration execution state after deployment failure: $($_.Exception.Message)"
        }

        throw
    }
    finally {
        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

Invoke-CymBuildSchemaDeployment
