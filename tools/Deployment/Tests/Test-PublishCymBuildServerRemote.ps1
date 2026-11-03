# Runs under Windows PowerShell 5.1 (the server's version). Invoked by Invoke-PublishCymBuildServerTests.ps1.
# Exercises Publish-CymBuildServer.ps1's server-side functions against temp folders; touches no service or IIS.
param([string]$ScriptPath, [string]$Work)
$ErrorActionPreference = 'Stop'
$fails = 0
function Check([bool]$Cond, [string]$Name) { if ($Cond) { Write-Host "PASS $Name" } else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:fails++ } }

$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
$assign = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$RemoteScript' }, $true)
$blockText = $assign.Right.Extent.Text
# Parse the remote block itself with the 5.1 parser
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($blockText, [ref]$null, [ref]$errs)
Check ($errs.Count -eq 0) "remote block parses under PS $($PSVersionTable.PSVersion)"
$remote = [scriptblock]::Create($blockText.Trim().TrimStart('{').TrimEnd('}'))

$deployRoot = Join-Path $Work 'deployroot'
$live = Join-Path $Work 'live-api'
$cfg = @{ DeployRoot = $deployRoot; Api = @{ Path = $live; ServiceName = 'x'; ProbeUri = 'https://localhost:1/' }; Pwa = @{ Path = (Join-Path $Work 'live-pwa'); SiteName = 'x'; AppPool = 'x'; BaseUri = 'https://localhost:1/' } }
$owned = @('appsettings*.json', 'web.config', 'nlog.config'); $dirs = @('logs')

# Stage
$zip = Join-Path $deployRoot 'incoming\R1.zip'
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
$staged = & $remote 'Stage' $cfg @('Api') $owned $dirs @{ ZipPath = $zip; ZipSha256 = $hash; Release = 'R1' }
Check (Test-Path (Join-Path $deployRoot 'releases\R1\api\Concursus.API.dll')) 'Stage extracts package'
Check (-not (Test-Path $zip)) 'Stage removes zip'
Check (@($staged.Warnings) -contains 'Api config key in build but not on server: Features:NewFlag') 'Stage reports missing config key by name'
Check (-not (@($staged.Warnings) -match 'secret-value')) 'Stage never outputs config values'
Check (@($staged.Removals) -contains 'Api: old-only.dll') 'Stage lists files that will be removed'
Check (-not (@($staged.Removals) -match 'logs|appsettings|web.config')) 'Stage removal list excludes server-owned files'

# Bad hash is rejected
Copy-Item (Join-Path $Work 'R2.zip') (Join-Path $deployRoot 'incoming\R2.zip')
$threw = $false
try { & $remote 'Stage' $cfg @('Api') $owned $dirs @{ ZipPath = (Join-Path $deployRoot 'incoming\R2.zip'); ZipSha256 = ('0' * 64); Release = 'R2' } } catch { $threw = $_.Exception.Message -like '*does not match*' }
Check $threw 'Stage rejects hash mismatch'

# Paths outside the deploy root are refused
$threw = $false
try { & $remote 'Stage' $cfg @('Api') $owned $dirs @{ ZipPath = 'C:\Windows\win.ini'; ZipSha256 = 'x'; Release = 'R3' } } catch { $threw = $_.Exception.Message -like '*outside*' }
Check $threw 'Refuses paths outside DeployRoot'

# Mirror / verify functions, defined by dot-sourcing only the function definitions
$fnAst = [System.Management.Automation.Language.Parser]::ParseInput($blockText, [ref]$null, [ref]$null)
$fns = $fnAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$OwnedFiles = $owned; $OwnedDirs = $dirs; $Cfg = $cfg
$deployRoot = $cfg.DeployRoot
foreach ($f in $fns) { . ([scriptblock]::Create($f.Extent.Text)) }

$src = Join-Path $deployRoot 'releases\R1\api'
$liveSettingsBefore = Get-Content (Join-Path $live 'appsettings.json') -Raw
Invoke-Mirror $src $live -KeepServerOwned
Check ((Get-Content (Join-Path $live 'appsettings.json') -Raw) -eq $liveSettingsBefore) 'Mirror keeps server appsettings.json'
Check (Test-Path (Join-Path $live 'logs\app.log')) 'Mirror keeps logs folder'
Check (Test-Path (Join-Path $live 'web.config')) 'Mirror keeps web.config'
Check ((Get-Content (Join-Path $live 'nlog.config') -Raw).Trim() -eq '<server-nlog/>') 'Mirror keeps server nlog.config'
Check (-not (Test-Path (Join-Path $live 'appsettings.QA.json'))) 'Mirror does not copy build appsettings variants'
Check (-not (Test-Path (Join-Path $live 'old-only.dll'))) 'Mirror removes files not in build'
Check (Test-Path (Join-Path $live 'sub\nested.dll')) 'Mirror copies nested files'
$ok = $true; try { Assert-TreesMatch $src $live } catch { $ok = $false; Write-Host $_ }
Check $ok 'Assert-TreesMatch passes after mirror'
$ok = $true; try { Assert-ManifestHashes $live (Read-Manifest (Join-Path $deployRoot 'releases\R1\manifest-api.tsv')) -SkipServerOwned } catch { $ok = $false; Write-Host $_ }
Check $ok 'Assert-ManifestHashes passes on live folder'

Set-Content (Join-Path $live 'Concursus.API.dll') 'tampered'
$threw = $false; try { Assert-ManifestHashes $live (Read-Manifest (Join-Path $deployRoot 'releases\R1\manifest-api.tsv')) -SkipServerOwned } catch { $threw = $true }
Check $threw 'Assert-ManifestHashes detects changed file'
Set-Content (Join-Path $live 'extra.txt') 'x'
$threw = $false; try { Assert-TreesMatch $src $live } catch { $threw = $true }
Check $threw 'Assert-TreesMatch detects unexpected file'

# Backup mirror (no exclusions except logs) copies appsettings
$bak = Join-Path $deployRoot 'backups\before-R1\api'
Invoke-Mirror $live $bak
Check (Test-Path (Join-Path $bak 'appsettings.json')) 'Backup includes server appsettings.json'
Check (-not (Test-Path (Join-Path $bak 'logs'))) 'Backup skips logs'

# Regression (QA 2026-10-13): with no API process running, the stop-wait loop threw
# "property 'Count' cannot be found" under StrictMode and left the service stopped.
Set-StrictMode -Version 2.0
$ok = $true; $n = -1; try { $n = @(Get-ApiProcesses).Count } catch { $ok = $false; Write-Host $_ }
Check ($ok -and $n -eq 0) 'Get-ApiProcesses with no match counts 0 under StrictMode 2.0'
Set-StrictMode -Off

Check (Test-ServerOwned 'wwwroot\appsettings.json') 'wwwroot\appsettings.json is server-owned'
Check (Test-ServerOwned 'logs\a.log') 'logs\ is server-owned'
Check (-not (Test-ServerOwned 'logs.dll')) 'logs.dll is not server-owned'
Check (-not (Test-ServerOwned 'wwwroot\_framework\dotnet.js')) 'framework file is not server-owned'

# Prune keeps newest N
1..5 | ForEach-Object { $d = New-Item -ItemType Directory (Join-Path $deployRoot "backups\b$_"); $d.LastWriteTime = (Get-Date).AddMinutes(-10 * $_) }
(Get-Item $bak).Parent.LastWriteTime = Get-Date
Remove-Old (Join-Path $deployRoot 'backups') 3
$left = @(Get-ChildItem (Join-Path $deployRoot 'backups') -Directory | Select-Object -ExpandProperty Name)
Check ($left.Count -eq 3 -and $left -contains 'before-R1' -and $left -contains 'b1' -and $left -contains 'b2') "Prune keeps newest 3 (left: $($left -join ','))"

Write-Host ''
if ($fails) { Write-Host "$fails FAILED" -ForegroundColor Red; exit 1 } else { Write-Host 'ALL PASSED' -ForegroundColor Green }
