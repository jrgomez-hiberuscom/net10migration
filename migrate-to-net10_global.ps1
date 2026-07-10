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

function Update-CSharpApiReferences {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $replacements = @(
    @{
        Old = @'
RegistradorSerilogLogger.RegistrarLoggerDesdeConfiguracionSerilog(
    loggingBuilder: loggingBuilder,
    configuration: builder.Configuration
)
'@
        New = @'
builder.Services.AddSsidArqNetLoggerFromAppSettings(
    configuration: builder.Configuration
)
'@
    },
    @{ Old = 'builder.Services.ConfigurarAspNetCoreApiSanitizacionDesdeAppSettings(config: builder.Configuration)'; New = 'builder.Services.AddSsidArqNetApiSanitizacionFromAppSettings(config: builder.Configuration)' },
    @{ Old = 'builder.Services.RegistrarAutenticacionNetCoreApiFromSettings(conf: builder.Configuration);'; New = 'builder.Services.AddSsidArqNetApiAuthenticationFromAppSettings(conf: builder.Configuration);' },
    @{ Old = 'builder.Services.AddSwaggerAtekaFromSettings(config: builder.Configuration);'; New = 'builder.Services.AddSsidArqNetSwaggerAtekaFromAppSettings(config: builder.Configuration);' },
    @{ Old = 'app.UseSwaggerAtekaFromSettings(config: builder.Configuration);'; New = 'app.UseSsidArqNetSwaggerAteka(config: builder.Configuration);' },
    @{ Old = 'RegistrarLoggerDesdeConfiguracionSerilog('; New = 'AddSsidArqNetLoggerFromAppSettings(' },
    @{ Old = 'ConfigurarAspNetCoreApiSanitizacionDesdeAppSettings('; New = 'AddSsidArqNetApiSanitizationFromAppSettings(' },
    @{ Old = 'RegistrarAutenticacionNetCoreApiFromSettings('; New = 'AddSsidArqNetApiAuthenticationFromAppSettings(' },
    @{ Old = 'AddSwaggerAtekaFromSettings('; New = 'AddSsidArqNetSwaggerAtekaFromAppSettings(' },
    @{ Old = '// Configuración manual de logging basada en Serilog'; New = 'AddSsidArqNetLoggerFromAppSettings(builder.Configuration)' },
    @{ Old = 'AddAspNetCoreBlazorSanitizacionFromAppSettings('; New = 'AddSsidArqNetBlazorSanitizacionFromAppSettings(' },
    @{ Old = 'AddAspNetCoreBlazorServerAuthenticationFromAppSettings('; New = 'AddSsidArqNetBlazorServerAuthenticationFromAppSettings(' },
    @{ Old = 'AddAspNetCoreBlazorServerStorageManagement()'; New = 'AddSsidArqNetBlazorServerStorageManagement()' },
    @{ Old = 'AddOpenApiClientAspNetCoreBlazorServerFromAppSettings('; New = 'AddSsidArqNetOpenApiClientAspNetCoreBlazorServerFromAppSettings(' },
    @{ Old = 'AddAspNetCoreBlazorServerLayoutInternetFromAppSettings<MenuItemManager>('; New = 'AddSsidArqNetBlazorServerLayoutInternetFromAppSettings<MenuItemManager>(' },
    @{ Old = 'AddAspNetCoreBlazorServerUserContext()'; New = 'AddSsidArqNetBlazorServerUserContext()' },
    @{
        Old = 'app.UsarAspNetCoreBlazorServerLayoutInternet();'
        New = @'
app.UseSsidArqNetBlazorServerLayoutInternet()
   .UseSsidArqNetBlazorServerStorageManagement();
app.MapStaticAssets();
app.UseAntiforgery();
'@
    },
    @{ Old = 'Services.ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings(config: builder.Configuration)'; New = 'Services.AddSsidArqNetBlazorSanitizacionFromAppSettings(config: builder.Configuration)' },
    @{
        Old = @'
.ConfigurarAspNetCoreBlazorWebAssemblyLayoutInternetDesdeAppSettings<MenuItemManager>(
        configuration: builder.Configuration
    );
'@
        New = @'
.AddSsidArqNetBlazorWebAssemblyLayoutInternetFromAppSettings<MenuItemManager>(
        configuration: builder.Configuration
    )
'@
    },
    @{ Old = 'await host.UsarAspNetCoreBlazorWebAssemblyLayoutInternetAsync();'; New = 'await host.UseSsidArqNetBlazorWebAssemblyLayoutInternetAsync();' },
    @{ Old = 'builder.ConfigurarProxyDesdeAppSettings();'; New = 'builder.AddSsidArqNetAtekaProxyFromAppSettings();' },
    @{ Old = 'RegistradorSerilogLogger.RegistrarLoggerDesdeConfiguracionSerilog('; New = 'AddSsidArqNetLoggerFromAppSettings(' },
    @{ Old = 'ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings('; New = 'AddSsidArqNetBlazorSanitizacionFromAppSettings(' },
    @{ Old = 'RegistrarAutenticacionNetCoreBlazorServerSideIncluidasRazorPagesFromSettings('; New = 'AddSsidArqNetBlazorServerAuthenticationFromAppSettings(' },
    @{ Old = 'ConfigurarAspNetCoreMenuManagement<MenuItemManager>()'; New = 'AddSsidArqNetMenuManagement<MenuItemManager>()' },
    @{
        Old = @'
.ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings(
    config: builder.Configuration
)
'@
        New = @'
.AddSsidArqNetBlazorSanitizacionFromAppSettings(
    config: builder.Configuration
)
'@
    },
    @{
        Old = @'
.ConfigurarAspNetCoreBlazorWebAssemblyInternationalizationDesdeAppSettings(
    configuration: builder.Configuration
)
'@
        New = @'
.AddSsidArqNetBlazorWebAssemblyInternationalizationFromAppSettings(
    configuration: builder.Configuration
)
'@
    },
    @{
        Old = '.ConfigurarAspNetCoreMenuManagement<MenuItemManager>();'
        New = @'
.AddSsidArqNetBlazorWasmAuthentication()
.AddSsidArqNetBlazorWasmUserContext()
.AddSsidArqNetMenuManagement<MenuItemManager>();
'@
    },
    @{ Old = 'await host.UsarAspNetCoreBlazorWebAssemblyInternationalizationAsync();'; New = 'await host.UseSsidArqNetBlazorWebAssemblyInternationalizationAsync();' },
    @{ Old = 'app.UsarProxyDesdeAppSettings()'; New = 'app.UseSsidArqNetProxy()' },
    @{ Old = 'RegistrarTokenExchangerFromSettings('; New = 'AddSsidArqNetTokenExchangerFromSettings(' },
    @{ Old = 'ConfigurarOpenApiNet('; New = 'AddSsidArqNetOpenApiClientFromAppSettings(' },
    @{ Old = 'using SsidArqNet.Ateka.TokenExchanger.Extensions;'; New = 'using SsidArqNet.Ateka.TokenExchanger.Extensions.Extensions;' },
    @{ Old = 'ensamblado:'; New = 'defaultAssembly:' }
    )

    $csFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.cs" -File |
        Where-Object { $_.FullName -notmatch "[/\\](bin|obj)([/\\]|$)" }

    $updatedFiles = 0
    foreach ($csFile in $csFiles) {
        $content = Get-Content -LiteralPath $csFile.FullName -Raw
        $updatedContent = $content

        foreach ($replacement in $replacements) {
            $updatedContent = $updatedContent.Replace($replacement.Old, $replacement.New)
        }

        if ($updatedContent -ne $content) {
            [System.IO.File]::WriteAllText($csFile.FullName, $updatedContent, [System.Text.UTF8Encoding]::new($false))
            $updatedFiles++
        }
    }

    return $updatedFiles
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

        $stdout = (& dotnet solution $solutionFile.FullName migrate 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            throw "Failed to convert '$($solutionFile.FullName)' to '.slnx'. dotnet output: $stdout"
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
    "AutoMapper" = "14.0.0"
    "Bogus" = "35.6.5"
    "bunit" = "2.7.2"
    "coverlet.collector" = "8.0.1"
    "FluentAssertions" = "7.2.2"
    "Microsoft.AspNetCore.Authentication.JwtBearer" = "10.0.5"
    "Microsoft.AspNetCore.Authentication.OpenIdConnect" = "10.0.5"
    "Microsoft.AspNetCore.Components.Authorization" = "10.0.5"
    "Microsoft.AspNetCore.Components.Web" = "10.0.5"
    "Microsoft.AspNetCore.Components.WebAssembly" = "10.0.5"
    "Microsoft.AspNetCore.Components.WebAssembly.Server" = "10.0.5"
    "Microsoft.AspNetCore.Diagnostics" = "2.3.10"
    "Microsoft.AspNetCore.Http" = "2.3.10"
    "Microsoft.AspNetCore.Mvc.Core" = "2.3.9"
    "Microsoft.AspNetCore.Mvc.Testing" = "10.0.5"
    "Microsoft.AspNetCore.TestHost" = "10.0.5"
    "Microsoft.EntityFrameworkCore" = "10.0.5"
    "Microsoft.EntityFrameworkCore.Design" = "10.0.5"
    "Microsoft.EntityFrameworkCore.InMemory" = "10.0.5"
    "Microsoft.EntityFrameworkCore.SqlServer" = "10.0.5"
    "Microsoft.EntityFrameworkCore.Tools" = "10.0.5"
    "Microsoft.Extensions.Configuration.Binder" = "10.0.5"
    "Microsoft.Extensions.Localization" = "10.0.8"
    "Microsoft.NET.Test.Sdk" = "18.6.0"
    "Moq" = "4.20.72"
    "Newtonsoft.Json" = "13.0.3"
    "NSwag.ApiDescription.Client" = "14.7.1"
    "NUnit" = "4.6.1"
    "NUnit.Analyzers" = "4.13.0"
    "NUnit3TestAdapter" = "6.2.0"
    "Radzen.Blazor" = "9.1.0"
    "Serilog" = "3.1.0"
    "SsidArqNet.Ateka.AspNetCore.Api" = "10.0.0"
    "SsidArqNet.Ateka.AspNetCore.Api.Swagger" = "10.0.0"
    "SsidArqNet.Ateka.AspNetCore.Blazor.Server" = "10.0.0"
    "SsidArqNet.Ateka.AspNetCoreApi" = "10.0.0"
    "SsidArqNet.Ateka.AspNetCoreApi.Swagger" = "10.0.0"
    "SsidArqNet.Ateka.Blazor.Server" = "10.0.0"
    "SsidArqNet.Ateka.Blazor.Server.UserContext" = "10.0.0"
    "SsidArqNet.Ateka.Blazor.Wasm" = "10.0.0"
    "SsidArqNet.Ateka.Blazor.Wasm.UserContext" = "10.0.0"
    "SsidArqNet.Ateka.Core" = "10.0.0"
    "SsidArqNet.Ateka.PublisherProxy" = "10.0.0"
    "SsidArqNet.Ateka.UserContext" = "10.0.0"
    "SsidArqNet.Ateka.UserContext.AspNetCore" = "10.0.0"
    "SsidArqNet.Components.Blazor.Layout.Internet" = "10.0.0"
    "SsidArqNet.Components.Blazor.MenuManagement" = "10.0.0"
    "SsidArqNet.Components.Blazor.Server.Layout.Internet" = "10.0.0"
    "SsidArqNet.Components.Blazor.Wasm.Layout.Internet" = "10.0.0"
    "SsidArqNet.Core" = "10.0.0"
    "SsidArqNet.Core.ProblemDetails" = "10.0.0"
    "SsidArqNet.Core.SeedWork" = "10.0.0"
    "SsidArqNet.ExceptionManagement.AspNetCore.Api" = "10.0.0"
    "SsidArqNet.ExceptionManagement.AspNetCore.Blazor" = "10.0.0"
    "SsidArqNet.ExceptionManagement.Core" = "10.0.0"
    "SsidArqNet.Internationalization.AspNetCore.Blazor" = "10.0.0"
    "SsidArqNet.Internationalization.Blazor.Server" = "10.0.0"
    "SsidArqNet.Internationalization.Blazor.Wasm" = "10.0.0"
    "SsidArqNet.Internationalization.IcuData" = "10.0.0"
    "SsidArqNet.Logger.Serilog.Net.Extension" = "10.0.0"
    "SsidArqNet.OpenApiClient.AspNetCore" = "10.0.0"
    "SsidArqNet.StorageManagement.Blazor.Server" = "10.0.0"
    "System.ServiceModel.Duplex" = "6.0.0"
    "System.ServiceModel.Federation" = "10.0.652802"
    "System.ServiceModel.Http" = "10.0.652802"
    "System.ServiceModel.NetTcp" = "10.0.652802"
    "System.ServiceModel.Security" = "6.0.0"
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
$updatedCSharpFiles = Update-CSharpApiReferences -RootPath $solutionRootFullPath

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
Write-Host "- C# files updated with API reference replacements: $updatedCSharpFiles"
