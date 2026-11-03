param(
    [switch]$WhatIf
)

$root = Get-Location

Write-Host "Searching under:"
Write-Host $root
Write-Host ""

# Stop any local API/PWA processes this repo's own tooling started, so their build
# output isn't open/in-use while we delete it. Safe/idempotent - only touches PIDs
# that script itself recorded, and does nothing if nothing is running.
$stopScript = Join-Path $root "tools\UI\Stop-CymBuildLocal.ps1"
if (Test-Path $stopScript) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would run: $stopScript"
    }
    else {
        Write-Host "Stopping any locally-running Concursus.API/Concursus.PWA (tools\UI\Stop-CymBuildLocal.ps1)..."
        try {
            & $stopScript
        }
        catch {
            Write-Host "Stop-CymBuildLocal.ps1 failed, continuing anyway: $($_.Exception.Message)"
        }
    }
}

# Shut down the MSBuild/VBCSCompiler(Roslyn)/Razor build-server background processes.
# These are long-lived nodes that dotnet build/run spin up for speed and keep running
# (and keep file handles open in obj\) independently of whether the app itself is
# running - a leftover node here is what causes the intermittent
# "process cannot access ... *.dswa.cache.json" lock errors during a rebuild, not
# necessarily a still-running app. Doing this before deleting obj\ avoids that.
if ($WhatIf) {
    Write-Host "[WhatIf] Would run: dotnet build-server shutdown"
}
else {
    Write-Host "Shutting down dotnet build servers (MSBuild/VBCSCompiler/Razor)..."
    dotnet build-server shutdown | Out-Host
}

Write-Host ""

# Find bin and obj folders
$folders = Get-ChildItem -Path $root -Directory -Recurse -Force |
    Where-Object {
        $_.Name -in @("bin", "obj") -and
        $_.FullName -notmatch "\\\.git\\"
    } |
    Sort-Object FullName -Descending

# Find zip files
$zipFiles = Get-ChildItem -Path $root -File -Recurse -Force -Filter "*.zip" |
    Where-Object {
        $_.FullName -notmatch "\\\.git\\"
    } |
    Sort-Object FullName -Descending

# Visual Studio's per-solution cache (IntelliSense DB plus a design-time build cache).
# It's local-only, VS regenerates it automatically, and a stale copy can itself hold
# handles that interfere with a clean obj\ removal.
$vsFolder = Join-Path $root ".vs"
$vsFolderExists = Test-Path $vsFolder

if (-not $folders -and -not $zipFiles -and -not $vsFolderExists) {
    Write-Host "No bin folders, obj folders, zip files, or .vs cache found."
    exit 0
}

foreach ($folder in $folders) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove folder: $($folder.FullName)"
    }
    else {
        Write-Host "Removing folder: $($folder.FullName)"
        Remove-Item -LiteralPath $folder.FullName -Recurse -Force
    }
}

foreach ($zip in $zipFiles) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove zip file: $($zip.FullName)"
    }
    else {
        Write-Host "Removing zip file: $($zip.FullName)"
        Remove-Item -LiteralPath $zip.FullName -Force
    }
}

if ($vsFolderExists) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove folder: $vsFolder"
    }
    else {
        Write-Host "Removing folder: $vsFolder"
        try {
            Remove-Item -LiteralPath $vsFolder -Recurse -Force -ErrorAction Stop
        }
        catch {
            # VS keeps its FileContentIndex *.vsidx files open while a devenv.exe instance
            # has this solution loaded. Non-fatal - close Visual Studio first for a full
            # .vs removal, but it doesn't affect the bin\obj rebuild this script is for.
            Write-Host "Could not fully remove $vsFolder (likely still open in Visual Studio): $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Note: this only cleans .NET build output and IDE cache on disk. It does not"
Write-Host "touch the PWA's browser-side service worker, Cache Storage, or IndexedDB -"
Write-Host "use the 'Repair / refresh the app' button (or DevTools > Application >"
Write-Host "Service Workers) once the rebuilt app is running again."