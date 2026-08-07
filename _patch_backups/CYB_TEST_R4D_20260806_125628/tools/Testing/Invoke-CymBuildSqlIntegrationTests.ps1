[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

    [Parameter(Mandatory = $true)]
    [string]$ConnectionString,

    [Parameter(Mandatory = $false)]
    [string]$AllowedDatabaseName = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Debug', 'Release', 'Test')]
    [string]$Configuration = 'Release',

    [Parameter(Mandatory = $false)]
    [string]$ResultsRoot,

    [Parameter(Mandatory = $false)]
    [switch]$NoRestore,

    [Parameter(Mandatory = $false)]
    [switch]$NoBuild,

    [Parameter(Mandatory = $false)]
    [switch]$NoCoverage,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateConnectionStringOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DatabaseNameFromConnectionString {
    param([Parameter(Mandatory = $true)][string]$Value)

    # SqlConnectionStringBuilder implements IDictionary. Windows PowerShell's
    # extended type adapter can therefore interpret ordinary property access as
    # dictionary-key access. Calling the CLR accessor methods explicitly avoids
    # accidentally creating a provider keyword named `ConnectionString` and is
    # consistent in Windows PowerShell 5.1 and PowerShell 7.
    $builder = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder
    try {
        $builder.set_ConnectionString($Value)
        $databaseName = ([string]$builder.get_InitialCatalog()).Trim()
    }
    catch {
        throw "The SQL test connection string is invalid: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($databaseName)) {
        throw 'The SQL test connection string must include Initial Catalog or Database.'
    }

    return $databaseName
}

function Invoke-DotNet {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $dotnet = Get-Command dotnet -ErrorAction Stop
    $previousErrorActionPreference = $ErrorActionPreference
    $exitCode = -1
    try {
        $ErrorActionPreference = 'Continue'
        & $dotnet.Source @Arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode."
    }
}

function Get-TrxCounts {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Expected TRX result was not produced: $Path"
    }

    [xml]$trx = Get-Content -LiteralPath $Path -Raw
    $results = @($trx.SelectNodes("//*[local-name()='UnitTestResult']"))
    return [pscustomobject]@{
        Total = $results.Count
        Passed = @($results | Where-Object { [string]$_.outcome -eq 'Passed' }).Count
        Failed = @($results | Where-Object { [string]$_.outcome -eq 'Failed' }).Count
        Skipped = @($results | Where-Object { [string]$_.outcome -in @('NotExecuted', 'Skipped') }).Count
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$project = Join-Path $RepoRoot 'tests\CymBuild.Database.IntegrationTests\CymBuild.Database.IntegrationTests.csproj'
$runSettings = Join-Path $RepoRoot 'tests\CymBuild.Testing.runsettings'

if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
    throw "SQL integration test project not found: $project"
}
if (-not (Test-Path -LiteralPath $runSettings -PathType Leaf)) {
    throw "Shared test run settings not found: $runSettings"
}

$databaseName = Get-DatabaseNameFromConnectionString -Value $ConnectionString
$systemDatabases = @('master', 'model', 'msdb', 'tempdb')
if ($systemDatabases -contains $databaseName.ToLowerInvariant()) {
    throw "Refusing to run SQL integration tests against system database '$databaseName'."
}

$hasSafePrefix = $databaseName.StartsWith('CymBuild_Test_', [System.StringComparison]::OrdinalIgnoreCase)
$isExplicitlyAllowed = -not [string]::IsNullOrWhiteSpace($AllowedDatabaseName) -and
    [string]::Equals($databaseName, $AllowedDatabaseName, [System.StringComparison]::OrdinalIgnoreCase)

if (-not $hasSafePrefix -and -not $isExplicitlyAllowed) {
    throw "Refusing to run SQL integration tests against '$databaseName'. Use a dedicated CymBuild_Test_* database or pass -AllowedDatabaseName explicitly."
}

if ($ValidateConnectionStringOnly) {
    Write-Host "SQL test connection string validated for dedicated database '$databaseName'."
    return
}

$dotnet = Get-Command dotnet -ErrorAction Stop
$sdkVersion = (& $dotnet.Source --version).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the installed .NET SDK version.'
}
$majorVersion = 0
if (-not [int]::TryParse(($sdkVersion -split '\.')[0], [ref]$majorVersion) -or $majorVersion -lt 10) {
    throw "CymBuild SQL integration tests require .NET SDK 10 or later. Installed version: $sdkVersion"
}

if ([string]::IsNullOrWhiteSpace($ResultsRoot)) {
    $runStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
    $ResultsRoot = Join-Path $RepoRoot "TestResults\sql-integration\$runStamp"
}
else {
    $ResultsRoot = [System.IO.Path]::GetFullPath($ResultsRoot)
}
New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null

$projectName = 'CymBuild.Database.IntegrationTests'
$trxPath = Join-Path $ResultsRoot "$projectName.trx"
$arguments = @(
    'test',
    $project,
    '--configuration', $Configuration,
    '--settings', $runSettings,
    '--results-directory', $ResultsRoot,
    '--logger', "trx;LogFileName=$projectName.trx"
)
if ($NoRestore) { $arguments += '--no-restore' }
if ($NoBuild) { $arguments += '--no-build' }
if (-not $NoCoverage) {
    $arguments += '--collect'
    $arguments += 'XPlat Code Coverage'
}

$previousConnectionString = $env:CYMBUILD_SQL_TEST_CONNECTION_STRING
$previousAllowedDatabase = $env:CYMBUILD_SQL_TEST_ALLOWED_DATABASE
$previousDotnetTelemetry = $env:DOTNET_CLI_TELEMETRY_OPTOUT
$previousTestingTelemetry = $env:TESTINGPLATFORM_TELEMETRY_OPTOUT
$env:CYMBUILD_SQL_TEST_CONNECTION_STRING = $ConnectionString
$env:CYMBUILD_SQL_TEST_ALLOWED_DATABASE = if ($isExplicitlyAllowed) { $databaseName } else { '' }
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:TESTINGPLATFORM_TELEMETRY_OPTOUT = '1'

$startedUtc = (Get-Date).ToUniversalTime()
try {
    Write-Host "Running SQL integration tests against dedicated database '$databaseName'."
    Invoke-DotNet -Arguments $arguments -Description 'SQL integration tests'
}
finally {
    $env:CYMBUILD_SQL_TEST_CONNECTION_STRING = $previousConnectionString
    $env:CYMBUILD_SQL_TEST_ALLOWED_DATABASE = $previousAllowedDatabase
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = $previousDotnetTelemetry
    $env:TESTINGPLATFORM_TELEMETRY_OPTOUT = $previousTestingTelemetry
}
$finishedUtc = (Get-Date).ToUniversalTime()

$counts = Get-TrxCounts -Path $trxPath
if ($counts.Total -ne 22 -or $counts.Passed -ne 22 -or $counts.Failed -ne 0 -or $counts.Skipped -ne 0) {
    throw "Unexpected SQL integration result. Expected 22 passed, 0 failed, 0 skipped; actual total=$($counts.Total), passed=$($counts.Passed), failed=$($counts.Failed), skipped=$($counts.Skipped)."
}

if (-not $NoCoverage) {
    $coverage = @(Get-ChildItem -LiteralPath $ResultsRoot -Recurse -Filter 'coverage.cobertura.xml' -File)
    if ($coverage.Count -eq 0) {
        throw 'SQL integration coverage.cobertura.xml was not produced.'
    }
}

$summary = [pscustomobject]@{
    SchemaVersion = 1
    Scope = 'SqlIntegration'
    Configuration = $Configuration
    DatabaseName = $databaseName
    DotNetSdkVersion = $sdkVersion
    StartedUtc = $startedUtc.ToString('o')
    FinishedUtc = $finishedUtc.ToString('o')
    DurationSeconds = [math]::Round(($finishedUtc - $startedUtc).TotalSeconds, 3)
    Total = $counts.Total
    Passed = $counts.Passed
    Failed = $counts.Failed
    Skipped = $counts.Skipped
    CoverageCollected = -not $NoCoverage
    Succeeded = $true
}
$summaryPath = Join-Path $ResultsRoot 'sql-integration-test-run.json'
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "SQL integration results: $ResultsRoot"
Write-Host "Run summary            : $summaryPath"
Write-Host 'All CymBuild SQL integration tests passed.'
