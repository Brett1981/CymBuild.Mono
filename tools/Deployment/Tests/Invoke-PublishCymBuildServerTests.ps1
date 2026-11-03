#requires -Version 7.2
# Offline tests for tools/Deployment/Publish-CymBuildServer.ps1. Builds a fake package with the deploy
# script's own manifest code, then runs the server-side functions under Windows PowerShell 5.1.
# Usage: pwsh -File tools/Deployment/Tests/Invoke-PublishCymBuildServerTests.ps1
$ErrorActionPreference = 'Stop'
$script = (Resolve-Path (Join-Path $PSScriptRoot '..\Publish-CymBuildServer.ps1')).Path
$work = Join-Path ([IO.Path]::GetTempPath()) 'cymbuild-publish-server-tests'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory $work | Out-Null

# Load New-FileManifest from the real script
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'New-FileManifest' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))

function New-Package([string]$Name) {
    $stage = Join-Path $work "stage-$Name"
    $api = Join-Path $stage 'api'
    New-Item -ItemType Directory (Join-Path $api 'sub') -Force | Out-Null
    Set-Content (Join-Path $api 'Concursus.API.dll') "dll $Name"
    Set-Content (Join-Path $api 'sub\nested.dll') 'nested'
    Set-Content (Join-Path $api 'appsettings.json') '{ "Logging": { "Level": "x" }, "Features": { "NewFlag": "secret-value" } }'
    Set-Content (Join-Path $api 'appsettings.QA.json') '{ "ConnectionStrings": { "A": "secret-value" } }'
    Set-Content (Join-Path $api 'web.config') '<build-web-config/>'
    Set-Content (Join-Path $api 'nlog.config') '<build-nlog/>'
    $count = New-FileManifest $api (Join-Path $stage 'manifest-api.tsv')
    '{ "Release": "' + $Name + '" }' | Set-Content (Join-Path $stage 'release.json')
    $zip = Join-Path $work "$Name.zip"
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
    $zip
}
$zip1 = New-Package 'R1'
$null = New-Package 'R2'
New-Item -ItemType Directory (Join-Path $work 'deployroot\incoming') -Force | Out-Null
Move-Item $zip1 (Join-Path $work 'deployroot\incoming\R1.zip')

# Fake live API folder
$live = Join-Path $work 'live-api'
New-Item -ItemType Directory (Join-Path $live 'logs') -Force | Out-Null
Set-Content (Join-Path $live 'Concursus.API.dll') 'old'
Set-Content (Join-Path $live 'old-only.dll') 'old'
Set-Content (Join-Path $live 'appsettings.json') '{ "Logging": { "Level": "server" } }'
Set-Content (Join-Path $live 'web.config') '<server-web-config/>'
Set-Content (Join-Path $live 'nlog.config') '<server-nlog/>'
Set-Content (Join-Path $live 'logs\app.log') 'log'

& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-CymBuildDatabaseSettings.ps1') -Work $work
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-PublishCymBuildServerRemote.ps1') -ScriptPath $script -Work $work
exit $LASTEXITCODE
