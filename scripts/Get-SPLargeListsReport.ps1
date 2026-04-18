#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies SharePoint lists and libraries with item counts over a defined threshold.

.DESCRIPTION
    Scans all lists and libraries across specified scope and reports those exceeding
    the large list threshold. Includes risk assessment and recommended actions.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER LargeListThreshold
    Item count threshold to flag a list as large. Default is 5000.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.EXAMPLE
    .\Get-SPLargeListsReport.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.EXAMPLE
    .\Get-SPLargeListsReport.ps1 -LargeListThreshold 10000

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.
#>

param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\output",
    [int]$LargeListThreshold = 5000,
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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Large Lists Report" -ForegroundColor Cyan
Write-Host " Threshold: $LargeListThreshold items" -ForegroundColor Cyan
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
    Write-ToolkitLog -Message "Scanning $totalSites site collections for large lists..." -Level Info
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
                    foreach ($list in $web.Lists) {
                        try {
                            if ($list.ItemCount -ge $LargeListThreshold) {
                                $riskLevel = Get-ListRiskLevel -ItemCount $list.ItemCount
                                $lastModified = try { $list.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { Write-Verbose "Could not retrieve LastItemModifiedDate for list $($list.Title)"; "N/A" }

                                # Determine recommended action based on risk level
                                $recommendedAction = switch ($riskLevel) {
                                    "Critical" { "Requires detailed migration strategy; consider splitting content into multiple libraries" }
                                    "High" { "Test migration and consider restructuring; review metadata and folder structure" }
                                    "Medium" { "Review indexed columns and views; confirm whether all content needs to migrate" }
                                    default { "Review before migration" }
                                }

                                $result = [PSCustomObject]@{
                                    SiteCollectionUrl        = $site.Url
                                    WebUrl                   = $web.Url
                                    ListTitle                = $list.Title
                                    ListUrl                  = $list.DefaultViewUrl
                                    ItemCount                = $list.ItemCount
                                    BaseType                 = $list.BaseType
                                    HasUniqueRoleAssignments = $list.HasUniqueRoleAssignments
                                    EnableVersioning         = $list.EnableVersioning
                                    LastItemModifiedDate     = $lastModified
                                    RiskLevel                = $riskLevel
                                    RecommendedAction        = $recommendedAction
                                    AssessmentDate           = $assessmentDate
                                }

                                $results += $result

                                Write-ToolkitLog -Message "  [LARGE] $($list.Title) - $($list.ItemCount) items ($riskLevel)" -Level Warning
                            }
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "large-lists-report"
    Write-Host ""
    Write-ToolkitLog -Message "Large lists report complete." -Level Success
    Write-ToolkitLog -Message "Total large lists found: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No large lists found above the threshold of $LargeListThreshold items." -Level Warning
}

Write-Host ""
