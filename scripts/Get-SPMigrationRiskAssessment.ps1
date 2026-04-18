#Requires -Version 5.1

<#
.SYNOPSIS
    Generates a migration risk assessment based on collected SharePoint inventory data.

.DESCRIPTION
    Scans site collections, webs, lists, and libraries to produce a first-pass
    risk assessment for migration planning. Evaluates ownership, staleness,
    list size, permissions complexity, and other migration-relevant factors.

    The goal is not to be perfect. The goal is to give a useful first-pass view
    of migration complexity.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER StaleSiteThresholdDays
    Number of days to consider a site stale. Default is 365.

.PARAMETER LargeListThreshold
    Item count threshold for large list flagging. Default is 5000.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.EXAMPLE
    .\Get-SPMigrationRiskAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.
#>

param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\output",
    [int]$StaleSiteThresholdDays = 365,
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

# Initialize output folder
Initialize-OutputFolder -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()
$cutoffDate = (Get-Date).AddDays(-$StaleSiteThresholdDays)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Migration Risk Assessment" -ForegroundColor Cyan
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
    Write-Host "Assessing risk for $totalSites site collections..." -ForegroundColor White
    $siteCounter = 0

    foreach ($site in $sites) {
        $siteCounter++
        try {
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                continue
            }

            Write-Host "Processing site collection ($siteCounter/$totalSites): $($site.Url)" -ForegroundColor Cyan

            # --- Site Collection Level Risks ---

            # Missing owner check
            if (-not $site.Owner -or [string]::IsNullOrWhiteSpace($site.Owner.LoginName)) {
                $results += [PSCustomObject]@{
                    ObjectType       = "SiteCollection"
                    ObjectUrl        = $site.Url
                    ObjectTitle      = $site.RootWeb.Title
                    RiskCategory     = "Missing Owner"
                    RiskLevel        = "High"
                    RiskReason       = "Site has no clear owner"
                    RecommendedAction = "Confirm business owner before migration"
                    AssessmentDate   = $assessmentDate
                }
            }

            # Stale site check
            if ($site.LastContentModifiedDate -lt $cutoffDate) {
                $daysSinceModified = [math]::Floor(((Get-Date) - $site.LastContentModifiedDate).TotalDays)
                $riskLevel = Get-StaleSiteRiskLevel -DaysSinceLastModified $daysSinceModified

                $recommendedAction = switch ($riskLevel) {
                    "Critical" { "Archive candidate; business confirmation required before migration" }
                    "High"     { "Consider archive or exclusion from migration" }
                    "Medium"   { "Confirm whether site should migrate" }
                    default    { "Review before migration" }
                }

                $results += [PSCustomObject]@{
                    ObjectType       = "SiteCollection"
                    ObjectUrl        = $site.Url
                    ObjectTitle      = $site.RootWeb.Title
                    RiskCategory     = "Stale Site"
                    RiskLevel        = $riskLevel
                    RiskReason       = "No activity in $daysSinceModified days"
                    RecommendedAction = $recommendedAction
                    AssessmentDate   = $assessmentDate
                }
            }

            # Large storage check
            $storageUsedGB = [math]::Round($site.Usage.Storage / 1GB, 2)
            if ($storageUsedGB -ge 100) {
                $results += [PSCustomObject]@{
                    ObjectType       = "SiteCollection"
                    ObjectUrl        = $site.Url
                    ObjectTitle      = $site.RootWeb.Title
                    RiskCategory     = "Large Storage"
                    RiskLevel        = "High"
                    RiskReason       = "Site collection uses $storageUsedGB GB of storage"
                    RecommendedAction = "Confirm migration batching strategy; may require extended migration window"
                    AssessmentDate   = $assessmentDate
                }
            }
            elseif ($storageUsedGB -ge 50) {
                $results += [PSCustomObject]@{
                    ObjectType       = "SiteCollection"
                    ObjectUrl        = $site.Url
                    ObjectTitle      = $site.RootWeb.Title
                    RiskCategory     = "Large Storage"
                    RiskLevel        = "Medium"
                    RiskReason       = "Site collection uses $storageUsedGB GB of storage"
                    RecommendedAction = "Review migration batching strategy"
                    AssessmentDate   = $assessmentDate
                }
            }

            # --- Web and List Level Risks ---
            foreach ($web in $site.AllWebs) {
                try {
                    # Web unique permissions
                    if ($web.HasUniqueRoleAssignments) {
                        $roleAssignmentCount = $web.RoleAssignments.Count
                        $riskLevel = Get-PermissionRiskLevel -RoleAssignmentCount $roleAssignmentCount

                        $results += [PSCustomObject]@{
                            ObjectType       = "Web"
                            ObjectUrl        = $web.Url
                            ObjectTitle      = $web.Title
                            RiskCategory     = "Unique Permissions"
                            RiskLevel        = $riskLevel
                            RiskReason       = "Site has unique permissions with $roleAssignmentCount role assignments"
                            RecommendedAction = "Include in permission validation testing"
                            AssessmentDate   = $assessmentDate
                        }
                    }

                    # List/library risks
                    foreach ($list in $web.Lists) {
                        try {
                            if ($list.Hidden) { continue }

                            # Large list check
                            if ($list.ItemCount -ge $LargeListThreshold) {
                                $riskLevel = Get-ListRiskLevel -ItemCount $list.ItemCount
                                $objectType = if ($list.BaseType -eq "DocumentLibrary") { "Library" } else { "List" }

                                $recommendedAction = switch ($riskLevel) {
                                    "Critical" { "Requires detailed migration strategy" }
                                    "High"     { "Review migration batching strategy and run test migration" }
                                    "Medium"   { "Review views, indexing, and migration approach" }
                                    default    { "Review before migration" }
                                }

                                $results += [PSCustomObject]@{
                                    ObjectType       = $objectType
                                    ObjectUrl        = $list.DefaultViewUrl
                                    ObjectTitle      = $list.Title
                                    RiskCategory     = "Large $objectType"
                                    RiskLevel        = $riskLevel
                                    RiskReason       = "$objectType contains $($list.ItemCount) items"
                                    RecommendedAction = $recommendedAction
                                    AssessmentDate   = $assessmentDate
                                }
                            }

                            # List unique permissions
                            if ($list.HasUniqueRoleAssignments) {
                                $roleAssignmentCount = $list.RoleAssignments.Count
                                if ($roleAssignmentCount -ge 50) {
                                    $riskLevel = Get-PermissionRiskLevel -RoleAssignmentCount $roleAssignmentCount
                                    $objectType = if ($list.BaseType -eq "DocumentLibrary") { "Library" } else { "List" }

                                    $results += [PSCustomObject]@{
                                        ObjectType       = $objectType
                                        ObjectUrl        = $list.DefaultViewUrl
                                        ObjectTitle      = $list.Title
                                        RiskCategory     = "Complex Permissions"
                                        RiskLevel        = $riskLevel
                                        RiskReason       = "$objectType has $roleAssignmentCount role assignments"
                                        RecommendedAction = "Simplify permissions before migration where possible"
                                        AssessmentDate   = $assessmentDate
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Warning "    Failed to assess list: $($list.Title) - $($_.Exception.Message)"
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "migration-risk-assessment"

    # Display summary
    $lowCount = @($results | Where-Object { $_.RiskLevel -eq "Low" }).Count
    $mediumCount = @($results | Where-Object { $_.RiskLevel -eq "Medium" }).Count
    $highCount = @($results | Where-Object { $_.RiskLevel -eq "High" }).Count
    $criticalCount = @($results | Where-Object { $_.RiskLevel -eq "Critical" }).Count

    Write-Host ""
    Write-Host "Migration risk assessment complete." -ForegroundColor Green
    Write-Host "Total risk items found: $($results.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "Risk Summary:" -ForegroundColor White
    Write-Host "  Low:      $lowCount" -ForegroundColor Green
    Write-Host "  Medium:   $mediumCount" -ForegroundColor Yellow
    Write-Host "  High:     $highCount" -ForegroundColor DarkYellow
    Write-Host "  Critical: $criticalCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Host "No migration risks detected." -ForegroundColor Green
}

Write-Host ""
