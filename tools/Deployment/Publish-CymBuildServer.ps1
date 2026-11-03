#requires -Version 7.2
<#
.SYNOPSIS
Builds, transfers and deploys the CymBuild API and PWA to QA or UAT on SOC-CONIIS.

.DESCRIPTION
Replaces the manual "publish to a folder, back up by hand, copy over RDP" process for QA and UAT.

1. Local checks: clean working tree, recorded branch and commit.
2. Remote read-only preflight over PowerShell remoting (Kerberos, admin account):
   the Windows service, IIS site and app pool exist and point at the expected folders,
   there is enough disk, and no other deployment holds the lock.
3. dotnet publish (Release) of each component, SHA-256 manifest, single zip.
4. Zip copied to the server, hash checked, extracted and every file re-verified.
5. Database phase (see CymBuildDatabaseDeploy.ps1; skip with -SkipDatabase):
   verified COPY_ONLY backup -> schema -> metadata (only if schema succeeded).
   Each step uses an accepted-but-unapplied workbench run if there is one, otherwise it
   creates a run selecting every difference the apply step supports. The source is the
   previous environment (QA from DEV, UAT from QA). Schema source is synced from it and
   committed before the schema apply. A failed step is reported and the
   remaining database steps are skipped; the application deployment always continues.
6. Current live folders backed up, then per component:
   API: stop service -> mirror files -> verify -> start service -> health check.
   PWA: stop app pool -> mirror files -> verify -> start app pool -> health check.
7. Any failure after a live folder has changed restores that component from the
   backup taken in step 6 and restarts it.

Server-owned files are never overwritten or deleted: appsettings*.json, web.config, nlog.config and the
logs folder. Environment configuration stays on the server. New configuration keys in the
build that are missing from the server appsettings.json are reported by NAME only.

QA and UAT are configured. LIVE is deliberately absent and stays manual. The target and source
databases are read from the environment's committed services\Concursus.API\appsettings.<env>.json
(QA: appsettings.QA.json from appsettings.Development.json; UAT: appsettings.Test.json from
appsettings.QA.json), so a renamed database only needs that file changed.

.EXAMPLE
# Read-only: local checks, remote preflight and plan. No build, no changes.
./tools/Deployment/Publish-CymBuildServer.ps1 -WhatIf

.EXAMPLE
# Deploy the API and PWA from the current clean checkout.
./tools/Deployment/Publish-CymBuildServer.ps1

.EXAMPLE
# Deploy to UAT (database migrated from QA). Preview first with -WhatIf.
./tools/Deployment/Publish-CymBuildServer.ps1 -Environment UAT

.EXAMPLE
# Deploy only the PWA, without the database phase.
./tools/Deployment/Publish-CymBuildServer.ps1 -Component Pwa -SkipDatabase

.EXAMPLE
# Put back the most recent backup (itself backed up first, so this is reversible).
./tools/Deployment/Publish-CymBuildServer.ps1 -RestoreBackup latest

.NOTES
Requires: PowerShell 7.2+ locally, the .NET 10 SDK, and an account that is a local
administrator on the server (for example ESGL\<you>_adm). The server needs only
Windows PowerShell 5.1 and WinRM, both already present.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'Deploy')]
param(
    [ValidateSet('QA', 'UAT')]
    [string]$Environment = 'QA',

    [ValidateSet('Api', 'Pwa')]
    [string[]]$Component = @('Api', 'Pwa'),

    [Parameter(ParameterSetName = 'Deploy')]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{2,80}$')]
    [string]$ReleaseName,

    [Parameter(ParameterSetName = 'Deploy')]
    [switch]$SkipDatabase,

    [Parameter(Mandatory, ParameterSetName = 'Restore')]
    [ValidatePattern('^(latest|[A-Za-z0-9][A-Za-z0-9._-]{2,120})$')]
    [string]$RestoreBackup,

    [pscredential]$Credential,

    [ValidateRange(1, 20)]
    [int]$KeepReleases = 3,

    [ValidateRange(5, 300)]
    [int]$StabiliseSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------ target configuration
# Server facts confirmed by read-only discovery of SOC-CONIIS on 2026-10-13.
# Databases are not listed here: they are read from services\Concursus.API\<AppSettings> (target)
# and <SourceAppSettings> (the previous environment) in the commit being deployed.
$Targets = @{
    QA = @{
        ComputerName      = 'soc-coniis.esgl.co.uk'
        DeployRoot        = 'C:\CymBuildDeploy\QA'
        AppSettings       = 'appsettings.QA.json'
        SourceEnvironment = 'DEV'
        SourceAppSettings = 'appsettings.Development.json'
        Api               = @{
            Project     = 'services\Concursus.API\Concursus.API.csproj'
            ServiceName = 'Concursus.API_dev'
            Path        = 'C:\Program Files\Concursus.API_Dev'
            ProbeUri    = 'https://cymbuild-dev.socotec.co.uk:9401/'
        }
        Pwa               = @{
            Project  = 'apps\Concursus.PWA\Concursus.PWA.csproj'
            SiteName = 'Concursus.PWA_Dev'
            AppPool  = 'Concursus.PWA_Dev'
            Path     = 'C:\inetpub\wwwroot\Concursus.PWA_Dev'
            BaseUri  = 'https://cymbuild-dev.socotec.co.uk/'
        }
    }
    UAT = @{
        ComputerName      = 'soc-coniis.esgl.co.uk'
        DeployRoot        = 'C:\CymBuildDeploy\UAT'
        AppSettings       = 'appsettings.Test.json'
        SourceEnvironment = 'QA'
        SourceAppSettings = 'appsettings.QA.json'
        Api               = @{
            Project     = 'services\Concursus.API\Concursus.API.csproj'
            ServiceName = 'Concursus.API_Test'
            Path        = 'C:\Program Files\Concursus.API_Test'
            ProbeUri    = 'https://cymbuild-uat.socotec.co.uk:9501/'
        }
        Pwa               = @{
            Project  = 'apps\Concursus.PWA\Concursus.PWA.csproj'
            SiteName = 'Concursus.PWA_Test'
            AppPool  = 'Concursus.PWA_Test'
            Path     = 'C:\inetpub\wwwroot\Concursus.PWA_Test'
            BaseUri  = 'https://cymbuild-uat.socotec.co.uk/'
        }
    }
}

# Files and folders that belong to the server, never to the build.
$ServerOwnedFilePatterns = @('appsettings*.json', 'web.config', 'nlog.config')
$ServerOwnedDirectories = @('logs')

$target = $Targets[$Environment]
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$isRestore = $PSCmdlet.ParameterSetName -eq 'Restore'
$runDatabase = -not $isRestore -and -not $SkipDatabase
. (Join-Path $PSScriptRoot 'CymBuildDatabaseDeploy.ps1')

function Write-Phase([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Note([string]$Message) { Write-Host "    $Message" }
function Write-Warn([string]$Message) { Write-Host "    WARNING: $Message" -ForegroundColor Yellow }

function Invoke-Native {
    param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)][string[]]$ArgumentList, [Parameter(Mandatory)][string]$Description)
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "$Description failed with exit code $LASTEXITCODE." }
}

function Get-GitValue([string[]]$Arguments) {
    $value = & git -C $repoRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed." }
    ($value -join "`n").Trim()
}

# Writes SHA256<TAB>Length<TAB>RelativePath for every file under $Root; returns the file count.
function New-FileManifest([string]$Root, [string]$OutFile) {
    $rootFull = (Resolve-Path $Root).Path.TrimEnd('\') + '\'
    $lines = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        "{0}`t{1}`t{2}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Length, $_.FullName.Substring($rootFull.Length)
    }
    [IO.File]::WriteAllLines($OutFile, [string[]]$lines)
    @($lines).Count
}

# ------------------------------------------------------------------ remote code (Windows PowerShell 5.1)
# One script block holds every server-side function; $Action selects the operation.
# Keep it 5.1-compatible: no ternary, no ??, Join-Path with two arguments only.
$RemoteScript = {
    param(
        [string]$Action,
        [hashtable]$Cfg,
        [string[]]$Components,
        [string[]]$OwnedFiles,
        [string[]]$OwnedDirs,
        [hashtable]$Options
    )

    Set-StrictMode -Version 2.0
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $deployRoot = $Cfg.DeployRoot
    $releasesRoot = Join-Path $deployRoot 'releases'
    $backupsRoot = Join-Path $deployRoot 'backups'
    $incomingRoot = Join-Path $deployRoot 'incoming'
    $lockPath = Join-Path $deployRoot 'deploy.lock'
    $currentPath = Join-Path $deployRoot 'current.json'
    $historyPath = Join-Path $deployRoot 'history.log'

    function Say([string]$Message) { Write-Host ("    [server] {0}" -f $Message) }

    function Test-ServerOwned([string]$RelativePath) {
        $leaf = Split-Path $RelativePath -Leaf
        foreach ($p in $OwnedFiles) { if ($leaf -like $p) { return $true } }
        $segments = @($RelativePath -split '\\')
        if ($segments.Count -gt 1) {
            foreach ($seg in $segments[0..($segments.Count - 2)]) { if ($OwnedDirs -contains $seg) { return $true } }
        }
        return $false
    }

    function Assert-UnderDeployRoot([string]$Path) {
        $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $root = [IO.Path]::GetFullPath($deployRoot).TrimEnd('\') + '\'
        if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to touch '$Path': outside $deployRoot." }
    }

    function Get-RelativeFiles([string]$Root) {
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        $result = @{}
        Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -ErrorAction Stop | ForEach-Object {
            $rel = $_.FullName.Substring($rootFull.Length)
            if (-not (Test-ServerOwned $rel)) { $result[$rel] = $_.Length }
        }
        $result
    }

    function Assert-TreesMatch([string]$Source, [string]$Destination) {
        $src = Get-RelativeFiles $Source
        $dst = Get-RelativeFiles $Destination
        $problems = @()
        foreach ($k in $src.Keys) {
            if (-not $dst.ContainsKey($k)) { $problems += "missing: $k" }
            elseif ($dst[$k] -ne $src[$k]) { $problems += "size differs: $k" }
        }
        foreach ($k in $dst.Keys) { if (-not $src.ContainsKey($k)) { $problems += "unexpected: $k" } }
        if ($problems.Count -gt 0) {
            throw ("Folder verification failed for {0} ({1} problems), first: {2}" -f $Destination, $problems.Count, (($problems | Select-Object -First 5) -join '; '))
        }
        Say ("verified {0} files in {1}" -f $src.Count, $Destination)
    }

    # manifest-<component>.tsv lines: SHA256<TAB>Length<TAB>RelativePath (plain text avoids 5.1 JSON size limits)
    function Read-Manifest([string]$Path) {
        $files = @{}
        foreach ($line in [IO.File]::ReadAllLines($Path)) {
            if (-not $line) { continue }
            $parts = $line.Split("`t")
            $files[$parts[2]] = $parts[0]
        }
        $files
    }

    function Assert-ManifestHashes([string]$Root, [hashtable]$Files, [switch]$SkipServerOwned) {
        $bad = @()
        $checked = 0
        foreach ($rel in $Files.Keys) {
            if ($SkipServerOwned -and (Test-ServerOwned $rel)) { continue }
            $path = Join-Path $Root $rel
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $bad += "missing: $rel"; continue }
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($hash -ne $Files[$rel]) { $bad += "hash differs: $rel" }
            $checked++
        }
        if ($bad.Count -gt 0) {
            throw ("SHA-256 verification failed under {0} ({1} problems), first: {2}" -f $Root, $bad.Count, (($bad | Select-Object -First 5) -join '; '))
        }
        Say ("SHA-256 verified {0} files under {1}" -f $checked, $Root)
    }

    function Invoke-Mirror([string]$Source, [string]$Destination, [switch]$KeepServerOwned) {
        $roboArgs = @($Source, $Destination, '/MIR', '/R:3', '/W:2', '/NP', '/NFL', '/NDL', '/NJH', '/NJS')
        if ($KeepServerOwned) {
            $roboArgs += '/XF'; $roboArgs += $OwnedFiles
            $roboArgs += '/XD'; $roboArgs += $OwnedDirs
        } else {
            $roboArgs += '/XD'; $roboArgs += $OwnedDirs
        }
        $output = & robocopy.exe @roboArgs
        if ($LASTEXITCODE -ge 8) { throw ("robocopy {0} -> {1} failed with exit code {2}: {3}" -f $Source, $Destination, $LASTEXITCODE, (($output | Where-Object { $_ }) -join ' | ')) }
    }

    function Get-JsonKeyPaths($Node, [string]$Prefix) {
        $paths = @()
        if ($Node -is [Management.Automation.PSCustomObject]) {
            foreach ($p in $Node.PSObject.Properties) {
                $name = $p.Name
                if ($Prefix) { $name = "$Prefix`:$($p.Name)" }
                $children = @(Get-JsonKeyPaths $p.Value $name)
                if ($children.Count -eq 0) { $paths += $name } else { $paths += $children }
            }
        }
        $paths
    }

    function Get-MissingConfigKeys([string]$PackageFile, [string]$ServerFile) {
        if (-not (Test-Path -LiteralPath $PackageFile) -or -not (Test-Path -LiteralPath $ServerFile)) { return @() }
        try {
            $pkg = Get-JsonKeyPaths (Get-Content -LiteralPath $PackageFile -Raw | ConvertFrom-Json) ''
            $srv = Get-JsonKeyPaths (Get-Content -LiteralPath $ServerFile -Raw | ConvertFrom-Json) ''
            @($pkg | Where-Object { $srv -notcontains $_ })
        } catch { @("(could not compare: $($_.Exception.Message))") }
    }

    function Get-HttpStatus([string]$Uri) {
        try {
            $r = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0
            return [pscustomobject]@{ Status = [int]$r.StatusCode; Content = $r.Content }
        } catch [System.Net.WebException] {
            if ($_.Exception.Response) { return [pscustomobject]@{ Status = [int]$_.Exception.Response.StatusCode; Content = '' } }
            return [pscustomobject]@{ Status = 0; Content = $_.Exception.Message }
        } catch {
            return [pscustomobject]@{ Status = 0; Content = $_.Exception.Message }
        }
    }

    # ---- API (Windows service running Kestrel)
    # Callers must wrap in @(): function output unrolls, so no match returns $null and
    # $null.Count throws under StrictMode.
    function Get-ApiProcesses {
        $prefix = $Cfg.Api.Path.TrimEnd('\') + '\'
        @(Get-CimInstance Win32_Process -Filter "Name='Concursus.API.exe'" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
    }

    function Stop-Api {
        $svc = Get-Service -Name $Cfg.Api.ServiceName
        if ($svc.Status -ne 'Stopped') {
            Say "stopping service $($Cfg.Api.ServiceName)"
            Stop-Service -Name $Cfg.Api.ServiceName -Force
            $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(90))
        }
        $deadline = (Get-Date).AddSeconds(30)
        while (@(Get-ApiProcesses).Count -gt 0) {
            if ((Get-Date) -gt $deadline) { throw "Concursus.API.exe is still running from $($Cfg.Api.Path) after the service stopped." }
            Start-Sleep -Seconds 1
        }
    }

    function Start-Api {
        Say "starting service $($Cfg.Api.ServiceName)"
        Start-Service -Name $Cfg.Api.ServiceName
        (Get-Service -Name $Cfg.Api.ServiceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(90))
    }

    function Test-Api([datetime]$StartedAfter) {
        Say "waiting $($Options.StabiliseSeconds)s for the API to settle"
        Start-Sleep -Seconds $Options.StabiliseSeconds
        $svc = Get-Service -Name $Cfg.Api.ServiceName
        if ($svc.Status -ne 'Running') { throw "Service $($Cfg.Api.ServiceName) is $($svc.Status) after $($Options.StabiliseSeconds)s - check $($Cfg.Api.Path)\logs." }
        $procs = @(Get-ApiProcesses)
        if ($procs.Count -eq 0) { throw 'No Concursus.API.exe process is running after start.' }
        if ($procs[0].CreationDate -lt $StartedAfter.AddSeconds(-5)) { throw 'The running Concursus.API.exe predates this deployment.' }
        $deadline = (Get-Date).AddSeconds(60)
        do {
            $r = Get-HttpStatus $Cfg.Api.ProbeUri
            if ($r.Status -gt 0) { Say ("API answered HTTP {0} at {1}" -f $r.Status, $Cfg.Api.ProbeUri); return }
            Start-Sleep -Seconds 3
        } while ((Get-Date) -lt $deadline)
        throw "API did not answer at $($Cfg.Api.ProbeUri): $($r.Content)"
    }

    # ---- PWA (static IIS site)
    function Stop-Pwa {
        Import-Module WebAdministration
        $state = (Get-WebAppPoolState -Name $Cfg.Pwa.AppPool).Value
        if ($state -ne 'Stopped') {
            Say "stopping app pool $($Cfg.Pwa.AppPool)"
            Stop-WebAppPool -Name $Cfg.Pwa.AppPool
            $deadline = (Get-Date).AddSeconds(60)
            while ((Get-WebAppPoolState -Name $Cfg.Pwa.AppPool).Value -ne 'Stopped') {
                if ((Get-Date) -gt $deadline) { throw "App pool $($Cfg.Pwa.AppPool) did not stop." }
                Start-Sleep -Seconds 1
            }
        }
    }

    function Start-Pwa {
        Import-Module WebAdministration
        Say "starting app pool $($Cfg.Pwa.AppPool)"
        Start-WebAppPool -Name $Cfg.Pwa.AppPool
        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-WebAppPoolState -Name $Cfg.Pwa.AppPool).Value -ne 'Started') {
            if ((Get-Date) -gt $deadline) { throw "App pool $($Cfg.Pwa.AppPool) did not start." }
            Start-Sleep -Seconds 1
        }
    }

    function Test-Pwa {
        $base = $Cfg.Pwa.BaseUri
        $deadline = (Get-Date).AddSeconds(60)
        do {
            $page = Get-HttpStatus $base
            if ($page.Status -eq 200) { break }
            Start-Sleep -Seconds 3
        } while ((Get-Date) -lt $deadline)
        if ($page.Status -ne 200) { throw "PWA home page returned $($page.Status) at $base." }
        if ($page.Content -notmatch '_framework/') { throw 'PWA home page does not reference _framework/ - is the SPA being served?' }
        $settings = Get-HttpStatus ($base + 'appsettings.json')
        if ($settings.Status -ne 200) { throw "PWA appsettings.json returned $($settings.Status)." }
        try { $null = $settings.Content | ConvertFrom-Json } catch { throw 'PWA appsettings.json is not valid JSON.' }
        Say "PWA served home page and appsettings.json at $base"
    }

    # Last resort after a failed restore: never leave the environment stopped if it can be started.
    function Start-ComponentIfStopped([string]$Component) {
        try {
            if ($Component -eq 'Api') {
                if ((Get-Service -Name $Cfg.Api.ServiceName).Status -ne 'Running') { Start-Api }
                return "Api service is $((Get-Service -Name $Cfg.Api.ServiceName).Status)."
            }
            Import-Module WebAdministration
            if ((Get-WebAppPoolState -Name $Cfg.Pwa.AppPool).Value -ne 'Started') { Start-Pwa }
            return "Pwa app pool is $((Get-WebAppPoolState -Name $Cfg.Pwa.AppPool).Value)."
        } catch {
            return "$Component could not be started: $($_.Exception.Message)"
        }
    }

    function Get-LiveState {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        $issues = @()
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) { $issues += 'Remote session is not elevated/administrator.' }

        $state = [ordered]@{
            ComputerName = $env:COMPUTERNAME; User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            ApiService = '(not found)'; ApiVersion = '(unknown)'; PwaSite = '(not found)'
            FreeGB = 0; CurrentRelease = $null; Backups = @(); Issues = @()
        }
        if ($Components -contains 'Api') {
            $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $Cfg.Api.ServiceName)
            if (-not $svc) { $issues += "Service $($Cfg.Api.ServiceName) not found." }
            else {
                $state.ApiService = "$($svc.State) ($($svc.StartMode)) as $($svc.StartName)"
                if ($svc.PathName.Trim('"') -notlike ($Cfg.Api.Path.TrimEnd('\') + '\*')) { $issues += "Service $($Cfg.Api.ServiceName) runs '$($svc.PathName)', not from $($Cfg.Api.Path)." }
            }
            if (-not (Test-Path -LiteralPath (Join-Path $Cfg.Api.Path 'Concursus.API.dll'))) { $issues += "$($Cfg.Api.Path) does not contain Concursus.API.dll." }
            else { $state.ApiVersion = (Get-Item -LiteralPath (Join-Path $Cfg.Api.Path 'Concursus.API.dll')).VersionInfo.ProductVersion }
            if (-not (Test-Path -LiteralPath (Join-Path $Cfg.Api.Path 'appsettings.json'))) { $issues += "$($Cfg.Api.Path)\appsettings.json is missing (server-owned config)." }
        }
        if ($Components -contains 'Pwa') {
            $site = Get-Website -Name $Cfg.Pwa.SiteName -ErrorAction SilentlyContinue
            if (-not $site) { $issues += "IIS site $($Cfg.Pwa.SiteName) not found." }
            else {
                $state.PwaSite = "$($site.State), pool $($site.applicationPool)"
                $phys = [Environment]::ExpandEnvironmentVariables($site.physicalPath).TrimEnd('\')
                if ($phys -ne $Cfg.Pwa.Path.TrimEnd('\')) { $issues += "IIS site $($Cfg.Pwa.SiteName) points at '$phys', not $($Cfg.Pwa.Path)." }
                if ($site.applicationPool -ne $Cfg.Pwa.AppPool) { $issues += "IIS site uses pool '$($site.applicationPool)', expected $($Cfg.Pwa.AppPool)." }
            }
            if (-not (Test-Path -LiteralPath (Join-Path $Cfg.Pwa.Path 'wwwroot\appsettings.json'))) { $issues += "$($Cfg.Pwa.Path)\wwwroot\appsettings.json is missing (server-owned config)." }
        }

        $drive = (Split-Path $deployRoot -Qualifier).TrimEnd(':')
        $state.FreeGB = [math]::Round((Get-PSDrive -Name $drive).Free / 1GB, 1)
        if ($state.FreeGB -lt 10) { $issues += "Only $($state.FreeGB) GB free on $drive`:." }
        if (Test-Path -LiteralPath $lockPath) { $issues += ("Deployment lock held: {0} (delete {1} only if that deployment is definitely not running)" -f ((Get-Content -LiteralPath $lockPath -Raw) -replace '\s+', ' '), $lockPath) }
        if (Test-Path -LiteralPath $currentPath) { $state.CurrentRelease = (Get-Content -LiteralPath $currentPath -Raw | ConvertFrom-Json).Label }
        if (Test-Path -LiteralPath $backupsRoot) { $state.Backups = @(Get-ChildItem -LiteralPath $backupsRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty Name) }
        $state.Issues = $issues
        [pscustomobject]$state
    }

    function Remove-Old([string]$Root, [int]$Keep) {
        if (-not (Test-Path -LiteralPath $Root)) { return }
        Get-ChildItem -LiteralPath $Root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep | ForEach-Object {
            Assert-UnderDeployRoot $_.FullName
            Say "pruning $($_.FullName)"
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
    }

    switch ($Action) {
        'Preflight' { return Get-LiveState }

        'Stage' {
            foreach ($d in @($deployRoot, $releasesRoot, $backupsRoot, $incomingRoot)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }
            $zip = $Options.ZipPath
            Assert-UnderDeployRoot $zip
            $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
            if ($hash -ne $Options.ZipSha256) { throw "Transferred package hash $hash does not match local $($Options.ZipSha256)." }
            Say 'package hash matches'
            $releaseDir = Join-Path $releasesRoot $Options.Release
            Assert-UnderDeployRoot $releaseDir
            if (Test-Path -LiteralPath $releaseDir) { throw "Release folder $releaseDir already exists - use a new -ReleaseName." }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [IO.Compression.ZipFile]::ExtractToDirectory($zip, $releaseDir)
            Remove-Item -LiteralPath $zip -Force
            $warnings = @()
            $removals = @()
            foreach ($c in $Components) {
                $folder = $c.ToLowerInvariant()
                Assert-ManifestHashes (Join-Path $releaseDir $folder) (Read-Manifest (Join-Path $releaseDir "manifest-$folder.tsv"))
                if ($c -eq 'Api') { $settingsRel = 'appsettings.json'; $live = $Cfg.Api.Path } else { $settingsRel = 'wwwroot\appsettings.json'; $live = $Cfg.Pwa.Path }
                $missing = Get-MissingConfigKeys (Join-Path (Join-Path $releaseDir $folder) $settingsRel) (Join-Path $live $settingsRel)
                foreach ($m in $missing) { $warnings += "$c config key in build but not on server: $m" }
                $newFiles = Get-RelativeFiles (Join-Path $releaseDir $folder)
                $liveFiles = Get-RelativeFiles $live
                foreach ($k in $liveFiles.Keys) { if (-not $newFiles.ContainsKey($k)) { $removals += "$c`: $k" } }
            }
            return [pscustomobject]@{ ReleaseDir = $releaseDir; Warnings = $warnings; Removals = @($removals | Sort-Object) }
        }

        'Switch' {
            # Options: SourceRoot, Label, Release (manifest folder or $null), Commit, Branch, DeployedBy
            foreach ($d in @($deployRoot, $releasesRoot, $backupsRoot)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }
            try { New-Item -ItemType File -Path $lockPath -Value ("{0} by {1} at {2:o}" -f $Options.Label, $Options.DeployedBy, (Get-Date)) -ErrorAction Stop | Out-Null }
            catch { throw "Could not take deployment lock $lockPath - another deployment may be running." }

            $messages = New-Object System.Collections.Generic.List[string]
            $status = 'Succeeded'
            $switched = @()
            $keepLock = $false
            $sourceRoot = $Options.SourceRoot
            Assert-UnderDeployRoot $sourceRoot

            $backupDir = Join-Path $backupsRoot ("before-{0}" -f $Options.Label)
            Assert-UnderDeployRoot $backupDir
            try {
                foreach ($c in $Components) {
                    if ($c -eq 'Api') { $live = $Cfg.Api.Path } else { $live = $Cfg.Pwa.Path }
                    $dest = Join-Path $backupDir $c.ToLowerInvariant()
                    Say "backing up $live -> $dest"
                    Invoke-Mirror $live $dest
                }
            } catch {
                Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
                throw "Backup failed, nothing was changed: $($_.Exception.Message)"
            }

            try {
                foreach ($c in $Components) {
                    $src = Join-Path $sourceRoot $c.ToLowerInvariant()
                    if (-not (Test-Path -LiteralPath $src)) { throw "Source $src does not exist." }
                    $switchTime = Get-Date
                    if ($c -eq 'Api') {
                        $switched += $c
                        Stop-Api
                        Say "mirroring $src -> $($Cfg.Api.Path) (keeping server-owned files)"
                        Invoke-Mirror $src $Cfg.Api.Path -KeepServerOwned
                        Assert-TreesMatch $src $Cfg.Api.Path
                        if ($Options.VerifyHashes) { Assert-ManifestHashes $Cfg.Api.Path (Read-Manifest (Join-Path $sourceRoot 'manifest-api.tsv')) -SkipServerOwned }
                        Start-Api
                        Test-Api $switchTime
                    } else {
                        $switched += $c
                        Stop-Pwa
                        Say "mirroring $src -> $($Cfg.Pwa.Path) (keeping server-owned files)"
                        Invoke-Mirror $src $Cfg.Pwa.Path -KeepServerOwned
                        Assert-TreesMatch $src $Cfg.Pwa.Path
                        if ($Options.VerifyHashes) { Assert-ManifestHashes $Cfg.Pwa.Path (Read-Manifest (Join-Path $sourceRoot 'manifest-pwa.tsv')) -SkipServerOwned }
                        Start-Pwa
                        Test-Pwa
                    }
                    $messages.Add("$c switched and healthy.")
                }
            } catch {
                $failure = $_.Exception.Message
                $messages.Add("FAILED: $failure")
                Write-Host ("    [server] FAILED: {0}" -f $failure) -ForegroundColor Red
                $status = 'RolledBack'
                foreach ($c in $switched) {
                    try {
                        $bak = Join-Path $backupDir $c.ToLowerInvariant()
                        Say "restoring $c from $bak"
                        if ($c -eq 'Api') {
                            Stop-Api
                            Invoke-Mirror $bak $Cfg.Api.Path -KeepServerOwned
                            Start-Api
                            Test-Api (Get-Date)
                        } else {
                            Stop-Pwa
                            Invoke-Mirror $bak $Cfg.Pwa.Path -KeepServerOwned
                            Start-Pwa
                            Test-Pwa
                        }
                        $messages.Add("$c restored from backup and healthy.")
                    } catch {
                        $status = 'NeedsAttention'
                        $keepLock = $true
                        $messages.Add("$c RESTORE FAILED: $($_.Exception.Message). Backup is at $bak.")
                        $messages.Add((Start-ComponentIfStopped $c))
                    }
                }
            }

            $entry = [ordered]@{
                Label = $Options.Label; Release = $Options.Release; Status = $status; Components = $Components
                Commit = $Options.Commit; Branch = $Options.Branch; DeployedBy = $Options.DeployedBy
                At = (Get-Date).ToString('o'); Backup = $backupDir
            }
            Add-Content -LiteralPath $historyPath -Value ($entry | ConvertTo-Json -Compress)
            if ($status -eq 'Succeeded') {
                $entry | ConvertTo-Json | Set-Content -LiteralPath $currentPath -Encoding UTF8
                Remove-Old $releasesRoot $Options.KeepReleases
                Remove-Old $backupsRoot $Options.KeepReleases
            }
            if (-not $keepLock) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
            else { $messages.Add("Deployment lock left at $lockPath for manual reconciliation.") }
            return [pscustomobject]@{ Status = $status; Messages = $messages.ToArray(); Backup = $backupDir }
        }

        default { throw "Unknown action $Action" }
    }
}

# ------------------------------------------------------------------ 1. local checks
Write-Phase "CymBuild $Environment server deployment ($(if ($isRestore) { 'restore' } else { 'deploy' }): $($Component -join ', '))"

$branch = Get-GitValue @('rev-parse', '--abbrev-ref', 'HEAD')
$commit = Get-GitValue @('rev-parse', 'HEAD')
$deployedBy = "$env:USERDOMAIN\$env:USERNAME"
if (-not $isRestore) {
    $dirty = Get-GitValue @('status', '--porcelain')
    if ($dirty) {
        # -WhatIf builds and deploys nothing, so preview is allowed; a real deploy must map to a commit.
        if ($WhatIfPreference) { Write-Warn "Working tree has uncommitted changes - a real deploy will refuse until they are committed or stashed." }
        else { throw "Working tree has uncommitted changes. Commit or stash them first:`n$dirty" }
    }
    if ($branch -notlike 'release/*') { Write-Warn "Deploying from '$branch', not a release/* branch." }
    if (-not $ReleaseName) { $ReleaseName = '{0}-{1:yyyyMMdd-HHmmss}-{2}' -f $Environment, (Get-Date), $commit.Substring(0, 8) }
    Write-Note "Release : $ReleaseName"
    Write-Note "Source  : $branch @ $commit"
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw 'dotnet SDK not found on PATH.' }
}

# Database names come from the committed appsettings for this environment and the previous one.
$databases = $null
if ($runDatabase) {
    $databases = Resolve-CymBuildDeployDatabases -RepoRoot $repoRoot -Target $target
    Write-Note ("Target DB : {0} / {1}  ({2} ConnectionStrings:{3})" -f $databases.Target.Server, $databases.Target.Database, $databases.Target.File, $databases.Target.Key)
    Write-Note ("Source DB : {0} / {1}  ({2}, {3} ConnectionStrings:{4})" -f $databases.Source.Server, $databases.Source.Database, $databases.SourceEnvironment, $databases.Source.File, $databases.Source.Key)
}

# Already running as an admin account (e.g. ESGL\stephen.brett_adm, ESGL\Oliver.Eros_adm): use the
# current Kerberos identity. Otherwise prompt for <you>_adm.
$sessionParams = @{ ComputerName = $target.ComputerName; ErrorAction = 'Stop' }
if ($Credential) {
    $sessionParams.Credential = $Credential
} elseif ($env:USERNAME -notmatch '_adm$') {
    $sessionParams.Credential = Get-Credential -UserName ("{0}\{1}_adm" -f $env:USERDOMAIN, $env:USERNAME) -Message "Administrator account for $($target.ComputerName)"
}

# ------------------------------------------------------------------ 2. remote preflight
Write-Phase "Connecting to $($target.ComputerName) as $(if ($sessionParams.ContainsKey('Credential')) { $sessionParams['Credential'].UserName } else { "$env:USERDOMAIN\$env:USERNAME (current login)" })"
$session = New-PSSession @sessionParams
$transcribing = $false
$dbResults = $null
try {
    $remoteArgs = @{ Session = $session; ScriptBlock = $RemoteScript }
    $common = @($target, $Component, $ServerOwnedFilePatterns, $ServerOwnedDirectories)

    $preflight = Invoke-Command @remoteArgs -ArgumentList (@('Preflight') + $common + @(@{}))
    Write-Note "Server     : $($preflight.ComputerName) as $($preflight.User)"
    if ($Component -contains 'Api') { Write-Note "API        : $($preflight.ApiService), version $($preflight.ApiVersion)" }
    if ($Component -contains 'Pwa') { Write-Note "PWA        : $($preflight.PwaSite)" }
    Write-Note "Free space : $($preflight.FreeGB) GB"
    Write-Note "Last deploy: $(if ($preflight.CurrentRelease) { $preflight.CurrentRelease } else { '(none recorded by this script)' })"
    if (@($preflight.Issues).Count -gt 0) {
        $preflight.Issues | ForEach-Object { Write-Host "    BLOCKED: $_" -ForegroundColor Red }
        throw 'Remote preflight failed; nothing was changed.'
    }

    $restoreSource = $null
    if ($isRestore) {
        $available = @($preflight.Backups)
        if ($available.Count -eq 0) { throw "No backups under $($target.DeployRoot)\backups." }
        $restoreName = if ($RestoreBackup -eq 'latest') { $available[0] } else { $RestoreBackup }
        if ($available -notcontains $restoreName) { throw "Backup '$restoreName' not found. Available: $($available -join ', ')" }
        $restoreSource = "$($target.DeployRoot)\backups\$restoreName"
        Write-Note "Restore    : $restoreSource"
    }

    # ------------------------------------------------------------------ 3. plan
    if ($runDatabase) {
        Write-Note "Database   : back up $($databases.Target.Database), then schema and metadata from $($databases.Source.Database) ($($databases.SourceEnvironment)) (accepted runs first, else new runs selecting all differences)"
    } elseif (-not $isRestore) {
        Write-Note 'Database   : skipped (-SkipDatabase)'
    }

    $plan = if ($isRestore) { "restore $restoreSource to $($Component -join ' and ')" }
            else { "build $branch@$($commit.Substring(0, 8))$(if ($runDatabase) { ', migrate ' + $databases.Target.Database }) and deploy $($Component -join ' and ')" }
    if (-not $PSCmdlet.ShouldProcess("$Environment on $($target.ComputerName)", $plan)) {
        Write-Phase 'WhatIf: stopped before build, transfer, database backup or migration, or any server change.'
        return
    }

    $runDir = Join-Path $repoRoot ("artifacts\server-deploy\{0}" -f $(if ($isRestore) { "restore-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" } else { $ReleaseName }))
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Start-Transcript -LiteralPath (Join-Path $runDir 'deploy.log') | Out-Null
    $transcribing = $true

    $switchOptions = @{
        Commit = $commit; Branch = $branch; DeployedBy = $deployedBy
        KeepReleases = $KeepReleases; StabiliseSeconds = $StabiliseSeconds
    }

    if ($isRestore) {
        $switchOptions.SourceRoot = $restoreSource
        $switchOptions.Label = "restore-$((Get-Date).ToString('yyyyMMdd-HHmmss'))-from-$(Split-Path $restoreSource -Leaf)"
        $switchOptions.Release = $null
        $switchOptions.VerifyHashes = $false
    } else {
        # ------------------------------------------------------------------ 4. build
        $stage = Join-Path $runDir 'package'
        $fileCounts = [ordered]@{}
        foreach ($c in $Component) {
            Write-Phase "Publishing $c"
            $out = Join-Path $stage $c.ToLowerInvariant()
            Invoke-Native -FilePath 'dotnet' -ArgumentList @('publish', (Join-Path $repoRoot $target[$c].Project), '-c', 'Release', '-o', $out, '--nologo', '-v', 'q', '-tl:off', '-clp:ErrorsOnly') -Description "dotnet publish $c"
            $fileCounts[$c] = New-FileManifest $out (Join-Path $stage "manifest-$($c.ToLowerInvariant()).tsv")
            Write-Note "$($fileCounts[$c]) files"
        }
        $manifest = [ordered]@{
            Release = $ReleaseName; Environment = $Environment; Branch = $branch; Commit = $commit
            BuiltBy = $deployedBy; BuiltAt = (Get-Date).ToString('o'); Components = $Component; FileCounts = $fileCounts
        }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'release.json') -Encoding utf8

        $zip = Join-Path $runDir "$ReleaseName.zip"
        [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
        $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        Write-Note ("Package {0:N0} MB, SHA-256 {1}" -f ((Get-Item $zip).Length / 1MB), $zipHash)

        # ------------------------------------------------------------------ 5. transfer + stage
        Write-Phase 'Transferring package'
        $remoteZip = "$($target.DeployRoot)\incoming\$ReleaseName.zip"
        Invoke-Command -Session $session -ScriptBlock { param($dir) if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null } } -ArgumentList (Split-Path $remoteZip -Parent)
        Copy-Item -LiteralPath $zip -Destination $remoteZip -ToSession $session -Force
        $staged = Invoke-Command @remoteArgs -ArgumentList (@('Stage') + $common + @(@{ ZipPath = $remoteZip; ZipSha256 = $zipHash; Release = $ReleaseName }))
        # Blazor fingerprints _framework files, so every build replaces them; only ask about anything else.
        $allRemovals = @($staged.Removals)
        $frameworkRemovals = @($allRemovals | Where-Object { $_ -match '\\_framework\\' })
        $removals = @($allRemovals | Where-Object { $_ -notmatch '\\_framework\\' })
        if ($frameworkRemovals.Count -gt 0) { Write-Note "$($frameworkRemovals.Count) superseded _framework file(s) will be replaced (kept in the backup)." }
        if ($removals.Count -gt 0) {
            Write-Warn "$($removals.Count) other file(s) on the server are not in this build and will be removed (they are kept in the backup):"
            $removals | Select-Object -First 25 | ForEach-Object { Write-Note "  - $_" }
            if ($removals.Count -gt 25) { Write-Note "  ... and $($removals.Count - 25) more" }
            if (-not $PSCmdlet.ShouldContinue("Remove $($removals.Count) server file(s) that are not in the build?", 'Confirm file removal')) {
                throw "Stopped before switching. The staged release remains on the server; nothing live was changed."
            }
        }
        $warnings = @($staged.Warnings)
        foreach ($w in $warnings) { Write-Warn $w }
        if ($warnings.Count -gt 0) { Write-Warn 'Add the keys above to the server appsettings.json if the new build needs them (deploy continues).' }

        # ------------------------------------------------------------------ 6. database phase
        # Failures are reported in the summary; they never stop the application deployment.
        if ($runDatabase) {
            try {
                $dbResults = Invoke-CymBuildDatabasePhase -RepoRoot $repoRoot -RunDir $runDir -Databases $databases `
                    -TargetEnvironment $Environment -Label $ReleaseName
            } catch {
                $dbResults = @(New-DbStepResult -Step 'Database' -Status Failed -Message "Database phase stopped unexpectedly: $($_.Exception.Message)")
            }
        }

        $switchOptions.SourceRoot = $staged.ReleaseDir
        $switchOptions.Label = $ReleaseName
        $switchOptions.Release = $ReleaseName
        $switchOptions.VerifyHashes = $true
    }

    # ------------------------------------------------------------------ 7. switch
    Write-Phase "Switching $($Component -join ', ')"
    $result = Invoke-Command @remoteArgs -ArgumentList (@('Switch') + $common + @($switchOptions))
    $result.Messages | ForEach-Object { Write-Note $_ }
    Write-Note "Backup of previous files: $($result.Backup)"
    if ($dbResults) { Write-DbPhaseSummary -Results $dbResults }

    switch ($result.Status) {
        'Succeeded' {
            $dbFailed = $dbResults -and @($dbResults | Where-Object Status -ne 'Succeeded').Count -gt 0
            Write-Phase "Done: $($switchOptions.Label) is live on $Environment$(if ($dbFailed) { ' - database steps need manual attention (see summary above)' })."
        }
        'RolledBack' { throw "Deployment failed and the previous files were restored. See $runDir\deploy.log." }
        default { throw "Deployment failed AND restore failed - $Environment needs manual attention. See $runDir\deploy.log." }
    }
} finally {
    Remove-PSSession -Session $session -ErrorAction SilentlyContinue -WhatIf:$false
    if ($transcribing) { Stop-Transcript | Out-Null }
}
