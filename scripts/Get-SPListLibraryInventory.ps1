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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

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
        Write-ToolkitLog -Message "Scanning site collection: $SiteCollectionUrl" -Level Progress
        $sites = @(Get-SPSite -Identity $SiteCollectionUrl -ErrorAction Stop)
    }
    elseif ($WebApplicationUrl) {
        Write-ToolkitLog -Message "Scanning web application: $WebApplicationUrl" -Level Progress
        $sites = Get-SPSite -WebApplication $WebApplicationUrl -Limit All -ErrorAction Stop
    }
    else {
        Write-ToolkitLog -Message "Scanning all web applications..." -Level Progress
        $sites = Get-SPSite -Limit All -ErrorAction Stop
    }

    $totalSites = @($sites).Count
    Write-ToolkitLog -Message "Found $totalSites site collections to scan." -Level Info
    $siteCounter = 0

    foreach ($site in $sites) {
        $siteCounter++
        try {
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                continue
            }

            Write-ToolkitLog -Message "Processing site collection ($siteCounter/$totalSites): $($site.Url)" -Level Progress

            foreach ($web in $site.AllWebs) {
                try {
                    Write-Host "  Processing web: $($web.Url)" -ForegroundColor Gray

                    foreach ($list in $web.Lists) {
                        try {
                            # Skip hidden lists unless explicitly included
                            if ($list.Hidden -and -not $IncludeHiddenLists) {
                                continue
                            }

                            $lastModified = try { $list.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { Write-Verbose "Could not retrieve LastItemModifiedDate for list $($list.Title)"; "N/A" }

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
                            Write-ToolkitLog -Message "    Failed to process list: $($list.Title) - $($_.Exception.Message)" -Level Warning
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "list-library-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "List and library inventory complete." -Level Success
    Write-ToolkitLog -Message "Total lists/libraries processed: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No lists or libraries found or processed." -Level Warning
}

Write-Host ""
