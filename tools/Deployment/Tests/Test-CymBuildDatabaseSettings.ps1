#requires -Version 7.2
# Offline tests for the database-name resolution in tools/Deployment/CymBuildDatabaseDeploy.ps1.
# Called by Invoke-PublishCymBuildServerTests.ps1. Touches no database.
param([Parameter(Mandatory)][string]$Work)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $PSScriptRoot '..\CymBuildDatabaseDeploy.ps1')

$failures = 0
function Check([string]$Name, [scriptblock]$Test) {
    try { if (& $Test) { Write-Host "PASS $Name" } else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failures++ } }
    catch { Write-Host "FAIL $Name : $($_.Exception.Message)" -ForegroundColor Red; $script:failures++ }
}
function Throws([scriptblock]$Action, [string]$Like) {
    try { & $Action; $false } catch { $_.Exception.Message -like $Like }
}

$dir = Join-Path $Work 'settings\services\Concursus.API'
New-Item -ItemType Directory $dir -Force | Out-Null
function Set-Settings([string]$Name, [string]$Json) { Set-Content -LiteralPath (Join-Path $dir $Name) -Value $Json }

Set-Settings 'appsettings.Target.json' @'
{
  // comments and URLs must not confuse the parser: https://example
  "ConnectionStrings": {
    "ShoreDB": "Data Source=SQL01\\SQL2022;Initial Catalog=CymBuild_UAT_Renamed;Integrated Security=True;TrustServerCertificate=True;"
  }
}
'@
Set-Settings 'appsettings.Source.json' '{ "ConnectionStrings": { "ShoreDB": "Data Source=10.0.0.1\\general;Initial Catalog=CymBuild_QA9;Integrated Security=True;" } }'
Set-Settings 'appsettings.Default.json' '{ "ConnectionStrings": { "CymBuild": "Data Source=a;Initial Catalog=Low;", "ShoreDB": "Data Source=b;Initial Catalog=Mid;", "DefaultConnection": "Data Source=c;Initial Catalog=High;" } }'
Set-Settings 'appsettings.Live.json' '{ "ConnectionStrings": { "ShoreDB": "Data Source=SQL01\\SQL2022;Initial Catalog=Concursus;" } }'
Set-Settings 'appsettings.Prod.json' '{ "ConnectionStrings": { "ShoreDB": "Data Source=x;Initial Catalog=CymBuild_Prod;" } }'
Set-Settings 'appsettings.None.json' '{ "Logging": {} }'
Set-Settings 'appsettings.NoCatalog.json' '{ "ConnectionStrings": { "ShoreDB": "Data Source=x;Integrated Security=True;" } }'
$root = Join-Path $Work 'settings'

Check 'reads server and database from ShoreDB' {
    $r = Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $dir 'appsettings.Target.json')
    $r.Server -eq 'SQL01\SQL2022' -and $r.Database -eq 'CymBuild_UAT_Renamed' -and $r.Key -eq 'ShoreDB'
}
Check 'DefaultConnection wins over ShoreDB and CymBuild (API order)' {
    (Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $dir 'appsettings.Default.json')).Database -eq 'High'
}
Check 'missing connection string is refused' { Throws { Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $dir 'appsettings.None.json') } '*No ConnectionStrings*' }
Check 'missing Initial Catalog is refused' { Throws { Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $dir 'appsettings.NoCatalog.json') } '*no Data Source or Initial Catalog*' }
Check 'missing file is refused' { Throws { Get-CymBuildDatabaseFromAppSettings -Path (Join-Path $dir 'nope.json') } '*not found*' }

Check 'resolves target and source with source environment' {
    $r = Resolve-CymBuildDeployDatabases -RepoRoot $root -Target @{ AppSettings = 'appsettings.Target.json'; SourceAppSettings = 'appsettings.Source.json'; SourceEnvironment = 'QA' }
    $r.Target.Database -eq 'CymBuild_UAT_Renamed' -and $r.Source.Database -eq 'CymBuild_QA9' -and $r.Source.Server -eq '10.0.0.1\general' -and $r.SourceEnvironment -eq 'QA'
}
Check 'LIVE database name is refused' {
    Throws { Resolve-CymBuildDeployDatabases -RepoRoot $root -Target @{ AppSettings = 'appsettings.Live.json'; SourceAppSettings = 'appsettings.Source.json'; SourceEnvironment = 'QA' } } '*looks like LIVE*'
}
Check 'prod database name is refused' {
    Throws { Resolve-CymBuildDeployDatabases -RepoRoot $root -Target @{ AppSettings = 'appsettings.Prod.json'; SourceAppSettings = 'appsettings.Source.json'; SourceEnvironment = 'QA' } } '*looks like LIVE*'
}
Check 'same source and target is refused' {
    Throws { Resolve-CymBuildDeployDatabases -RepoRoot $root -Target @{ AppSettings = 'appsettings.Source.json'; SourceAppSettings = 'appsettings.Source.json'; SourceEnvironment = 'QA' } } '*must differ*'
}

# The committed settings the real targets use.
Check 'repo QA target resolves (appsettings.QA.json from appsettings.Development.json)' {
    $r = Resolve-CymBuildDeployDatabases -RepoRoot $repoRoot -Target @{ AppSettings = 'appsettings.QA.json'; SourceAppSettings = 'appsettings.Development.json'; SourceEnvironment = 'DEV' }
    Write-Host "     QA : $($r.Target.Server) / $($r.Target.Database) <- $($r.Source.Server) / $($r.Source.Database)"
    $true
}
Check 'repo UAT target resolves (appsettings.Test.json from appsettings.QA.json)' {
    $r = Resolve-CymBuildDeployDatabases -RepoRoot $repoRoot -Target @{ AppSettings = 'appsettings.Test.json'; SourceAppSettings = 'appsettings.QA.json'; SourceEnvironment = 'QA' }
    Write-Host "     UAT: $($r.Target.Server) / $($r.Target.Database) <- $($r.Source.Server) / $($r.Source.Database)"
    $true
}
Check 'repo LIVE settings would be refused' { Test-CymBuildLiveDatabaseName -Server 'SOC-SQLBRE01\SQL2022' -Database 'Concursus' }

if ($failures) { Write-Host "$failures database-settings test(s) failed" -ForegroundColor Red; exit 1 }
Write-Host 'All database-settings tests passed'
