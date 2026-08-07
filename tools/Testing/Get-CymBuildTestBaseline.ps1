[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directorySeparators = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd($directorySeparators) + [System.IO.Path]::DirectorySeparatorChar
    $pathFullPath = [System.IO.Path]::GetFullPath($Path)
    $baseUri = New-Object System.Uri -ArgumentList $baseFullPath
    $pathUri = New-Object System.Uri -ArgumentList $pathFullPath
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Test-IsExcludedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    return $RelativePath -match '^(?:_patch_backups|TestResults|artifacts|CYB[^\\]*|SQL_CI_Packs(?:_Metadata)?)\\' -or
           $RelativePath -match '(?:^|\\)(?:bin|obj)\\'
}

function Get-FirstPropertyValue {
    param(
        [Parameter(Mandatory = $true)][object[]]$PropertyGroups,
        [Parameter(Mandatory = $true)][string]$Name
    )

    foreach ($propertyGroup in $PropertyGroups) {
        $property = $propertyGroup.PSObject.Properties[$Name]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    return ''
}

function Convert-ToMarkdownCell {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoRoot 'TestResults\baseline'
}
else {
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$solutionPath = Join-Path $RepoRoot 'CymBuild.Monorepo.sln'
$solutionProjectPaths = New-Object 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $solutionPath -PathType Leaf) {
    $solutionText = Get-Content -LiteralPath $solutionPath -Raw
    $matches = [System.Text.RegularExpressions.Regex]::Matches(
        $solutionText,
        '(?m)^Project\("[^"]+"\)\s*=\s*"[^"]+",\s*"(?<path>[^"]+\.csproj)"'
    )
    foreach ($match in $matches) {
        [void]$solutionProjectPaths.Add($match.Groups['path'].Value.Replace('/', '\'))
    }
}

$projectFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter '*.csproj' -File | ForEach-Object {
    $relativePath = Get-RelativePath -BasePath $RepoRoot -Path $_.FullName
    if (-not (Test-IsExcludedRepositoryPath -RelativePath $relativePath)) {
        [pscustomobject]@{
            File = $_
            RelativePath = $relativePath
        }
    }
} | Where-Object { $null -ne $_ } | Sort-Object RelativePath

$projects = New-Object System.Collections.Generic.List[object]
$totalFacts = 0
$totalTheories = 0
$totalInlineData = 0
$totalSourceFiles = 0
$totalSourceLines = 0

foreach ($projectEntry in $projectFiles) {
    [xml]$projectXml = Get-Content -LiteralPath $projectEntry.File.FullName -Raw
    $propertyGroups = @($projectXml.SelectNodes("/*[local-name()='Project']/*[local-name()='PropertyGroup']"))
    $isTestProjectValue = Get-FirstPropertyValue -PropertyGroups $propertyGroups -Name 'IsTestProject'
    $isTestProject = $projectEntry.File.BaseName -match '(?i)Tests$' -or $isTestProjectValue -eq 'true'
    $targetFramework = Get-FirstPropertyValue -PropertyGroups $propertyGroups -Name 'TargetFramework'
    if ([string]::IsNullOrWhiteSpace($targetFramework)) {
        $targetFramework = Get-FirstPropertyValue -PropertyGroups $propertyGroups -Name 'TargetFrameworks'
    }

    $projectDirectory = $projectEntry.File.Directory.FullName
    $sourceSearchParameters = @{
        LiteralPath = $projectDirectory
        File = $true
    }
    $directorySeparators = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    if (-not [string]::Equals($projectDirectory.TrimEnd($directorySeparators), $RepoRoot.TrimEnd($directorySeparators), [System.StringComparison]::OrdinalIgnoreCase)) {
        $sourceSearchParameters['Recurse'] = $true
    }

    $sourceFiles = @(Get-ChildItem @sourceSearchParameters | Where-Object {
        $_.Extension -in @('.cs', '.razor') -and
        $_.FullName -notmatch '[\\/](?:bin|obj)[\\/]' -and
        $_.Name -notmatch '(?i)(?:\.g|\.designer)\.cs$'
    })

    $sourceLineCount = 0
    $factCount = 0
    $theoryCount = 0
    $inlineDataCount = 0
    foreach ($sourceFile in $sourceFiles) {
        $content = Get-Content -LiteralPath $sourceFile.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }
        $sourceLineCount += ([System.Text.RegularExpressions.Regex]::Matches($content, "`n").Count + 1)
        if ($isTestProject) {
            $factCount += [System.Text.RegularExpressions.Regex]::Matches($content, '(?m)^\s*\[Fact(?:Attribute)?(?:\([^\]]*\))?\]').Count
            $theoryCount += [System.Text.RegularExpressions.Regex]::Matches($content, '(?m)^\s*\[Theory(?:Attribute)?(?:\([^\]]*\))?\]').Count
            $inlineDataCount += [System.Text.RegularExpressions.Regex]::Matches($content, '(?m)^\s*\[InlineData(?:Attribute)?\(').Count
        }
    }

    $projectReferences = New-Object System.Collections.Generic.List[string]
    $projectReferenceNodes = @($projectXml.SelectNodes(
        "/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='ProjectReference']"
    ))
    foreach ($projectReference in $projectReferenceNodes) {
        $include = $projectReference.GetAttribute('Include')
        if (-not [string]::IsNullOrWhiteSpace($include)) {
            $projectReferences.Add($include)
        }
    }

    $inSolution = $solutionProjectPaths.Contains($projectEntry.RelativePath)
    $projects.Add([pscustomobject]@{
        Name = $projectEntry.File.BaseName
        Path = $projectEntry.RelativePath
        TargetFramework = $targetFramework
        IsTestProject = $isTestProject
        InRootSolution = $inSolution
        SourceFiles = $sourceFiles.Count
        SourceLines = $sourceLineCount
        FactAttributes = $factCount
        TheoryAttributes = $theoryCount
        InlineDataAttributes = $inlineDataCount
        ProjectReferences = $projectReferences.ToArray()
    })

    $totalFacts += $factCount
    $totalTheories += $theoryCount
    $totalInlineData += $inlineDataCount
    $totalSourceFiles += $sourceFiles.Count
    $totalSourceLines += $sourceLineCount
}

$duplicateGroups = @($projects | Group-Object Name | Where-Object { $_.Count -gt 1 } | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        Paths = @($_.Group | ForEach-Object { $_.Path })
    }
})
$testProjects = @($projects | Where-Object { $_.IsTestProject })
$productionCandidates = @($projects | Where-Object { -not $_.IsTestProject })
$omittedProductionCandidates = @($productionCandidates | Where-Object { -not $_.InRootSolution })

$rootSolutionName = $null
if (Test-Path -LiteralPath $solutionPath -PathType Leaf) {
    $rootSolutionName = 'CymBuild.Monorepo.sln'
}

$report = [pscustomobject]@{
    SchemaVersion = 1
    GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
    RepositoryRoot = $RepoRoot
    RootSolution = $rootSolutionName
    Summary = [pscustomobject]@{
        ProjectFiles = $projects.Count
        TestProjects = $testProjects.Count
        ProductionProjectCandidates = $productionCandidates.Count
        ProductionProjectCandidatesOmittedFromRootSolution = $omittedProductionCandidates.Count
        DuplicateProjectNameGroups = $duplicateGroups.Count
        SourceFiles = $totalSourceFiles
        SourceLines = $totalSourceLines
        FactAttributes = $totalFacts
        TheoryAttributes = $totalTheories
        InlineDataAttributes = $totalInlineData
    }
    DuplicateProjectNames = $duplicateGroups
    ProductionProjectCandidatesOmittedFromRootSolution = $omittedProductionCandidates
    Projects = $projects.ToArray()
}

$jsonPath = Join-Path $OutputDirectory 'cymbuild-test-baseline.json'
$markdownPath = Join-Path $OutputDirectory 'cymbuild-test-baseline.md'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add('# CymBuild test baseline')
$markdown.Add('')
$markdown.Add("Generated UTC: $($report.GeneratedUtc)")
$markdown.Add('')
$markdown.Add('## Summary')
$markdown.Add('')
$markdown.Add('| Measure | Count |')
$markdown.Add('|---|---:|')
$markdown.Add("| Project files | $($report.Summary.ProjectFiles) |")
$markdown.Add("| Test projects | $($report.Summary.TestProjects) |")
$markdown.Add("| Production project candidates | $($report.Summary.ProductionProjectCandidates) |")
$markdown.Add("| Production project candidates omitted from root solution | $($report.Summary.ProductionProjectCandidatesOmittedFromRootSolution) |")
$markdown.Add("| Duplicate project-name groups | $($report.Summary.DuplicateProjectNameGroups) |")
$markdown.Add("| Source files | $($report.Summary.SourceFiles) |")
$markdown.Add("| Source lines | $($report.Summary.SourceLines) |")
$markdown.Add("| Fact attributes | $($report.Summary.FactAttributes) |")
$markdown.Add("| Theory attributes | $($report.Summary.TheoryAttributes) |")
$markdown.Add("| InlineData attributes | $($report.Summary.InlineDataAttributes) |")
$markdown.Add('')
$markdown.Add('## Projects')
$markdown.Add('')
$markdown.Add('| Project | Framework | Test | In root solution | Source files | Source lines | Facts | Theories | InlineData |')
$markdown.Add('|---|---|:---:|:---:|---:|---:|---:|---:|---:|')
foreach ($project in $projects) {
    $markdown.Add("| $(Convert-ToMarkdownCell $project.Path) | $(Convert-ToMarkdownCell $project.TargetFramework) | $($project.IsTestProject) | $($project.InRootSolution) | $($project.SourceFiles) | $($project.SourceLines) | $($project.FactAttributes) | $($project.TheoryAttributes) | $($project.InlineDataAttributes) |")
}

if ($omittedProductionCandidates.Count -gt 0) {
    $markdown.Add('')
    $markdown.Add('## Production project candidates omitted from the root solution')
    $markdown.Add('')
    foreach ($project in $omittedProductionCandidates) {
        $markdown.Add("- ``$($project.Path)``")
    }
}

if ($duplicateGroups.Count -gt 0) {
    $markdown.Add('')
    $markdown.Add('## Duplicate project names')
    $markdown.Add('')
    foreach ($duplicateGroup in $duplicateGroups) {
        $markdown.Add("- **$($duplicateGroup.Name)**: $($duplicateGroup.Paths -join ', ')")
    }
}

$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Host "JSON baseline    : $jsonPath"
Write-Host "Markdown baseline: $markdownPath"

if ($PassThru) {
    return $report
}
