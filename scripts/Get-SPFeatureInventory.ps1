#Requires -Version 5.1

<#
.SYNOPSIS
    Inventories activated SharePoint features for migration scoping.

.DESCRIPTION
    Collects activated features at farm, web application, site collection,
    and web scope. Helps identify custom or third-party features that may
    affect migration to SharePoint Online.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.EXAMPLE
    .\Get-SPFeatureInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.

    Feature inventory across all webs may be slow in large environments.
#>

param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\output",
    [switch]$IncludePersonalSites
)

# Import shared module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\SPMigrationScopingToolkit\SPMigrationScopingToolkit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Warning "Shared module not found at: $modulePath"
}

# Initialize SharePoint snap-in
Initialize-SPSnapin

# Initialize output folder
Initialize-OutputFolder -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Feature Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Farm-scoped Features ---
Write-Host "Collecting farm-scoped features..." -ForegroundColor Cyan
try {
    $farmFeatures = Get-SPFeature -Limit All -ErrorAction SilentlyContinue | Where-Object { $_.Scope -eq "Farm" }
    foreach ($feature in $farmFeatures) {
        $results += [PSCustomObject]@{
            Scope              = "Farm"
            FeatureName        = $feature.DisplayName
            FeatureId          = $feature.Id
            CompatibilityLevel = $feature.CompatibilityLevel
            SiteCollectionUrl  = "N/A"
            WebUrl             = "N/A"
            RiskLevel          = "Medium"
            RecommendedAction  = "Review feature compatibility with SharePoint Online"
            AssessmentDate     = $assessmentDate
        }
    }
    Write-Host "  Found $(@($farmFeatures).Count) farm-scoped features." -ForegroundColor White
}
catch {
    Write-Warning "Failed to collect farm-scoped features: $($_.Exception.Message)"
}

# --- Web Application-scoped Features ---
Write-Host "Collecting web application-scoped features..." -ForegroundColor Cyan
try {
    $webApps = if ($WebApplicationUrl) {
        @(Get-SPWebApplication $WebApplicationUrl -ErrorAction Stop)
    }
    else {
        Get-SPWebApplication -ErrorAction Stop
    }

    foreach ($webApp in $webApps) {
        try {
            $waFeatures = $webApp.Features
            foreach ($feature in $waFeatures) {
                $featureDef = $feature.Definition
                $featureName = if ($featureDef) { $featureDef.DisplayName } else { "Unknown" }
                $featureId = $feature.DefinitionId

                $results += [PSCustomObject]@{
                    Scope              = "WebApplication"
                    FeatureName        = $featureName
                    FeatureId          = $featureId
                    CompatibilityLevel = if ($featureDef) { $featureDef.CompatibilityLevel } else { "N/A" }
                    SiteCollectionUrl  = "N/A"
                    WebUrl             = $webApp.Url
                    RiskLevel          = "Medium"
                    RecommendedAction  = "Review feature compatibility with SharePoint Online"
                    AssessmentDate     = $assessmentDate
                }
            }
        }
        catch {
            Write-Warning "Failed to collect features for web application: $($webApp.Url) - $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Warning "Failed to collect web application-scoped features: $($_.Exception.Message)"
}

# --- Site Collection and Web-scoped Features ---
Write-Host "Collecting site collection and web-scoped features..." -ForegroundColor Cyan
try {
    if ($SiteCollectionUrl) {
        $sites = @(Get-SPSite -Identity $SiteCollectionUrl -ErrorAction Stop)
    }
    elseif ($WebApplicationUrl) {
        $sites = Get-SPSite -WebApplication $WebApplicationUrl -Limit All -ErrorAction Stop
    }
    else {
        $sites = Get-SPSite -Limit All -ErrorAction Stop
    }

    $totalSites = @($sites).Count
    $siteCounter = 0

    foreach ($site in $sites) {
        $siteCounter++
        try {
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                continue
            }

            Write-Host "Processing site collection ($siteCounter/$totalSites): $($site.Url)" -ForegroundColor Cyan

            # Site collection features
            foreach ($feature in $site.Features) {
                try {
                    $featureDef = $feature.Definition
                    $featureName = if ($featureDef) { $featureDef.DisplayName } else { "Unknown" }

                    $results += [PSCustomObject]@{
                        Scope              = "Site"
                        FeatureName        = $featureName
                        FeatureId          = $feature.DefinitionId
                        CompatibilityLevel = if ($featureDef) { $featureDef.CompatibilityLevel } else { "N/A" }
                        SiteCollectionUrl  = $site.Url
                        WebUrl             = "N/A"
                        RiskLevel          = "Low"
                        RecommendedAction  = "Verify feature availability in SharePoint Online"
                        AssessmentDate     = $assessmentDate
                    }
                }
                catch {
                    Write-Warning "    Failed to process site feature: $($_.Exception.Message)"
                }
            }

            # Web-scoped features
            foreach ($web in $site.AllWebs) {
                try {
                    foreach ($feature in $web.Features) {
                        try {
                            $featureDef = $feature.Definition
                            $featureName = if ($featureDef) { $featureDef.DisplayName } else { "Unknown" }

                            $results += [PSCustomObject]@{
                                Scope              = "Web"
                                FeatureName        = $featureName
                                FeatureId          = $feature.DefinitionId
                                CompatibilityLevel = if ($featureDef) { $featureDef.CompatibilityLevel } else { "N/A" }
                                SiteCollectionUrl  = $site.Url
                                WebUrl             = $web.Url
                                RiskLevel          = "Low"
                                RecommendedAction  = "Verify feature availability in SharePoint Online"
                                AssessmentDate     = $assessmentDate
                            }
                        }
                        catch {
                            Write-Warning "      Failed to process web feature: $($_.Exception.Message)"
                        }
                    }
                }
                catch {
                    Write-Warning "  Failed to process web features: $($web.Url) - $($_.Exception.Message)"
                }
                finally {
                    if ($web) { $web.Dispose() }
                }
            }
        }
        catch {
            Write-Warning "Failed to process site collection: $($site.Url) - $($_.Exception.Message)"
        }
        finally {
            if ($site) { $site.Dispose() }
        }
    }
}
catch {
    Write-Warning "Failed to collect site/web features: $($_.Exception.Message)"
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "feature-inventory"
    Write-Host ""
    Write-Host "Feature inventory complete." -ForegroundColor Green
    Write-Host "Total features collected: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No features collected."
}

Write-Host ""
