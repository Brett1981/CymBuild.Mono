# Applies the CYB-237 rejection-reason Dev264 script. Windows authentication only.
$ErrorActionPreference = 'Stop'
foreach ($v in 'SQLCMDUSER', 'SQLCMDPASSWORD', 'SQLCMDDBNAME', 'SQLCMDSERVER') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe'
Write-Host '=== CYB237_Dev264_RejectionReason.sql'
& $sqlcmd -S '10.100.34.114\general' -d 'CymBuild_Dev264' -E -C -b -i (Join-Path $PSScriptRoot 'CYB237_Dev264_RejectionReason.sql')
if ($LASTEXITCODE -ne 0) { throw "CYB-237 script failed with exit code $LASTEXITCODE." }
Write-Host '=== done'
