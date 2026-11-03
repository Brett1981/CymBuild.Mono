<#
.SYNOPSIS
    Starts Concursus.API and Concursus.PWA locally for browser-driven UI work
    (e.g. the cymbuild-uitest skill), on the exact ports the app actually needs.

.DESCRIPTION
    Two things bite anyone starting this app ad hoc:
      1. The PWA's Azure AD app registration only allows the redirect URI
         https://localhost:44368/authentication/login-callback. `dotnet run`
         with no launch profile picks a default Kestrel port (e.g. 5000) and
         sign-in fails with AADSTS50011. This script forces ASPNETCORE_URLS
         to the registered port.
      2. There's no "Project"/Kestrel launch profile for the PWA in
         launchSettings.json (only IISExpress ones), so `dotnet run` needs
         the URL forced via environment variable, not --launch-profile.

    Idempotent: if both ports are already listening, does nothing and just
    reports the URLs. Safe to call before every cymbuild-uitest run.

.NOTES
    "Local" only means the API/PWA processes run on this machine - the DB
    connection in appsettings.Development.json still points at the shared
    CymBuild_DEV SQL Server. This script does not touch the database.
#>
[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$logDir = Join-Path $repoRoot 'artifacts\local-run'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$apiPort = 7202
$pwaPort = 44368

function Test-PortListening([int]$Port) {
    return [bool](Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -eq $Port })
}

$apiWasUp = Test-PortListening $apiPort
$pwaWasUp = Test-PortListening $pwaPort

if ($apiWasUp -and $pwaWasUp) {
    Write-Host "Already running - API: https://localhost:$apiPort  PWA: https://localhost:$pwaPort"
    return
}

if (-not $apiWasUp) {
    Write-Host "Starting Concursus.API (Kestrel, Development)..."
    $apiLog = Join-Path $logDir 'api.log'
    $apiErr = Join-Path $logDir 'api.err.log'
    $apiProc = Start-Process -FilePath 'dotnet' `
        -ArgumentList @('run', '--project', 'services\Concursus.API\Concursus.API.csproj', '--launch-profile', '"API - Dev (Kestrel)"') `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $apiLog -RedirectStandardError $apiErr `
        -WindowStyle Hidden -PassThru `
        -Environment @{ ASPNETCORE_ENVIRONMENT = 'Development'; DOTNET_ENVIRONMENT = 'Development' }
    $apiProc.Id | Out-File (Join-Path $logDir 'api.pid') -Encoding ascii

    # API and PWA both build Concursus.Common.Shared. Starting both `dotnet run`
    # builds at once races on that project's obj\ output and one build fails
    # with CS2012 (file locked by the other's MSBuild/VBCSCompiler worker).
    # Wait for the API to finish starting before kicking off the PWA build.
    if (-not $pwaWasUp) {
        Write-Host "Waiting for API to come up before starting PWA build (avoids a shared-project build race)..."
        $apiDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $apiDeadline -and -not (Test-PortListening $apiPort)) {
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $pwaWasUp) {
    Write-Host "Starting Concursus.PWA, forced onto the AAD-registered port $pwaPort..."
    $pwaLog = Join-Path $logDir 'pwa.log'
    $pwaErr = Join-Path $logDir 'pwa.err.log'
    $pwaProc = Start-Process -FilePath 'dotnet' `
        -ArgumentList @('run', '--project', 'apps\Concursus.PWA\Concursus.PWA.csproj') `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $pwaLog -RedirectStandardError $pwaErr `
        -WindowStyle Hidden -PassThru `
        -Environment @{
            ASPNETCORE_ENVIRONMENT = 'Development'
            DOTNET_ENVIRONMENT = 'Development'
            ASPNETCORE_URLS = "https://localhost:$pwaPort;http://localhost:28213"
        }
    $pwaProc.Id | Out-File (Join-Path $logDir 'pwa.pid') -Encoding ascii
}

Write-Host "Waiting for both ports to come up (timeout ${TimeoutSeconds}s - first build can be slow)..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if ((Test-PortListening $apiPort) -and (Test-PortListening $pwaPort)) {
        Write-Host "Ready - API: https://localhost:$apiPort  PWA: https://localhost:$pwaPort"
        return
    }
    Start-Sleep -Seconds 5
}

$apiUp = Test-PortListening $apiPort
$pwaUp = Test-PortListening $pwaPort
Write-Warning "Timed out after ${TimeoutSeconds}s - API up: $apiUp, PWA up: $pwaUp"
Write-Warning "Check logs: $logDir\api.log / $logDir\pwa.log (tail them, don't cat in full - they're verbose build output)"
exit 1
