# Applies the CYB-279 Dev264 script (#847). Windows authentication only.
$ErrorActionPreference = 'Stop'
foreach ($v in 'SQLCMDUSER', 'SQLCMDPASSWORD', 'SQLCMDDBNAME', 'SQLCMDSERVER') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe'
Write-Host '=== CYB279_Dev264_DrawdownCadence.sql'
& $sqlcmd -S '10.100.34.114\general' -d 'CymBuild_Dev264' -E -C -b -i (Join-Path $PSScriptRoot 'CYB279_Dev264_DrawdownCadence.sql')
if ($LASTEXITCODE -ne 0) { throw "CYB-279 script failed with exit code $LASTEXITCODE." }
Write-Host '=== done'
