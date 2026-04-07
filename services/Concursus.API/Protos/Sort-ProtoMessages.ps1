<#
.SYNOPSIS
  Sort core.proto top-level definitions A-Z (messages/services/enums) and sort RPCs inside services.
  IMPORTANT: does NOT touch nested messages (e.g. message DriveItem { message Identity { ... } }).

.EXAMPLE
  pwsh .\Sort-ProtoMessages.ps1 -InputPath .\core.proto -OutputPath .\core.sorted.proto

.EXAMPLE
  pwsh .\Sort-ProtoMessages.ps1 -InputPath .\core.proto -OutputPath .\core.sorted.proto -SortServices
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $InputPath,
  [Parameter(Mandatory = $true)] [string] $OutputPath,
  [switch] $SortServices
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BlockEndIndex {
  param(
    [Parameter(Mandatory=$true)][string] $Text,
    [Parameter(Mandatory=$true)][int] $OpenBraceIndex
  )

  # We start ON the '{'
  $i = $OpenBraceIndex
  $depth = 0

  $inLineComment = $false
  $inBlockComment = $false
  $inString = $false
  $stringQuote = [char]0

  while ($i -lt $Text.Length) {
    $ch = $Text[$i]
    $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

    # End line comment
    if ($inLineComment) {
      if ($ch -eq "`n") { $inLineComment = $false }
      $i++
      continue
    }

    # End block comment
    if ($inBlockComment) {
      if ($ch -eq "*" -and $next -eq "/") { $inBlockComment = $false; $i += 2; continue }
      $i++
      continue
    }

    # End string
    if ($inString) {
      if ($ch -eq "\" ) { $i += 2; continue } # skip escaped char
      if ($ch -eq $stringQuote) { $inString = $false; $stringQuote = [char]0; $i++; continue }
      $i++
      continue
    }

    # Start comments
    if ($ch -eq "/" -and $next -eq "/") { $inLineComment = $true; $i += 2; continue }
    if ($ch -eq "/" -and $next -eq "*") { $inBlockComment = $true; $i += 2; continue }

    # Start string
    if ($ch -eq '"' -or $ch -eq "'") {
      $inString = $true
      $stringQuote = $ch
      $i++
      continue
    }

    # Brace tracking (only when not in comment/string)
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) {
        return $i
      }
      if ($depth -lt 0) {
        throw "Brace depth went negative while scanning block (unexpected)."
      }
    }

    $i++
  }

  throw "Unbalanced braces: reached EOF before closing brace."
}

function Sort-ServiceRpcs {
  param([string] $ServiceBlock)

  # Find the braces of the service so we can only sort inside.
  $open = $ServiceBlock.IndexOf("{")
  if ($open -lt 0) { return $ServiceBlock }

  $close = Get-BlockEndIndex -Text $ServiceBlock -OpenBraceIndex $open

  $prefix = $ServiceBlock.Substring(0, $open + 1)
  $body = $ServiceBlock.Substring($open + 1, $close - ($open + 1))
  $suffix = $ServiceBlock.Substring($close)

  # Split body into lines, sort only rpc lines, keep other lines in place
  $lines = $body -split "(`r`n|`n|`r)"
  $rpcLines = New-Object System.Collections.Generic.List[string]
  $nonRpc = New-Object System.Collections.Generic.List[object]

  for ($idx = 0; $idx -lt $lines.Length; $idx++) {
    $line = $lines[$idx]
    if ($line -match '^\s*rpc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
      $rpcLines.Add($line)
      $nonRpc.Add($null) # placeholder
    } else {
      $nonRpc.Add($line)
    }
  }

  $sortedRpc = $rpcLines | Sort-Object { ($_ -replace '^\s*rpc\s+','') }

  # Rebuild body, replacing rpc placeholders in order
  $rpcIdx = 0
  $rebuilt = for ($i = 0; $i -lt $nonRpc.Count; $i++) {
    if ($null -eq $nonRpc[$i]) {
      $sortedRpc[$rpcIdx]
      $rpcIdx++
    } else {
      $nonRpc[$i]
    }
  }

  $newBody = ($rebuilt -join "`n")
  return $prefix + "`n" + $newBody.TrimEnd() + "`n" + $suffix
}

# ----------------------------
# Read proto
# ----------------------------
$text = Get-Content -Path $InputPath -Raw

# Match ONLY top-level definitions (must start at column 1)
# This avoids nested: "  message Identity { ... }"
$defRegex = [regex]'(?m)^(service|message|enum)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{'

$matches = $defRegex.Matches($text)

if ($matches.Count -eq 0) {
  throw "No top-level service/message/enum blocks found. Check formatting (must start at column 1)."
}

# Everything before the first top-level definition stays as-is (syntax/imports/options/package/comments)
$preamble = $text.Substring(0, $matches[0].Index)

$blocks = @()

for ($m = 0; $m -lt $matches.Count; $m++) {
  $kind = $matches[$m].Groups[1].Value
  $name = $matches[$m].Groups[2].Value
  $start = $matches[$m].Index

  $openBrace = $text.IndexOf("{", $start)
  if ($openBrace -lt 0) { throw "No '{' found for $kind $name" }

  $endBrace = Get-BlockEndIndex -Text $text -OpenBraceIndex $openBrace
  $end = $endBrace + 1

  $blockText = $text.Substring($start, $end - $start).Trim()

  if ($kind -eq "service") {
    $blockText = Sort-ServiceRpcs -ServiceBlock $blockText
  }

  $blocks += [pscustomobject]@{
    Kind = $kind
    Name = $name
    Text = $blockText
  }
}

# Sort messages A-Z always
$messages = $blocks | Where-Object Kind -eq "message" | Sort-Object Name
$enums    = $blocks | Where-Object Kind -eq "enum"    | Sort-Object Name
$services = $blocks | Where-Object Kind -eq "service" | Sort-Object Name

if (-not $SortServices) {
  # Keep service order as in file (but RPCs inside are sorted)
  $services = $blocks | Where-Object Kind -eq "service"
}

# Rebuild file
$out = New-Object System.Text.StringBuilder
[void]$out.Append($preamble.TrimEnd())
[void]$out.Append("`n`n")

foreach ($s in $services) {
  [void]$out.Append($s.Text.TrimEnd())
  [void]$out.Append("`n`n")
}
foreach ($e in $enums) {
  [void]$out.Append($e.Text.TrimEnd())
  [void]$out.Append("`n`n")
}
foreach ($msg in $messages) {
  [void]$out.Append($msg.Text.TrimEnd())
  [void]$out.Append("`n`n")
}

# Write output
$outText = $out.ToString().TrimEnd() + "`n"
Set-Content -Path $OutputPath -Value $outText -Encoding UTF8

Write-Host "Sorted proto written to: $OutputPath"
Write-Host "Notes: nested messages are not moved. Service RPCs were sorted A-Z."
