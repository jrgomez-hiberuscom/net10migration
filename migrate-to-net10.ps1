<#
.SYNOPSIS
Centralizes NuGet package versions into Directory.Packages.props.

.PARAMETER SolutionRoot
Root directory of the solution that contains the .sln file and .csproj files to migrate.
#>
param(
    [string]$SolutionRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if (-not (Test-Path -LiteralPath $SolutionRoot)) {
    throw "The path '$SolutionRoot' does not exist."
}

$solutionRootFullPath = (Resolve-Path -LiteralPath $SolutionRoot).Path

$directoryPackagesPath = Join-Path $solutionRootFullPath "Directory.Packages.props"
Ensure-DirectoryPackagesProps -Path $directoryPackagesPath

[xml]$directoryPackagesDocument = Get-Content -LiteralPath $directoryPackagesPath -Raw
$packageVersions = [ordered]@{}
$packageSources = @{}

$existingPackageVersionNodes = $directoryPackagesDocument.SelectNodes("/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='PackageVersion']")
foreach ($packageVersionNode in $existingPackageVersionNodes) {
    $packageName = $packageVersionNode.Attributes["Include"]?.Value
    $versionValue = $packageVersionNode.Attributes["Version"]?.Value
    if ([string]::IsNullOrWhiteSpace($packageName) -or [string]::IsNullOrWhiteSpace($versionValue)) {
        continue
    }

    $packageVersions[$packageName] = $versionValue
    $packageSources[$packageName] = @($directoryPackagesPath)
}

$csprojFiles = Get-ChildItem -Path $solutionRootFullPath -Recurse -Filter "*.csproj" -File |
    Where-Object { $_.FullName -notmatch "[/\\](bin|obj)([/\\]|$)" }

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
            if ($packageVersions[$packageKey] -ne $versionValue) {
                $existingSource = ($packageSources[$packageKey] -join ", ")
                throw "Version conflict for '$packageKey': '$($packageVersions[$packageKey])' in '$existingSource' and '$versionValue' in '$($csproj.FullName)'."
            }

            if (-not ($packageSources[$packageKey] -contains $csproj.FullName)) {
                $packageSources[$packageKey] += $csproj.FullName
            }
            continue
        }

        $packageVersions[$packageKey] = $versionValue
        $packageSources[$packageKey] = @($csproj.FullName)
    }

    if ($projectChanged) {
        Save-XmlUtf8 -XmlDocument $projectDocument -Path $csproj.FullName
    }
}

$projectNode = $directoryPackagesDocument.SelectSingleNode("/*[local-name()='Project']")
$packageItemGroup = $projectNode.SelectSingleNode("./*[local-name()='ItemGroup'][*[local-name()='PackageVersion']]")
if (-not $packageItemGroup) {
    $packageItemGroup = $directoryPackagesDocument.CreateElement("ItemGroup")
    [void]$projectNode.AppendChild($packageItemGroup)
}

$currentPackageVersionNodes = $directoryPackagesDocument.SelectNodes("/*[local-name()='Project']/*[local-name()='ItemGroup']/*[local-name()='PackageVersion']")
# Create a copy before removal to avoid mutating a live XML node collection during enumeration.
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

Write-Host "Step 1 completed."
Write-Host "- Directory.Packages.props ensured at: $directoryPackagesPath"
Write-Host "- Projects analyzed: $($csprojFiles.Count)"
Write-Host "- Packages centralized: $($packageVersions.Count)"
