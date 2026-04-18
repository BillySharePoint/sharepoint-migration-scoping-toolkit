#Requires -Version 5.1

<#
.SYNOPSIS
    Generates an inventory of SharePoint lists and document libraries for migration scoping.

.DESCRIPTION
    Collects list and library information including item count, versioning settings,
    permissions, and migration risk indicators. Exports results to CSV.

    This report is highly useful for migration scoping because list size, library size,
    versioning, and content types can affect migration complexity.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the inventory.

.PARAMETER IncludeHiddenLists
    Include hidden lists in the inventory. Default is to skip hidden lists.

.PARAMETER LargeListThreshold
    Item count threshold to flag a list as large. Default is 5000.

.EXAMPLE
    .\Get-SPListLibraryInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.EXAMPLE
    .\Get-SPListLibraryInventory.ps1 -SiteCollectionUrl "https://sharepoint.contoso.com/sites/hr"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.
#>

param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\output",
    [switch]$IncludePersonalSites,
    [switch]$IncludeHiddenLists,
    [int]$LargeListThreshold = 5000
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
Write-Host " List & Library Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get site collections
    if ($SiteCollectionUrl) {
        Write-Host "Scanning site collection: $SiteCollectionUrl" -ForegroundColor Cyan
        $sites = @(Get-SPSite -Identity $SiteCollectionUrl -ErrorAction Stop)
    }
    elseif ($WebApplicationUrl) {
        Write-Host "Scanning web application: $WebApplicationUrl" -ForegroundColor Cyan
        $sites = Get-SPSite -WebApplication $WebApplicationUrl -Limit All -ErrorAction Stop
    }
    else {
        Write-Host "Scanning all web applications..." -ForegroundColor Cyan
        $sites = Get-SPSite -Limit All -ErrorAction Stop
    }

    $totalSites = @($sites).Count
    Write-Host "Found $totalSites site collections to scan." -ForegroundColor White
    $siteCounter = 0

    foreach ($site in $sites) {
        $siteCounter++
        try {
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                continue
            }

            Write-Host "Processing site collection ($siteCounter/$totalSites): $($site.Url)" -ForegroundColor Cyan

            foreach ($web in $site.AllWebs) {
                try {
                    Write-Host "  Processing web: $($web.Url)" -ForegroundColor Gray

                    foreach ($list in $web.Lists) {
                        try {
                            # Skip hidden lists unless explicitly included
                            if ($list.Hidden -and -not $IncludeHiddenLists) {
                                continue
                            }

                            $lastModified = try { $list.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { "N/A" }

                            # Get migration concerns
                            $concerns = Get-ListMigrationConcerns `
                                -ItemCount $list.ItemCount `
                                -HasUniquePermissions $list.HasUniqueRoleAssignments `
                                -EnableVersioning $list.EnableVersioning `
                                -MajorVersionLimit $list.MajorVersionLimit `
                                -ForceCheckout $list.ForceCheckout `
                                -IsHidden $list.Hidden `
                                -LargeListThreshold $LargeListThreshold

                            $result = [PSCustomObject]@{
                                SiteCollectionUrl        = $site.Url
                                WebUrl                   = $web.Url
                                ListTitle                = $list.Title
                                ListUrl                  = $list.DefaultViewUrl
                                BaseType                 = $list.BaseType
                                BaseTemplate             = $list.BaseTemplate.ToString()
                                ItemCount                = $list.ItemCount
                                Hidden                   = $list.Hidden
                                EnableVersioning         = $list.EnableVersioning
                                MajorVersionLimit        = $list.MajorVersionLimit
                                EnableMinorVersions      = $list.EnableMinorVersions
                                EnableModeration         = $list.EnableModeration
                                ForceCheckout            = $list.ForceCheckout
                                HasUniqueRoleAssignments = $list.HasUniqueRoleAssignments
                                EnableAttachments        = $list.EnableAttachments
                                LastItemModifiedDate     = $lastModified
                                MigrationConcern         = $concerns.MigrationConcern
                                RiskLevel                = $concerns.RiskLevel
                                RecommendedAction        = $concerns.RecommendedAction
                                AssessmentDate           = $assessmentDate
                            }

                            $results += $result
                        }
                        catch {
                            Write-Warning "    Failed to process list: $($list.Title) - $($_.Exception.Message)"
                        }
                    }
                }
                catch {
                    Write-Warning "  Failed to process web: $($web.Url) - $($_.Exception.Message)"
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
    Write-Host "Error retrieving sites: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "list-library-inventory"
    Write-Host ""
    Write-Host "List and library inventory complete." -ForegroundColor Green
    Write-Host "Total lists/libraries processed: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No lists or libraries found or processed."
}

Write-Host ""
