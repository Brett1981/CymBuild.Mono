[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionString = '',

    [Parameter(Mandatory = $false)]
    [string]$AllowedDatabaseName = '',

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [switch]$Apply,

    [Parameter(Mandatory = $true, ParameterSetName = 'Verify')]
    [switch]$VerifyOnly,

    [Parameter(Mandatory = $true, ParameterSetName = 'Source')]
    [switch]$ValidateSourceOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestRelativePath = 'tools\Testing\R4-Sql-Test-Schema.json'
$compatibilityRelativePath = 'tests\CymBuild.Database.IntegrationTests\Database\R4-Test-Compatibility.sql'
$fixtureRelativePath = 'tests\CymBuild.Database.IntegrationTests\Database\R4-Test-Fixtures.sql'

function Get-NormalizedTextHash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) {
        $offset = 3
    }

    $text = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset)
    $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized))
        )).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Split-SqlBatches {
    param([Parameter(Mandatory = $true)][string]$Text)

    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    return @(
        [regex]::Split(
            $normalized,
            '(?im)^\s*GO(?:\s+\d+)?\s*(?:--.*)?$'
        ) |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-ConnectionDetails {
    param([Parameter(Mandatory = $true)][string]$Value)

    $builder = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder
    try {
        $builder.set_ConnectionString($Value)
        $databaseName = ([string]$builder.get_InitialCatalog()).Trim()
        $builder.set_ApplicationName('CymBuild SQL Test Provisioner')
        $builder.set_MultipleActiveResultSets($false)
        $normalizedConnectionString = [string]$builder.get_ConnectionString()
    }
    catch {
        throw "The SQL test connection string is invalid: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($databaseName)) {
        throw 'The SQL test connection string must include Initial Catalog or Database.'
    }

    return [pscustomobject]@{
        DatabaseName = $databaseName
        ConnectionString = $normalizedConnectionString
    }
}

function Assert-SafeDatabaseName {
    param(
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $false)][string]$ExplicitlyAllowedDatabaseName = ''
    )

    $systemDatabases = @('master', 'model', 'msdb', 'tempdb')
    if ($systemDatabases -contains $DatabaseName.ToLowerInvariant()) {
        throw "Refusing to provision system database '$DatabaseName'."
    }

    $hasSafePrefix = $DatabaseName.StartsWith(
        'CymBuild_Test_',
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isExplicitlyAllowed =
        -not [string]::IsNullOrWhiteSpace($ExplicitlyAllowedDatabaseName) -and
        [string]::Equals(
            $DatabaseName,
            $ExplicitlyAllowedDatabaseName,
            [System.StringComparison]::OrdinalIgnoreCase
        )

    if (-not $hasSafePrefix -and -not $isExplicitlyAllowed) {
        throw "Refusing to provision '$DatabaseName'. Use a dedicated CymBuild_Test_* database or pass -AllowedDatabaseName explicitly."
    }
}

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "R4 SQL source manifest was not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ([int]$manifest.schemaVersion -ne 1) {
        throw "Unsupported R4 SQL source manifest version: $($manifest.schemaVersion)"
    }

    $sourceRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $RepositoryRoot ([string]$manifest.sourceRoot))
    )
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        throw "Canonical CymBuild SQL source root was not found: $sourceRoot"
    }

    foreach ($source in @($manifest.sources)) {
        $candidate = [System.IO.Path]::GetFullPath(
            (Join-Path $sourceRoot ([string]$source.path))
        )
        $trimCharacters = [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $rootWithSeparator = $sourceRoot.TrimEnd($trimCharacters) + [System.IO.Path]::DirectorySeparatorChar

        if (-not $candidate.StartsWith(
            $rootWithSeparator,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Manifest source path escapes the canonical schema root: $($source.path)"
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Canonical schema source file is missing: $($source.path)"
        }

        $actualHash = Get-NormalizedTextHash -Path $candidate
        if (-not [string]::Equals(
            $actualHash,
            [string]$source.sha256,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Canonical schema source hash mismatch: $($source.path). Review the source change and update the R4 manifest deliberately."
        }

        $text = Get-Content -LiteralPath $candidate -Raw
        $batches = @(Split-SqlBatches -Text $text)
        foreach ($batchContract in @($source.batches)) {
            $matches = @()
            $matchRegex = Get-OptionalPropertyValue -InputObject $batchContract -PropertyName 'matchRegex'
            if ($null -ne $matchRegex -and
                -not [string]::IsNullOrWhiteSpace([string]$matchRegex)) {
                $regex = [System.Text.RegularExpressions.Regex]::new(
                    [string]$matchRegex,
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )
                $matches = @($batches | Where-Object { $regex.IsMatch($_) })
            }
            else {
                $needle = [string](Get-OptionalPropertyValue -InputObject $batchContract -PropertyName 'match')
                $matches = @(
                    $batches |
                    Where-Object {
                        $_.IndexOf(
                            $needle,
                            [System.StringComparison]::OrdinalIgnoreCase
                        ) -ge 0
                    }
                )
            }

            if ($matches.Count -ne 1) {
                throw "Expected one canonical batch for '$($source.path)' contract '$($batchContract.kind)'; found $($matches.Count)."
            }
        }
    }

    return $manifest
}

function Assert-TestSqlScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$RequiredText
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "R4 fixture SQL was not found: $Path"
    }

    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($requiredTextItem in $RequiredText) {
        if ($text.IndexOf($requiredTextItem, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "R4 test SQL is missing required contract: $requiredTextItem"
        }
    }

    foreach ($forbiddenPattern in @(
        '(?im)^\s*DROP\s+',
        '(?im)^\s*TRUNCATE\s+',
        '(?im)^\s*DELETE\s+',
        '(?im)^\s*MERGE\s+',
        '(?im)\bSELECT\s+\*'
    )) {
        if ([regex]::IsMatch($text, $forbiddenPattern)) {
            throw "R4 test SQL contains a forbidden operation matching: $forbiddenPattern"
        }
    }
}

function New-SqlCommand {
    param(
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $false)][System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)][string]$CommandText
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $CommandText
    $command.CommandTimeout = 180
    if ($null -ne $Transaction) {
        $command.Transaction = $Transaction
    }

    return $command
}

function Invoke-SqlNonQuery {
    param(
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $false)][System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)][string]$CommandText
    )

    $command = New-SqlCommand -Connection $Connection -Transaction $Transaction -CommandText $CommandText
    try {
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-SqlScalar {
    param(
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $false)][System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)][string]$CommandText,
        [Parameter(Mandatory = $false)][hashtable]$Parameters = @{}
    )

    $command = New-SqlCommand -Connection $Connection -Transaction $Transaction -CommandText $CommandText
    try {
        foreach ($entry in $Parameters.GetEnumerator()) {
            $parameter = $command.Parameters.Add(
                [string]$entry.Key,
                [System.Data.SqlDbType]::NVarChar,
                128
            )
            $parameter.Value = [string]$entry.Value
        }
        return $command.ExecuteScalar()
    }
    finally {
        $command.Dispose()
    }
}

function Test-SchemaExists {
    param($Connection, $Transaction, [string]$SchemaName)

    $sql = 'SELECT COUNT_BIG(1) FROM sys.schemas WHERE name = @SchemaName;'
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{ '@SchemaName' = $SchemaName }
    return ([int64]$value -gt 0)
}

function Test-TableExists {
    param($Connection, $Transaction, [string]$SchemaName, [string]$TableName)

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.tables AS tableObject
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{ '@SchemaName' = $SchemaName; '@ObjectName' = $TableName }
    return ([int64]$value -gt 0)
}

function Test-ProcedureExists {
    param($Connection, $Transaction, [string]$SchemaName, [string]$ProcedureName)

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.procedures AS procedureObject
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = procedureObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND procedureObject.name = @ObjectName;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{ '@SchemaName' = $SchemaName; '@ObjectName' = $ProcedureName }
    return ([int64]$value -gt 0)
}

function Test-PrimaryKeyExists {
    param($Connection, $Transaction, [string]$SchemaName, [string]$TableName)

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName
  AND indexObject.is_primary_key = 1;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{ '@SchemaName' = $SchemaName; '@ObjectName' = $TableName }
    return ([int64]$value -gt 0)
}

function Test-IndexExists {
    param(
        $Connection,
        $Transaction,
        [string]$SchemaName,
        [string]$TableName,
        [string]$IndexName
    )

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName
  AND indexObject.name = @IndexName;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{
            '@SchemaName' = $SchemaName
            '@ObjectName' = $TableName
            '@IndexName' = $IndexName
        }
    return ([int64]$value -gt 0)
}

function Test-UniqueColumnIndexExists {
    param(
        $Connection,
        $Transaction,
        [string]$SchemaName,
        [string]$TableName,
        [string]$ColumnName
    )

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.indexes AS indexObject
JOIN sys.tables AS tableObject ON tableObject.object_id = indexObject.object_id
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
JOIN sys.index_columns AS indexColumn
  ON indexColumn.object_id = indexObject.object_id
 AND indexColumn.index_id = indexObject.index_id
JOIN sys.columns AS columnObject
  ON columnObject.object_id = indexColumn.object_id
 AND columnObject.column_id = indexColumn.column_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName
  AND indexObject.is_unique = 1
  AND indexColumn.is_included_column = 0
  AND columnObject.name = @ColumnName;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{
            '@SchemaName' = $SchemaName
            '@ObjectName' = $TableName
            '@ColumnName' = $ColumnName
        }
    return ([int64]$value -gt 0)
}

function Test-ForeignKeyExists {
    param(
        $Connection,
        $Transaction,
        [string]$SchemaName,
        [string]$TableName,
        [string]$ForeignKeyName
    )

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.foreign_keys AS foreignKey
JOIN sys.tables AS tableObject ON tableObject.object_id = foreignKey.parent_object_id
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName
  AND foreignKey.name = @ForeignKeyName;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{
            '@SchemaName' = $SchemaName
            '@ObjectName' = $TableName
            '@ForeignKeyName' = $ForeignKeyName
        }
    return ([int64]$value -gt 0)
}

function Test-ForeignKeyDisabled {
    param(
        $Connection,
        $Transaction,
        [string]$SchemaName,
        [string]$TableName,
        [string]$ForeignKeyName
    )

    $sql = @'
SELECT COUNT_BIG(1)
FROM sys.foreign_keys AS foreignKey
JOIN sys.tables AS tableObject ON tableObject.object_id = foreignKey.parent_object_id
JOIN sys.schemas AS schemaObject ON schemaObject.schema_id = tableObject.schema_id
WHERE schemaObject.name = @SchemaName
  AND tableObject.name = @ObjectName
  AND foreignKey.name = @ForeignKeyName
  AND foreignKey.is_disabled = 1;
'@
    $value = Invoke-SqlScalar `
        -Connection $Connection `
        -Transaction $Transaction `
        -CommandText $sql `
        -Parameters @{
            '@SchemaName' = $SchemaName
            '@ObjectName' = $TableName
            '@ForeignKeyName' = $ForeignKeyName
        }
    return ([int64]$value -gt 0)
}

function Get-MatchingBatch {
    param(
        [Parameter(Mandatory = $true)][object[]]$Batches,
        [Parameter(Mandatory = $true)]$BatchContract
    )

    $matchRegex = Get-OptionalPropertyValue -InputObject $BatchContract -PropertyName 'matchRegex'
    if ($null -ne $matchRegex -and
        -not [string]::IsNullOrWhiteSpace([string]$matchRegex)) {
        $regex = [System.Text.RegularExpressions.Regex]::new(
            [string]$matchRegex,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        return @($Batches | Where-Object { $regex.IsMatch($_) })[0]
    }

    $needle = [string](Get-OptionalPropertyValue -InputObject $BatchContract -PropertyName 'match')
    return @(
        $Batches |
        Where-Object {
            $_.IndexOf(
                $needle,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        }
    )[0]
}

function Convert-CanonicalBatchForTestDatabase {
    param(
        [Parameter(Mandatory = $true)][string]$Batch,
        [Parameter(Mandatory = $true)][string]$Kind
    )

    $converted = $Batch.Replace('[METADATA]', '[PRIMARY]')
    if ($Kind -eq 'Procedure') {
        $createProcedureRegex = New-Object System.Text.RegularExpressions.Regex(
            '(?im)^\s*CREATE\s+PROCEDURE',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $converted = $createProcedureRegex.Replace(
            $converted,
            'CREATE OR ALTER PROCEDURE',
            1
        )
    }

    return $converted
}

function Invoke-ManifestSource {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)]$Source,
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlTransaction]$Transaction
    )

    $path = Join-Path $SourceRoot ([string]$Source.path)
    $batches = @(Split-SqlBatches -Text (Get-Content -LiteralPath $path -Raw))
    $schemaName = [string]$Source.schema
    $objectName = [string]$Source.name

    foreach ($batchContract in @($Source.batches)) {
        $kind = [string]$batchContract.kind
        $shouldExecute = $false

        switch ($kind) {
            'Schema' {
                $shouldExecute = -not (Test-SchemaExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName)
            }
            'Table' {
                $shouldExecute = -not (Test-TableExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName)
            }
            'PrimaryKey' {
                $shouldExecute = -not (Test-PrimaryKeyExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName)
            }
            'Index' {
                $shouldExecute = -not (Test-IndexExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName -IndexName ([string]$batchContract.name))
            }
            'UniqueColumn' {
                $shouldExecute = -not (Test-UniqueColumnIndexExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName -ColumnName ([string]$batchContract.column))
            }
            'ForeignKey' {
                $shouldExecute = -not (Test-ForeignKeyExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName -ForeignKeyName ([string]$batchContract.name))
            }
            'DisableConstraint' {
                if (-not (Test-ForeignKeyExists -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName -ForeignKeyName ([string]$batchContract.name))) {
                    throw "Cannot disable missing foreign key [$schemaName].[$objectName].[$($batchContract.name)]."
                }
                $shouldExecute = -not (Test-ForeignKeyDisabled -Connection $Connection -Transaction $Transaction -SchemaName $schemaName -TableName $objectName -ForeignKeyName ([string]$batchContract.name))
            }
            'Procedure' {
                $shouldExecute = $true
            }
            default {
                throw "Unsupported R4 manifest batch kind '$kind'."
            }
        }

        if ($shouldExecute) {
            $batch = Get-MatchingBatch -Batches $batches -BatchContract $batchContract
            $converted = Convert-CanonicalBatchForTestDatabase -Batch $batch -Kind $kind
            Write-Host "  Applying $kind from $($Source.path)"
            Invoke-SqlNonQuery -Connection $Connection -Transaction $Transaction -CommandText $converted
        }
    }
}

function Ensure-TestSupportFunction {
    param(
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlTransaction]$Transaction
    )

    $exists = Invoke-SqlScalar -Connection $Connection -Transaction $Transaction `
        -CommandText @'
SELECT COUNT_BIG(1)
FROM sys.objects AS objectDefinition
WHERE objectDefinition.object_id = OBJECT_ID(N'SCore.GetCurrentUserDefaultGroup')
  AND objectDefinition.type IN (N'FN', N'FS');
'@

    if ([int64]$exists -eq 0) {
        Write-Host '  Creating test-only SCore.GetCurrentUserDefaultGroup compatibility function'
        Invoke-SqlNonQuery -Connection $Connection -Transaction $Transaction -CommandText @'
CREATE FUNCTION [SCore].[GetCurrentUserDefaultGroup]()
RETURNS int
AS
BEGIN
    RETURN -1;
END;
'@
    }
}

function Get-ProvisioningState {
    param(
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $false)][System.Data.SqlClient.SqlTransaction]$Transaction
    )

    $requiredObjectSql = @'
SELECT COUNT_BIG(1)
FROM (VALUES
    (N'SCore', N'DataObjects', N'U'),
    (N'SCore', N'DataObjectTransition', N'U'),
    (N'SCore', N'IntegrationOutbox', N'U'),
    (N'SCore', N'UpsertDataObject', N'P'),
    (N'SCore', N'DataObjectTransitionUpsert', N'P'),
    (N'SCore', N'NonActivityEventsUpsert', N'P')
) AS requiredObjects(SchemaName, ObjectName, ObjectType)
WHERE OBJECT_ID(
    QUOTENAME(requiredObjects.SchemaName) + N'.' + QUOTENAME(requiredObjects.ObjectName),
    requiredObjects.ObjectType
) IS NOT NULL;
'@
    $requiredTableSql = @'
SELECT COUNT_BIG(1)
FROM (VALUES
    (N'SCore', N'EntityTypes'),
    (N'SCore', N'DataObjects'),
    (N'SCore', N'EntityHobts'),
    (N'SCore', N'Groups'),
    (N'SCore', N'Identities'),
    (N'SCore', N'WorkflowStatus'),
    (N'SCore', N'NonActivityTypes'),
    (N'SCore', N'NonActivityEvents'),
    (N'SCore', N'DataObjectTransition'),
    (N'SCore', N'IntegrationOutbox')
) AS requiredTables(SchemaName, TableName)
WHERE OBJECT_ID(
    QUOTENAME(requiredTables.SchemaName) + N'.' + QUOTENAME(requiredTables.TableName),
    N'U'
) IS NOT NULL;
'@
    $requiredIndexSql = @'
SELECT COUNT_BIG(1)
FROM (VALUES
    (N'SCore', N'DataObjectTransition', N'IX_DataObjectTransition_Active_DataObjectGuid_ID'),
    (N'SCore', N'IntegrationOutbox', N'IX_IntegrationOutbox_PublishClaim')
) AS requiredIndexes(SchemaName, TableName, IndexName)
JOIN sys.schemas AS schemaObject ON schemaObject.name = requiredIndexes.SchemaName
JOIN sys.tables AS tableObject
  ON tableObject.schema_id = schemaObject.schema_id
 AND tableObject.name = requiredIndexes.TableName
JOIN sys.indexes AS indexObject
  ON indexObject.object_id = tableObject.object_id
 AND indexObject.name = requiredIndexes.IndexName;
'@
    $uniqueTransitionSql = @'
SELECT COUNT_BIG(1)
FROM sys.indexes AS indexObject
JOIN sys.index_columns AS indexColumn
  ON indexColumn.object_id = indexObject.object_id
 AND indexColumn.index_id = indexObject.index_id
JOIN sys.columns AS columnObject
  ON columnObject.object_id = indexColumn.object_id
 AND columnObject.column_id = indexColumn.column_id
WHERE indexObject.object_id = OBJECT_ID(N'SCore.DataObjectTransition')
  AND indexObject.is_unique = 1
  AND columnObject.name = N'Guid';
'@

    $state = [ordered]@{
        RequiredObjectCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $requiredObjectSql)
        RequiredTableCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $requiredTableSql)
        RequiredIndexCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $requiredIndexSql)
        UniqueTransitionGuidCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $uniqueTransitionSql)
        CompatibilityObjectCount = 0L
        FixtureEntityHobtCount = 0L
        FixtureGroupCount = 0L
        FixtureIdentityCount = 0L
        FixtureStatusCount = 0L
        FixtureNonActivityTypeCount = 0L
        FixtureDataObjectCount = 0L
    }

    $compatibilitySql = @'
SELECT COUNT_BIG(1)
FROM (VALUES
    (N'SCore', N'ObjectSecurity'),
    (N'SJob', N'Jobs'),
    (N'SSop', N'Enquiries'),
    (N'SSop', N'EnquiryServices'),
    (N'SSop', N'Quotes'),
    (N'SSop', N'QuoteItems'),
    (N'SSop', N'QuoteItemTotals')
) AS compatibilityObjects(SchemaName, ObjectName)
WHERE OBJECT_ID(
    QUOTENAME(compatibilityObjects.SchemaName) + N'.' + QUOTENAME(compatibilityObjects.ObjectName),
    N'U'
) IS NOT NULL;
'@
    $state.CompatibilityObjectCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $compatibilitySql)

    if ([int64]$state.RequiredTableCount -eq 10) {
        $fixtureEntityHobtSql = @'
SELECT COUNT_BIG(1)
FROM SCore.EntityHobts
WHERE Guid IN
(
    'D4D00002-0000-4000-8000-000000000007',
    'D4D00002-0000-4000-8000-000000000008'
)
  AND RowStatus NOT IN (0, 254);
'@
        $fixtureGroupSql = @'
SELECT COUNT_BIG(1)
FROM SCore.Groups
WHERE Guid = 'D4D00003-0000-4000-8000-000000000001'
  AND RowStatus NOT IN (0, 254)
  AND TRY_CONVERT(smallint, ID) IS NOT NULL;
'@
        $fixtureIdentitySql = @'
SELECT COUNT_BIG(1)
FROM SCore.Identities
WHERE Guid = 'D4D00004-0000-4000-8000-000000000001'
  AND RowStatus NOT IN (0, 254)
  AND IsActive = 1
  AND TRY_CONVERT(smallint, ID) IS NOT NULL;
'@
        $fixtureStatusSql = @'
SELECT COUNT_BIG(1)
FROM SCore.WorkflowStatus
WHERE Guid IN
(
    'D4D00005-0000-4000-8000-000000000001',
    'D4D00005-0000-4000-8000-000000000002'
)
  AND RowStatus NOT IN (0, 254);
'@
        $fixtureNonActivityTypeSql = @'
SELECT COUNT_BIG(1)
FROM SCore.NonActivityTypes
WHERE Guid = 'D4D00006-0000-4000-8000-000000000001'
  AND RowStatus NOT IN (0, 254);
'@
        $fixtureDataObjectSql = @'
SELECT COUNT_BIG(1)
FROM SCore.DataObjects
WHERE Guid IN
(
    'D4D00001-0000-4000-8000-000000000001',
    'D4D00001-0000-4000-8000-000000000002',
    'D4D00001-0000-4000-8000-000000000003',
    'D4D00001-0000-4000-8000-000000000004',
    'D4D00001-0000-4000-8000-000000000005',
    'D4D00001-0000-4000-8000-000000000006',
    'D4D00001-0000-4000-8000-000000000007',
    'D4D00001-0000-4000-8000-000000000008',
    'D4D00002-0000-4000-8000-000000000001',
    'D4D00002-0000-4000-8000-000000000002',
    'D4D00002-0000-4000-8000-000000000003',
    'D4D00002-0000-4000-8000-000000000004',
    'D4D00002-0000-4000-8000-000000000005',
    'D4D00002-0000-4000-8000-000000000006',
    'D4D00002-0000-4000-8000-000000000007',
    'D4D00002-0000-4000-8000-000000000008',
    'D4D00003-0000-4000-8000-000000000001',
    'D4D00004-0000-4000-8000-000000000001',
    'D4D00005-0000-4000-8000-000000000001',
    'D4D00005-0000-4000-8000-000000000002',
    'D4D00006-0000-4000-8000-000000000001'
)
  AND RowStatus NOT IN (0, 254);
'@
        $state.FixtureEntityHobtCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureEntityHobtSql)
        $state.FixtureGroupCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureGroupSql)
        $state.FixtureIdentityCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureIdentitySql)
        $state.FixtureStatusCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureStatusSql)
        $state.FixtureNonActivityTypeCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureNonActivityTypeSql)
        $state.FixtureDataObjectCount = [int64](Invoke-SqlScalar -Connection $Connection -Transaction $Transaction -CommandText $fixtureDataObjectSql)
    }

    return [pscustomobject]$state
}

function Assert-ProvisioningState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$DatabaseName
    )

    $failures = New-Object System.Collections.Generic.List[string]
    if ([int64]$State.RequiredObjectCount -ne 6) {
        $failures.Add("required objects $($State.RequiredObjectCount)/6")
    }
    if ([int64]$State.RequiredTableCount -ne 10) {
        $failures.Add("required tables $($State.RequiredTableCount)/10")
    }
    if ([int64]$State.RequiredIndexCount -ne 2) {
        $failures.Add("required named indexes $($State.RequiredIndexCount)/2")
    }
    if ([int64]$State.UniqueTransitionGuidCount -lt 1) {
        $failures.Add('unique transition Guid index missing')
    }
    if ([int64]$State.CompatibilityObjectCount -ne 7) {
        $failures.Add("procedure compatibility objects $($State.CompatibilityObjectCount)/7")
    }
    if ([int64]$State.FixtureEntityHobtCount -ne 2) {
        $failures.Add("required EntityHobts fixtures $($State.FixtureEntityHobtCount)/2")
    }
    if ([int64]$State.FixtureGroupCount -ne 1) {
        $failures.Add("group fixtures $($State.FixtureGroupCount)/1")
    }
    if ([int64]$State.FixtureIdentityCount -ne 1) {
        $failures.Add("identity fixtures $($State.FixtureIdentityCount)/1")
    }
    if ([int64]$State.FixtureStatusCount -ne 2) {
        $failures.Add("workflow status fixtures $($State.FixtureStatusCount)/2")
    }
    if ([int64]$State.FixtureNonActivityTypeCount -ne 1) {
        $failures.Add("non-activity fixtures $($State.FixtureNonActivityTypeCount)/1")
    }
    if ([int64]$State.FixtureDataObjectCount -ne 21) {
        $failures.Add("fixture DataObjects $($State.FixtureDataObjectCount)/21")
    }

    if ($failures.Count -gt 0) {
        throw "Dedicated SQL test database '$DatabaseName' is not provisioned for R4: $($failures -join '; '). Run Initialize-CymBuildSqlTestDatabase.ps1 with -Apply or invoke the SQL test runner with -ProvisionDatabase."
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$manifestPath = Join-Path $RepoRoot $manifestRelativePath
$compatibilityPath = Join-Path $RepoRoot $compatibilityRelativePath
$fixturePath = Join-Path $RepoRoot $fixtureRelativePath
$manifest = Get-Manifest -RepositoryRoot $RepoRoot -ManifestPath $manifestPath
Assert-TestSqlScript -Path $compatibilityPath -RequiredText @(
    "DB_NAME() NOT LIKE N'CymBuild[_]Test[_]%'",
    'CREATE TABLE SCore.ObjectSecurity',
    'CREATE TABLE SJob.Jobs',
    'CREATE TABLE SSop.QuoteItems',
    'CREATE TABLE SSop.Quotes',
    'CREATE TABLE SSop.QuoteItemTotals',
    'CREATE TABLE SSop.EnquiryServices',
    'CREATE TABLE SSop.Enquiries'
)
Assert-TestSqlScript -Path $fixturePath -RequiredText @(
    "DB_NAME() NOT LIKE N'CymBuild[_]Test[_]%'",
    'INSERT INTO SCore.EntityTypes',
    'INSERT INTO SCore.DataObjects',
    'INSERT INTO SCore.EntityHobts',
    'INSERT INTO SCore.Groups',
    'INSERT INTO SCore.Identities',
    'INSERT INTO SCore.WorkflowStatus',
    'INSERT INTO SCore.NonActivityTypes'
)

if ($ValidateSourceOnly) {
    Write-Host 'R4 SQL source manifest, compatibility SQL, and deterministic fixture SQL validated successfully.'
    Write-Host "Canonical sources: $(@($manifest.sources).Count)"
    return
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw 'A SQL test connection string is required for -Apply or -VerifyOnly.'
}

$connectionDetails = Get-ConnectionDetails -Value $ConnectionString
Assert-SafeDatabaseName `
    -DatabaseName $connectionDetails.DatabaseName `
    -ExplicitlyAllowedDatabaseName $AllowedDatabaseName

$isExplicitlyAllowed =
    -not [string]::IsNullOrWhiteSpace($AllowedDatabaseName) -and
    [string]::Equals(
        $connectionDetails.DatabaseName,
        $AllowedDatabaseName,
        [System.StringComparison]::OrdinalIgnoreCase
    )

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.set_ConnectionString($connectionDetails.ConnectionString)
try {
    $connection.Open()

    if (-not [string]::Equals(
        [string]$connection.get_Database(),
        $connectionDetails.DatabaseName,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Connected database '$($connection.get_Database())' does not match requested database '$($connectionDetails.DatabaseName)'."
    }

    if ($VerifyOnly) {
        $state = Get-ProvisioningState -Connection $connection
        Assert-ProvisioningState -State $state -DatabaseName $connectionDetails.DatabaseName
        Write-Host "Dedicated SQL test database '$($connectionDetails.DatabaseName)' is provisioned for all 22 R4 cases."
        return
    }

    $transaction = $connection.BeginTransaction()
    try {
        $lockCommand = New-SqlCommand -Connection $connection -Transaction $transaction -CommandText @'
DECLARE @Result int;
EXEC @Result = sys.sp_getapplock
    @Resource = N'CymBuild.SqlTestProvisioning',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 30000;
SELECT @Result;
'@
        try {
            $lockResult = [int]$lockCommand.ExecuteScalar()
            if ($lockResult -lt 0) {
                throw "Unable to acquire the R4 SQL provisioning lock. sp_getapplock returned $lockResult."
            }
        }
        finally {
            $lockCommand.Dispose()
        }

        $allowedDatabaseContext = if ($isExplicitlyAllowed) {
            "EXEC sys.sp_set_session_context @key = N'CYMBUILD_SQL_TEST_ALLOWED_DATABASE', @value = N'" +
            $connectionDetails.DatabaseName.Replace("'", "''") +
            "', @read_only = 0;"
        }
        else {
            "EXEC sys.sp_set_session_context @key = N'CYMBUILD_SQL_TEST_ALLOWED_DATABASE', @value = NULL, @read_only = 0;"
        }

        Invoke-SqlNonQuery -Connection $connection -Transaction $transaction -CommandText @"
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = 1, @read_only = 0;
EXEC sys.sp_set_session_context @key = N'S_disable_notification_triggers', @value = 1, @read_only = 0;
$allowedDatabaseContext
"@

        $sourceRoot = Join-Path $RepoRoot ([string]$manifest.sourceRoot)
        foreach ($source in @($manifest.sources | Where-Object { [string]$_.kind -eq 'Schema' })) {
            Invoke-ManifestSource -SourceRoot $sourceRoot -Source $source -Connection $connection -Transaction $transaction
        }
        foreach ($source in @($manifest.sources | Where-Object { [string]$_.kind -eq 'Table' })) {
            Invoke-ManifestSource -SourceRoot $sourceRoot -Source $source -Connection $connection -Transaction $transaction
        }

        Write-Host '  Applying empty procedure-compatibility objects'
        Invoke-SqlNonQuery `
            -Connection $connection `
            -Transaction $transaction `
            -CommandText (Get-Content -LiteralPath $compatibilityPath -Raw)

        Ensure-TestSupportFunction -Connection $connection -Transaction $transaction

        foreach ($source in @($manifest.sources | Where-Object { [string]$_.kind -eq 'Procedure' })) {
            Invoke-ManifestSource -SourceRoot $sourceRoot -Source $source -Connection $connection -Transaction $transaction
        }

        Write-Host "  Applying deterministic R4 fixture data"
        Invoke-SqlNonQuery `
            -Connection $connection `
            -Transaction $transaction `
            -CommandText (Get-Content -LiteralPath $fixturePath -Raw)

        $state = Get-ProvisioningState -Connection $connection -Transaction $transaction
        Assert-ProvisioningState -State $state -DatabaseName $connectionDetails.DatabaseName
        $transaction.Commit()
    }
    catch {
        try {
            $transaction.Rollback()
        }
        catch {
            Write-Warning "R4 SQL provisioning rollback also failed: $($_.Exception.Message)"
        }
        throw
    }
    finally {
        $transaction.Dispose()
    }

    $verifiedState = Get-ProvisioningState -Connection $connection
    Assert-ProvisioningState -State $verifiedState -DatabaseName $connectionDetails.DatabaseName
    Write-Host "Dedicated SQL test database '$($connectionDetails.DatabaseName)' provisioned successfully."
    Write-Host 'Canonical table/procedure definitions: source-controlled CymBuild SQL'
    Write-Host 'Fixture rows                     : deterministic, idempotent and DataObjects-compliant'
}
finally {
    $connection.Dispose()
}
