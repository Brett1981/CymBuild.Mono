# Applies the Dev264 scripts for CYB-237 (#843), CYB-389 (#846) and CYB-572 (#839, optional alignment).
# Stops at the first failure. Uses Windows authentication only.
$ErrorActionPreference = 'Stop'
foreach ($v in 'SQLCMDUSER', 'SQLCMDPASSWORD', 'SQLCMDDBNAME', 'SQLCMDSERVER') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }

$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe'
$dir = $PSScriptRoot
$scripts = @(
    'CYB237_Dev264_FeeAmendment_AgreedStatusBy.sql',
    'CYB389_Dev264_WIP_Reason.sql',
    'CYB572_Dev264_tvf_UnBilledActivities.sql'
)

foreach ($f in $scripts) {
    Write-Host "=== $f"
    & $sqlcmd -S '10.100.34.114\general' -d 'CymBuild_Dev264' -E -C -b -i (Join-Path $dir $f)
    if ($LASTEXITCODE -ne 0) { throw "$f failed with exit code $LASTEXITCODE - stopping." }
}
Write-Host '=== all done'
