[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

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
    [switch]$ListOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directorySeparators = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd($directorySeparators) + [System.IO.Path]::DirectorySeparatorChar
    $pathFullPath = [System.IO.Path]::GetFullPath($Path)
    $baseUri = New-Object System.Uri -ArgumentList $baseFullPath
    $pathUri = New-Object System.Uri -ArgumentList $pathFullPath
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}


function Get-TrxResultSummary {
    param([Parameter(Mandatory = $true)][string]$TrxPath)

    if (-not (Test-Path -LiteralPath $TrxPath -PathType Leaf)) {
        return [pscustomobject]@{
            Total = $null
            Passed = $null
            Failed = $null
            Skipped = $null
            FailedTests = @()
        }
    }

    try {
        [xml]$trx = Get-Content -LiteralPath $TrxPath -Raw
        $resultNodes = @($trx.SelectNodes("//*[local-name()='UnitTestResult']"))
        $failedTests = New-Object System.Collections.Generic.List[object]

        foreach ($resultNode in $resultNodes) {
            if ([string]$resultNode.outcome -ne 'Failed') {
                continue
            }

            $messageNode = $resultNode.SelectSingleNode(
                "./*[local-name()='Output']/*[local-name()='ErrorInfo']/*[local-name()='Message']"
            )
            $failedTests.Add([pscustomobject]@{
                Name = [string]$resultNode.testName
                Message = if ($null -eq $messageNode) { '' } else { [string]$messageNode.InnerText }
            })
        }

        return [pscustomobject]@{
            Total = $resultNodes.Count
            Passed = @($resultNodes | Where-Object { [string]$_.outcome -eq 'Passed' }).Count
            Failed = $failedTests.Count
            Skipped = @($resultNodes | Where-Object { [string]$_.outcome -in @('NotExecuted', 'Skipped') }).Count
            FailedTests = $failedTests.ToArray()
        }
    }
    catch {
        return [pscustomobject]@{
            Total = $null
            Passed = $null
            Failed = $null
            Skipped = $null
            FailedTests = @([pscustomobject]@{
                Name = '<TRX parse failure>'
                Message = $_.Exception.Message
            })
        }
    }
}

function Test-IsExcludedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    return $RelativePath -match '^(?:_patch_backups|TestResults|artifacts|CYB[^\\]*|SQL_CI_Packs(?:_Metadata)?)\\' -or
           $RelativePath -match '(?:^|\\)(?:bin|obj)\\'
}

function Test-IsTestProject {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$ProjectFile)

    if ($ProjectFile.BaseName -match '(?i)Tests$') {
        return $true
    }

    try {
        [xml]$projectXml = Get-Content -LiteralPath $ProjectFile.FullName -Raw
        $isTestProjectNodes = @($projectXml.SelectNodes(
            "/*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='IsTestProject']"
        ))
        foreach ($isTestProjectNode in $isTestProjectNodes) {
            if ([string]$isTestProjectNode.InnerText -eq 'true') {
                return $true
            }
        }
    }
    catch {
        throw "Unable to parse project '$($ProjectFile.FullName)': $($_.Exception.Message)"
    }

    return $false
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$runSettings = Join-Path $RepoRoot 'tests\CymBuild.Testing.runsettings'
if (-not (Test-Path -LiteralPath $runSettings -PathType Leaf)) {
    throw "Test run settings were not found at '$runSettings'."
}

$allProjects = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter '*.csproj' -File | ForEach-Object {
    $relativePath = Get-RelativePath -BasePath $RepoRoot -Path $_.FullName
    [pscustomobject]@{
        File = $_
        RelativePath = $relativePath
    }
} | Where-Object {
    -not (Test-IsExcludedRepositoryPath -RelativePath $_.RelativePath)
}

$testProjects = @($allProjects | Where-Object {
    (Test-IsTestProject -ProjectFile $_.File) -and
    $_.File.BaseName -notmatch '(?i)(IntegrationTests|EndToEnd\.Tests)$'
} | Sort-Object RelativePath)

if ($testProjects.Count -eq 0) {
    throw 'No fast test projects were discovered.'
}

Write-Host 'CymBuild fast test projects:'
foreach ($project in $testProjects) {
    Write-Host "  $($project.RelativePath)"
}

if ($ListOnly) {
    return
}

$dotnet = Get-Command dotnet -ErrorAction Stop
$versionText = (& $dotnet.Source --version).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the installed .NET SDK version.'
}

$majorVersion = 0
if (-not [int]::TryParse(($versionText -split '\.')[0], [ref]$majorVersion) -or $majorVersion -lt 10) {
    throw "CymBuild fast tests require .NET SDK 10 or later. Installed version: $versionText"
}

if ([string]::IsNullOrWhiteSpace($ResultsRoot)) {
    $runStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
    $ResultsRoot = Join-Path $RepoRoot "TestResults\fast\$runStamp"
}
else {
    $ResultsRoot = [System.IO.Path]::GetFullPath($ResultsRoot)
}

New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null

$previousDotnetTelemetry = $env:DOTNET_CLI_TELEMETRY_OPTOUT
$previousTestingTelemetry = $env:TESTINGPLATFORM_TELEMETRY_OPTOUT
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:TESTINGPLATFORM_TELEMETRY_OPTOUT = '1'

$startedUtc = (Get-Date).ToUniversalTime()
$results = New-Object System.Collections.Generic.List[object]
try {
    foreach ($project in $testProjects) {
        $projectName = $project.File.BaseName
        $projectResultRoot = Join-Path $ResultsRoot $projectName
        New-Item -ItemType Directory -Path $projectResultRoot -Force | Out-Null

        $arguments = @(
            'test',
            $project.File.FullName,
            '--configuration', $Configuration,
            '--settings', $runSettings,
            '--results-directory', $projectResultRoot,
            '--logger', "trx;LogFileName=$projectName.trx"
        )

        if ($NoRestore) {
            $arguments += '--no-restore'
        }
        if ($NoBuild) {
            $arguments += '--no-build'
        }
        if (-not $NoCoverage) {
            $arguments += '--collect'
            $arguments += 'XPlat Code Coverage'
        }

        Write-Host ''
        Write-Host "Running $($project.RelativePath)"
        $projectStartedUtc = (Get-Date).ToUniversalTime()

        # Windows PowerShell 5.1 exposes native stderr as PowerShell error records.
        # A failed test process must still be allowed to return its real exit code so
        # every project result and the run summary can be recorded before we fail.
        $previousErrorActionPreference = $ErrorActionPreference
        $exitCode = -1
        try {
            $ErrorActionPreference = 'Continue'
            & $dotnet.Source @arguments
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $projectFinishedUtc = (Get-Date).ToUniversalTime()
        $trxPath = Join-Path $projectResultRoot "$projectName.trx"
        $trxSummary = Get-TrxResultSummary -TrxPath $trxPath

        $results.Add([pscustomobject]@{
            Project = $project.RelativePath
            ExitCode = $exitCode
            StartedUtc = $projectStartedUtc.ToString('o')
            FinishedUtc = $projectFinishedUtc.ToString('o')
            DurationSeconds = [math]::Round(($projectFinishedUtc - $projectStartedUtc).TotalSeconds, 3)
            ResultsDirectory = $projectResultRoot
            TrxPath = $trxPath
            Total = $trxSummary.Total
            Passed = $trxSummary.Passed
            Failed = $trxSummary.Failed
            Skipped = $trxSummary.Skipped
            FailedTests = @($trxSummary.FailedTests)
        })
    }
}
finally {
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = $previousDotnetTelemetry
    $env:TESTINGPLATFORM_TELEMETRY_OPTOUT = $previousTestingTelemetry
}

$finishedUtc = (Get-Date).ToUniversalTime()
$failedProjects = @($results | Where-Object { $_.ExitCode -ne 0 })
$summary = [pscustomobject]@{
    SchemaVersion = 1
    Scope = 'Fast'
    Configuration = $Configuration
    CoverageCollected = -not $NoCoverage
    DotNetSdkVersion = $versionText
    StartedUtc = $startedUtc.ToString('o')
    FinishedUtc = $finishedUtc.ToString('o')
    DurationSeconds = [math]::Round(($finishedUtc - $startedUtc).TotalSeconds, 3)
    Succeeded = $failedProjects.Count -eq 0
    Projects = $results.ToArray()
}

$summaryPath = Join-Path $ResultsRoot 'fast-test-run.json'
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ''
Write-Host "Test results: $ResultsRoot"
Write-Host "Run summary : $summaryPath"

if ($failedProjects.Count -gt 0) {
    $failureDetails = New-Object System.Collections.Generic.List[string]
    foreach ($failedProject in $failedProjects) {
        $failedTestNames = @($failedProject.FailedTests | ForEach-Object { $_.Name })
        if ($failedTestNames.Count -gt 0) {
            $failureDetails.Add(
                "$($failedProject.Project) [$($failedTestNames -join '; ')]"
            )
        }
        else {
            $failureDetails.Add($failedProject.Project)
        }
    }

    throw "One or more fast test projects failed: $($failureDetails -join ', ')"
}

Write-Host 'All CymBuild fast test projects passed.'
