#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies SharePoint site collections and subsites that may be inactive or stale.

.DESCRIPTION
    Scans site collections and webs to identify those that have not been modified
    within a defined threshold period. Stale sites are candidates for archiving,
    exclusion from migration, or business owner confirmation.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER StaleSiteThresholdDays
    Number of days since last modification to consider a site stale. Default is 365.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.PARAMETER IncludeSubsites
    Include subsites in the stale site analysis.

.EXAMPLE
    .\Get-SPStaleSitesReport.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.EXAMPLE
    .\Get-SPStaleSitesReport.ps1 -StaleSiteThresholdDays 180 -IncludeSubsites

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.
#>

param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\output",
    [int]$StaleSiteThresholdDays = 365,
    [switch]$IncludePersonalSites,
    [switch]$IncludeSubsites
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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()
$cutoffDate = (Get-Date).AddDays(-$StaleSiteThresholdDays)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Stale Sites Report" -ForegroundColor Cyan
Write-Host " Threshold: $StaleSiteThresholdDays days" -ForegroundColor Cyan
Write-Host " Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get site collections
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
    Write-ToolkitLog -Message "Scanning $totalSites site collections for stale sites..." -Level Info
    $siteCounter = 0

    foreach ($site in $sites) {
        $siteCounter++
        try {
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                continue
            }

            Write-ToolkitLog -Message "Processing site collection ($siteCounter/$totalSites): $($site.Url)" -Level Progress

            # Check site collection level
            if ($site.LastContentModifiedDate -lt $cutoffDate) {
                $daysSinceModified = [math]::Floor(((Get-Date) - $site.LastContentModifiedDate).TotalDays)
                $riskLevel = Get-StaleSiteRiskLevel -DaysSinceLastModified $daysSinceModified
                $storageUsedMB = [math]::Round($site.Usage.Storage / 1MB, 2)

                $primaryOwner = if ($site.Owner) { $site.Owner.LoginName } else { "N/A" }
                $secondaryOwner = if ($site.SecondaryContact) { $site.SecondaryContact.LoginName } else { "N/A" }

                $recommendedAction = switch ($riskLevel) {
                    "Critical" { "Archive candidate; business confirmation required before migration" }
                    "High"     { "Consider archive or exclusion from migration scope" }
                    "Medium"   { "Confirm with business owner before migration" }
                    default    { "Review before migration" }
                }

                $results += [PSCustomObject]@{
                    SiteCollectionUrl       = $site.Url
                    WebUrl                  = $site.Url
                    Title                   = $site.RootWeb.Title
                    LastContentModifiedDate = $site.LastContentModifiedDate.ToString("yyyy-MM-dd HH:mm:ss")
                    DaysSinceLastModified   = $daysSinceModified
                    PrimaryOwner            = $primaryOwner
                    SecondaryOwner          = $secondaryOwner
                    StorageUsedMB           = $storageUsedMB
                    RiskLevel               = $riskLevel
                    RecommendedAction       = $recommendedAction
                    AssessmentDate          = $assessmentDate
                }

                Write-ToolkitLog -Message "  [STALE] $($site.RootWeb.Title) - $daysSinceModified days ($riskLevel)" -Level Warning
            }

            # Optionally check subsites
            if ($IncludeSubsites) {
                foreach ($web in $site.AllWebs) {
                    try {
                        # Skip root web (already checked at site collection level)
                        if ($web.Url -eq $site.Url) {
                            continue
                        }

                        if ($web.LastItemModifiedDate -lt $cutoffDate) {
                            $daysSinceModified = [math]::Floor(((Get-Date) - $web.LastItemModifiedDate).TotalDays)
                            $riskLevel = Get-StaleSiteRiskLevel -DaysSinceLastModified $daysSinceModified

                            $recommendedAction = switch ($riskLevel) {
                                "Critical" { "Archive candidate; business confirmation required" }
                                "High"     { "Consider archive or exclusion" }
                                "Medium"   { "Confirm with business owner before migration" }
                                default    { "Review before migration" }
                            }

                            $results += [PSCustomObject]@{
                                SiteCollectionUrl       = $site.Url
                                WebUrl                  = $web.Url
                                Title                   = $web.Title
                                LastContentModifiedDate = $web.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss")
                                DaysSinceLastModified   = $daysSinceModified
                                PrimaryOwner            = "N/A"
                                SecondaryOwner          = "N/A"
                                StorageUsedMB           = "N/A"
                                RiskLevel               = $riskLevel
                                RecommendedAction       = $recommendedAction
                                AssessmentDate          = $assessmentDate
                            }
                        }
                    }
                    catch {
                        Write-ToolkitLog -Message "  Failed to process web: $($web.Url) - $($_.Exception.Message)" -Level Warning
                    }
                    finally {
                        if ($web) { $web.Dispose() }
                    }
                }
            }
        }
        catch {
            Write-ToolkitLog -Message "Failed to process site collection: $($site.Url) - $($_.Exception.Message)" -Level Warning
        }
        finally {
            if ($site) { $site.Dispose() }
        }
    }
}
catch {
    Write-ToolkitLog -Message "Error retrieving sites: $($_.Exception.Message)" -Level Error
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "stale-sites-report"
    Write-Host ""
    Write-ToolkitLog -Message "Stale sites report complete." -Level Success
    Write-ToolkitLog -Message "Total stale sites found: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No stale sites found (threshold: $StaleSiteThresholdDays days)." -Level Warning
}

Write-Host ""
