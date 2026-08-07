<#
.SYNOPSIS
    CYB-361 manual schema deployment runner.

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

if ($Apply -and $WhatIf) {
    throw "Specify either -Apply or -WhatIf, not both."
}

if (-not $Apply) {
    $WhatIf = $true
}

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
    $connection.Open()
    return $connection
}

function Add-SqlParameter {
    param(
        [System.Data.SqlClient.SqlCommand]$Command,
        [string]$Name,
        [System.Data.SqlDbType]$Type,
        [object]$Value,
        [int]$Size = 0
    )

    if ($Size -gt 0) {
        $parameter = New-Object System.Data.SqlClient.SqlParameter($Name, $Type, $Size)
    }
    else {
        $parameter = New-Object System.Data.SqlClient.SqlParameter($Name, $Type)
    }

    if ($null -eq $Value) {
        $parameter.Value = [DBNull]::Value
    }
    else {
        $parameter.Value = $Value
    }

    [void]$Command.Parameters.Add($parameter)
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

    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        $parameter = $command.CreateParameter()
        $parameter.ParameterName = $key
        $parameter.Value = if ($null -eq $value) { [DBNull]::Value } else { $value }
        [void]$command.Parameters.Add($parameter)
    }

    $table = New-Object System.Data.DataTable
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
    [void]$adapter.Fill($table)
    return $table
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

    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        $parameter = $command.CreateParameter()
        $parameter.ParameterName = $key
        $parameter.Value = if ($null -eq $value) { [DBNull]::Value } else { $value }
        [void]$command.Parameters.Add($parameter)
    }

    [void]$command.ExecuteNonQuery()
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
    $safeMessage = if ($Message.Length -gt 2000) { $Message.Substring(0, 2000) } else { $Message }

    Invoke-SqlNonQuery -Connection $Connection -Sql @"
DECLARE @LogGuid UNIQUEIDENTIFIER = NEWID();
DECLARE @IsInsert BIT;

EXEC [SCore].[UpsertDataObject]
    @Guid = @LogGuid,
    @SchemeName = N'SMigration',
    @ObjectName = N'Schema_ExecutionLog',
    @IsInsert = @IsInsert OUTPUT;

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
                [void]$batches.Add($batch)
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

    return $batches
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

    if ($objectType -in @("Table", "TableType", "Sequence") -and $differenceType -ne "MissingTarget") {
        $result.Reason = "$objectType '$schemaName.$objectName' exists in the target but differs. Non-destructive ALTER migration SQL is required; table/type/sequence recreate is not allowed."
        return [pscustomobject]$result
    }

    $sourceFile = Get-SourceSqlFile -ObjectType $objectType -SchemaName $schemaName -ObjectName $objectName -ParentObjectName $parentObjectName
    $result.SourceFile = $sourceFile

    if ([string]::IsNullOrWhiteSpace($sourceFile) -or -not (Test-Path $sourceFile)) {
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
DECLARE @HasExplicitSelection BIT =
(
    SELECT
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM [SMigration].[Schema_RunSelections] AS rs
                WHERE rs.RunGuid = @RunGuid
                  AND rs.RowStatus <> 0
                  AND rs.RowStatus <> 254
            ) THEN CONVERT(BIT, 1)
            ELSE CONVERT(BIT, 0)
        END
);

SELECT
    c.Guid AS ComparisonGuid,
    c.ObjectType,
    c.SchemaName,
    c.ObjectName,
    c.ParentObjectName,
    c.DifferenceType,
    c.IsDeployable,
    c.IsDestructiveRisk,
    CASE WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1) ELSE ISNULL(sel.IsSelected, CONVERT(BIT, 0)) END AS IsSelected,
    @HasExplicitSelection AS HasExplicitSelection
FROM [SMigration].[Schema_ObjectComparisons] AS c
OUTER APPLY
(
    SELECT TOP (1)
        rs.IsSelected
    FROM [SMigration].[Schema_RunSelections] AS rs
    WHERE rs.RunGuid = c.RunGuid
      AND rs.ObjectType = c.ObjectType
      AND rs.SchemaName = c.SchemaName
      AND rs.ObjectName = c.ObjectName
      AND rs.ParentObjectName = c.ParentObjectName
      AND rs.RowStatus <> 0
      AND rs.RowStatus <> 254
    ORDER BY rs.ID DESC
) AS sel
WHERE c.RunGuid = @RunGuid
  AND c.RowStatus <> 0
  AND c.RowStatus <> 254
  AND c.IsDeployable = 1
  AND c.DifferenceType <> N'Equal'
  AND (@HasExplicitSelection = 0 OR ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1)
ORDER BY
    CASE c.ObjectType
        WHEN N'Schema' THEN 10
        WHEN N'TableType' THEN 20
        WHEN N'Table' THEN 30
        WHEN N'Sequence' THEN 40
        WHEN N'Constraint' THEN 50
        WHEN N'Index' THEN 60
        WHEN N'View' THEN 70
        WHEN N'Function' THEN 80
        WHEN N'StoredProcedure' THEN 90
        WHEN N'Trigger' THEN 100
        ELSE 900
    END,
    c.SchemaName,
    c.ObjectName;
"@ -Parameters @{ "@RunGuid" = $RunGuid } -TimeoutSeconds 600

    return [pscustomobject]@{
        RunRow = $runTable.Rows[0]
        PlanTable = $planTable
    }
}

function Test-LiveTarget {
    param([System.Data.DataRow]$RunRow)

    $targetEnvironment = ([string]$RunRow["TargetEnvironment"]).Trim()
    $targetDatabaseName = ([string]$RunRow["TargetDatabaseName"]).Trim()

    if ($targetEnvironment.Equals("LIVE", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($targetDatabaseName.Equals("Concursus", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($targetDatabaseName -match '(?i)(^|[_\-])(live|prod|production)([_\-]|$)') {
        return $true
    }

    return $false
}

function Assert-RunCanDeploy {
    param([System.Data.DataRow]$RunRow)

    $runTargetDatabase = [string]$RunRow["TargetDatabaseName"]
    $runTargetServer = [string]$RunRow["TargetServerName"]

    if (-not $IgnoreTargetMismatch) {
        if (-not $runTargetDatabase.Equals($TargetDatabase, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Run target database '$runTargetDatabase' does not match requested target database '$TargetDatabase'. Use -IgnoreTargetMismatch only when deliberately using an equivalent alias."
        }

        if (-not [string]::IsNullOrWhiteSpace($runTargetServer) -and -not $runTargetServer.Equals($TargetServer, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Run target server '$runTargetServer' does not match requested target server '$TargetServer'. Use -IgnoreTargetMismatch only when deliberately using an equivalent alias."
        }
    }

    if (-not $SkipAcceptanceCheck -and -not [bool]$RunRow["IsReviewed"]) {
        throw "Run $RunGuid has not been accepted/reviewed. Accept the run in CymBuild before deploying, or use -SkipAcceptanceCheck for DEV-only diagnostics."
    }

    if ($Apply -and (Test-LiveTarget -RunRow $RunRow) -and -not $AllowLive) {
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

    @($PlanTable.Rows) | Select-Object ComparisonGuid,ObjectType,SchemaName,ObjectName,ParentObjectName,DifferenceType,IsDeployable,IsDestructiveRisk,IsSelected,HasExplicitSelection | Export-Csv -Path $planCsv -NoTypeInformation
    @($ResolvedItems) | Export-Csv -Path $resolvedCsv -NoTypeInformation
    @($UnsupportedItems) | Export-Csv -Path $unsupportedCsv -NoTypeInformation

    $summary = [ordered]@{
        RunGuid = $RunGuid.ToString()
        TargetServer = $TargetServer
        TargetDatabase = $TargetDatabase
        ReleaseReference = $ReleaseReference
        DeploymentReference = $DeploymentReference
        IsApply = [bool]$Apply
        IsWhatIf = [bool]$WhatIf
        PlanCount = $PlanTable.Rows.Count
        SupportedCount = ($ResolvedItems | Where-Object { $_.IsSupported }).Count
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
    [void]$content.AppendLine("    Prefer running Invoke-CymBuildSchemaDeployment.ps1 so audit entries are written to SMigration.")
    [void]$content.AppendLine("    If this SQL is executed manually, record the outcome in CymBuild after completion.")
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

        Assert-RunCanDeploy -RunRow $runRow

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

        $supported = @($resolved | Where-Object { $_.IsSupported })
        $unsupportedItems = @($unsupported)

        Write-PlanOutputs -RunRow $runRow -PlanTable $planTable -ResolvedItems @($resolved) -UnsupportedItems $unsupportedItems
        $previewScriptPath = New-PreviewDeploymentScript -SupportedItems $supported

        Write-Host "CYB-361 schema deployment runner" -ForegroundColor Cyan
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
            if ($null -ne $connection -and $connection.State -eq [System.Data.ConnectionState]::Open) {
                Add-SchemaExecutionLog -Connection $connection -RunGuidValue $RunGuid -StepName "ManualDeploymentRunner" -StepStatus "Failed" -Message "Manual source-controlled schema deployment runner failed." -Details @{
                    Error = $_.Exception.Message
                    TargetServer = $TargetServer
                    TargetDatabase = $TargetDatabase
                }
            }
        }
        catch {
            Write-Warning "Failed to write SMigration execution log after deployment failure: $($_.Exception.Message)"
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
