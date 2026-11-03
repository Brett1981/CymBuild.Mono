<#
.SYNOPSIS
    Stops the local Concursus.API / Concursus.PWA processes started by
    Start-CymBuildLocal.ps1.
#>
[CmdletBinding()]
param()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$logDir = Join-Path $repoRoot 'artifacts\local-run'

foreach ($name in 'api', 'pwa') {
    $pidFile = Join-Path $logDir "$name.pid"
    if (Test-Path $pidFile) {
        $procId = Get-Content $pidFile
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -ErrorAction SilentlyContinue
        Write-Host "Stopped $name (PID $procId)"
    }
}
