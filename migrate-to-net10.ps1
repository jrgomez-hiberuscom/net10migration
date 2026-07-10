<#
.SYNOPSIS
Runs the .NET 10 migration workflow by updating target frameworks, generating .slnx files, and centralizing/enforcing NuGet package versions in Directory.Packages.props.

.PARAMETER SolutionRoot
Root directory of the solution that contains the .sln file and .csproj files to migrate.
#>
param(
    [string]$SolutionRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$numericIdentifierPattern = '^\d+$'

function Save-XmlUtf8 {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$XmlDocument,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`n"
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $XmlDocument.Save($writer)
    }
    finally {
        $writer.Dispose()
    }
}

function Ensure-DirectoryPackagesProps {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $xml = New-Object System.Xml.XmlDocument
        $xml.LoadXml("<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally></PropertyGroup><ItemGroup /></Project>")
        Save-XmlUtf8 -XmlDocument $xml -Path $Path
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Raw

    $projectNode = $doc.SelectSingleNode("/*[local-name()='Project']")
    if (-not $projectNode) {
        throw "The file '$Path' does not contain a valid Project node."
    }

    $propertyGroup = $projectNode.SelectSingleNode("./*[local-name()='PropertyGroup'][*[local-name()='ManagePackageVersionsCentrally']]")
    if (-not $propertyGroup) {
        $propertyGroup = $doc.CreateElement("PropertyGroup")
        [void]$projectNode.PrependChild($propertyGroup)
    }

    $manageNode = $propertyGroup.SelectSingleNode("./*[local-name()='ManagePackageVersionsCentrally']")
    if (-not $manageNode) {
        $manageNode = $doc.CreateElement("ManagePackageVersionsCentrally")
        [void]$propertyGroup.AppendChild($manageNode)
    }
    $manageNode.InnerText = "true"

    $itemGroup = $projectNode.SelectSingleNode("./*[local-name()='ItemGroup'][*[local-name()='PackageVersion']]")
    if (-not $itemGroup) {
        $itemGroup = $doc.CreateElement("ItemGroup")
        [void]$projectNode.AppendChild($itemGroup)
    }

    Save-XmlUtf8 -XmlDocument $doc -Path $Path
}

function Get-PackageKey {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Node
    )

    $includeAttribute = $Node.Attributes["Include"]
    if ($includeAttribute -and -not [string]::IsNullOrWhiteSpace($includeAttribute.Value)) {
        return $includeAttribute.Value.Trim()
    }

    $updateAttribute = $Node.Attributes["Update"]
    if ($updateAttribute -and -not [string]::IsNullOrWhiteSpace($updateAttribute.Value)) {
        return $updateAttribute.Value.Trim()
    }

    return $null
}

function Compare-VersionIdentifier {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,
        [Parameter(Mandatory = $true)]
        [string]$Right
    )

    $leftIsNumber = $Left -match $numericIdentifierPattern
    $rightIsNumber = $Right -match $numericIdentifierPattern

    if ($leftIsNumber -and $rightIsNumber) {
        $leftNumber = [int64]0
        $rightNumber = [int64]0
        if (-not [int64]::TryParse($Left, [ref]$leftNumber) -or -not [int64]::TryParse($Right, [ref]$rightNumber)) {
            return [string]::Compare($Left, $Right, [System.StringComparison]::Ordinal)
        }
        if ($leftNumber -lt $rightNumber) { return -1 }
        if ($leftNumber -gt $rightNumber) { return 1 }
        return 0
    }

    # SemVer precedence: numeric pre-release identifiers have lower precedence than non-numeric identifiers.
    if ($leftIsNumber) { return -1 }
    if ($rightIsNumber) { return 1 }

    return [string]::Compare($Left, $Right, [System.StringComparison]::Ordinal)
}

function Compare-PackageVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LeftVersion,
        [Parameter(Mandatory = $true)]
        [string]$RightVersion
    )

    $parseVersionString = {
        param([string]$VersionText)

        $withoutMetadata = ($VersionText -split '\+', 2)[0]
        $parts = $withoutMetadata -split '-', 2
        $coreText = $parts[0]
        $preReleaseText = if ($parts.Count -gt 1) { $parts[1] } else { $null }

        $coreNumbers = @()
        foreach ($segment in ($coreText -split '\.')) {
            $value = [int64]0
            if (-not [int64]::TryParse($segment, [ref]$value)) {
                Write-Warning "Could not parse version '$VersionText'. Segment '$segment' is not numeric. Falling back to simple string comparison, which may select the wrong highest version. Review the affected package version in Directory.Packages.props after the migration."
                return $null
            }
            $coreNumbers += $value
        }

        return @{
            Core = @($coreNumbers)
            PreRelease = if ([string]::IsNullOrWhiteSpace($preReleaseText)) { @() } else { @($preReleaseText -split '\.') }
        }
    }

    $left = & $parseVersionString $LeftVersion
    $right = & $parseVersionString $RightVersion

    if (-not $left -or -not $right) {
        return [string]::Compare($LeftVersion, $RightVersion, [System.StringComparison]::Ordinal)
    }

    $leftCore = @($left.Core)
    $rightCore = @($right.Core)
    $leftPreRelease = @($left.PreRelease)
    $rightPreRelease = @($right.PreRelease)

    $maxCoreLength = [Math]::Max($leftCore.Count, $rightCore.Count)
    for ($index = 0; $index -lt $maxCoreLength; $index++) {
        $leftNumber = if ($index -lt $leftCore.Count) { $leftCore[$index] } else { 0 }
        $rightNumber = if ($index -lt $rightCore.Count) { $rightCore[$index] } else { 0 }

        if ($leftNumber -lt $rightNumber) { return -1 }
        if ($leftNumber -gt $rightNumber) { return 1 }
    }

    $leftIsStable = $leftPreRelease.Count -eq 0
    $rightIsStable = $rightPreRelease.Count -eq 0
    if ($leftIsStable -and $rightIsStable) { return 0 }
    if ($leftIsStable) { return 1 }
    if ($rightIsStable) { return -1 }

    $maxPreReleaseLength = [Math]::Max($leftPreRelease.Count, $rightPreRelease.Count)
    for ($index = 0; $index -lt $maxPreReleaseLength; $index++) {
        if ($index -ge $leftPreRelease.Count) { return -1 }
        if ($index -ge $rightPreRelease.Count) { return 1 }

        $comparison = Compare-VersionIdentifier -Left $leftPreRelease[$index] -Right $rightPreRelease[$index]
        if ($comparison -ne 0) {
            return $comparison
        }
    }

    return 0
}

function Get-HigherPackageVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        [Parameter(Mandatory = $true)]
        [string]$CandidateVersion
    )

    if ((Compare-PackageVersion -LeftVersion $CurrentVersion -RightVersion $CandidateVersion) -ge 0) {
        return $CurrentVersion
    }

    return $CandidateVersion
}

function Update-TargetFrameworks {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$ProjectFiles
    )

    $updatedProjects = 0
    foreach ($projectFile in $ProjectFiles) {
        [xml]$projectDocument = Get-Content -LiteralPath $projectFile.FullName -Raw
        $projectChanged = $false

        $targetFrameworkNodes = $projectDocument.SelectNodes("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks']")
        foreach ($targetFrameworkNode in $targetFrameworkNodes) {
            $currentValue = $targetFrameworkNode.InnerText
            if ([string]::IsNullOrWhiteSpace($currentValue)) {
                continue
            }

            $updatedValue = [System.Text.RegularExpressions.Regex]::Replace($currentValue, "(^|;)net8\.0(?=;|$)", '${1}net10.0')
            if ($updatedValue -ne $currentValue) {
                $targetFrameworkNode.InnerText = $updatedValue
                $projectChanged = $true
            }
        }

        if ($projectChanged) {
            Save-XmlUtf8 -XmlDocument $projectDocument -Path $projectFile.FullName
            $updatedProjects++
        }
    }

    return $updatedProjects
}

function Convert-SolutionsToSlnx {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $createdSlnx = 0
    $solutionFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.sln" -File |
        Where-Object { $_.FullName -notmatch "[/\\](bin|obj)([/\\]|$)" }

    foreach ($solutionFile in $solutionFiles) {
        $slnxPath = [System.IO.Path]::ChangeExtension($solutionFile.FullName, ".slnx")
        if (Test-Path -LiteralPath $slnxPath) {
            continue
        }

        $stdout = ""
        $stderr = ""
        $exitCode = 0

        # Try both command syntaxes to support different SDK CLI layouts during transition to .NET 10 tooling.
        $stdout = (& dotnet sln migrate $solutionFile.FullName --output $slnxPath 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $stderr = $stdout
            $stdout = (& dotnet sln $solutionFile.FullName migrate --output $slnxPath 2>&1 | Out-String)
            $exitCode = $LASTEXITCODE
        }

        if ($exitCode -ne 0) {
            throw "Failed to convert '$($solutionFile.FullName)' to '.slnx'. dotnet output: $stderr $stdout"
        }

        if (-not (Test-Path -LiteralPath $slnxPath)) {
            throw "dotnet migration for '$($solutionFile.FullName)' completed without errors, but '$slnxPath' was not created."
        }

        $createdSlnx++
    }

    return $createdSlnx
}

if (-not (Test-Path -LiteralPath $SolutionRoot)) {
    throw "The path '$SolutionRoot' does not exist."
}

$solutionRootFullPath = (Resolve-Path -LiteralPath $SolutionRoot).Path

$targetPackageVersions = @{
    "bunit" = "2.7.2"
    "coverlet.collector" = "10.0.1"
    "FluentAssertions" = "8.10.0"
    "Microsoft.AspNetCore.Components.Web" = "10.0.9"
    "Microsoft.AspNetCore.Components.WebAssembly" = "10.0.9"
    "Microsoft.NET.Test.Sdk" = "18.7.0"
    "NUnit" = "4.6.1"
    "NUnit.Analyzers" = "4.14.0"
    "NUnit3TestAdapter" = "6.2.0"
    "SsidArqNet.Ateka.PublisherProxy" = "1.0.1"
    "SsidArqNet.Components.Blazor.Reporta" = "1.1.0"
    "SsidArqNet.InternalComponents.Blazor.TemplateBuilder" = "1.2.0"
}

$directoryPackagesPath = Join-Path $solutionRootFullPath "Directory.Packages.props"
Ensure-DirectoryPackagesProps -Path $directoryPackagesPath

[xml]$directoryPackagesDocument = Get-Content -LiteralPath $directoryPackagesPath -Raw
$packageVersions = @{}

$existingPackageVersionNodes = $directoryPackagesDocument.SelectNodes("/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='PackageVersion']")
foreach ($packageVersionNode in $existingPackageVersionNodes) {
    $includeAttribute = $packageVersionNode.Attributes["Include"]
    $versionAttribute = $packageVersionNode.Attributes["Version"]
    $packageName = if ($includeAttribute) { $includeAttribute.Value } else { $null }
    $versionValue = if ($versionAttribute) { $versionAttribute.Value } else { $null }
    if ([string]::IsNullOrWhiteSpace($packageName) -or [string]::IsNullOrWhiteSpace($versionValue)) {
        continue
    }
    $packageVersions[$packageName] = $versionValue
}

$csprojFiles = Get-ChildItem -Path $solutionRootFullPath -Recurse -Filter "*.csproj" -File |
    Where-Object { $_.FullName -notmatch "[/\\](bin|obj)([/\\]|$)" }

$updatedTargetFrameworkProjects = Update-TargetFrameworks -ProjectFiles $csprojFiles
$createdSlnxCount = Convert-SolutionsToSlnx -RootPath $solutionRootFullPath

foreach ($csproj in $csprojFiles) {
    [xml]$projectDocument = Get-Content -LiteralPath $csproj.FullName -Raw
    $projectChanged = $false

    $packageReferenceNodes = $projectDocument.SelectNodes("//*[local-name()='PackageReference']")
    foreach ($packageReferenceNode in $packageReferenceNodes) {
        $packageKey = Get-PackageKey -Node $packageReferenceNode
        if ([string]::IsNullOrWhiteSpace($packageKey)) {
            continue
        }

        $versionValue = $null
        if ($packageReferenceNode.Attributes["Version"]) {
            $versionValue = $packageReferenceNode.Attributes["Version"].Value
            [void]$packageReferenceNode.Attributes.RemoveNamedItem("Version")
            $projectChanged = $true
        }

        $versionNode = $packageReferenceNode.SelectSingleNode("./*[local-name()='Version']")
        if ($versionNode -and -not [string]::IsNullOrWhiteSpace($versionNode.InnerText)) {
            $versionValue = $versionNode.InnerText.Trim()
            [void]$packageReferenceNode.RemoveChild($versionNode)
            $projectChanged = $true
        }

        if ([string]::IsNullOrWhiteSpace($versionValue)) {
            continue
        }

        if ($packageVersions.Contains($packageKey)) {
            $packageVersions[$packageKey] = Get-HigherPackageVersion -CurrentVersion $packageVersions[$packageKey] -CandidateVersion $versionValue
            continue
        }

        $packageVersions[$packageKey] = $versionValue
    }

    if ($projectChanged) {
        Save-XmlUtf8 -XmlDocument $projectDocument -Path $csproj.FullName
    }
}

foreach ($packageName in $targetPackageVersions.Keys) {
    $packageVersions[$packageName] = $targetPackageVersions[$packageName]
}

$projectNode = $directoryPackagesDocument.SelectSingleNode("/*[local-name()='Project']")
$packageItemGroup = $projectNode.SelectSingleNode("./*[local-name()='ItemGroup'][*[local-name()='PackageVersion']]")
if (-not $packageItemGroup) {
    $packageItemGroup = $directoryPackagesDocument.CreateElement("ItemGroup")
    [void]$projectNode.AppendChild($packageItemGroup)
}

$currentPackageVersionNodes = $directoryPackagesDocument.SelectNodes("/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='PackageVersion']")
# Wrap the live XML NodeList in @() to create an array copy and avoid collection modification errors during iteration.
foreach ($node in @($currentPackageVersionNodes)) {
    [void]$node.ParentNode.RemoveChild($node)
}

foreach ($packageName in ($packageVersions.Keys | Sort-Object)) {
    $packageVersionNode = $directoryPackagesDocument.CreateElement("PackageVersion")
    [void]$packageVersionNode.SetAttribute("Include", $packageName)
    [void]$packageVersionNode.SetAttribute("Version", $packageVersions[$packageName])
    [void]$packageItemGroup.AppendChild($packageVersionNode)
}

Save-XmlUtf8 -XmlDocument $directoryPackagesDocument -Path $directoryPackagesPath

Write-Host "Central package version migration completed."
Write-Host "- Directory.Packages.props ensured at: $directoryPackagesPath"
Write-Host "- Projects analyzed: $($csprojFiles.Count)"
Write-Host "- Projects updated from net8.0 to net10.0: $updatedTargetFrameworkProjects"
Write-Host "- .sln to .slnx conversions created: $createdSlnxCount"
Write-Host "- Packages centralized: $($packageVersions.Count)"
