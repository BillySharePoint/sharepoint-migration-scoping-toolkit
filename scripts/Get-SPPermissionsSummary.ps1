#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies SharePoint sites, lists, and libraries with unique permissions.

.DESCRIPTION
    Scans webs and lists/libraries to identify objects with unique (broken inheritance)
    permissions. Complex permissions can increase migration complexity and post-migration
    validation effort.

    The first version focuses on summary-level permissions, not a full user-by-user
    permission matrix. Does not attempt item-level permissions.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.EXAMPLE
    .\Get-SPPermissionsSummary.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content or permissions.
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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Permissions Summary" -ForegroundColor Cyan
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
    Write-ToolkitLog -Message "Scanning $totalSites site collections for unique permissions..." -Level Info
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
                    # Check web-level permissions
                    if ($web.HasUniqueRoleAssignments) {
                        $roleAssignmentCount = $web.RoleAssignments.Count
                        $groupCount = @($web.RoleAssignments | Where-Object {
                                $_.Member.GetType().Name -eq "SPGroup"
                            }).Count
                        $directUserCount = $roleAssignmentCount - $groupCount

                        $riskLevel = Get-PermissionRiskLevel -RoleAssignmentCount $roleAssignmentCount

                        $recommendedAction = switch ($riskLevel) {
                            "Critical" { "Simplify permissions before migration; convert direct assignments to groups" }
                            "High" { "Review unique permission structure before migration; reduce direct user permissions" }
                            "Medium" { "Include in permission validation testing; confirm site owners and access groups" }
                            default { "Review before migration" }
                        }

                        $results += [PSCustomObject]@{
                            SiteCollectionUrl         = $site.Url
                            WebUrl                    = $web.Url
                            ObjectType                = "Web"
                            ObjectTitle               = $web.Title
                            ObjectUrl                 = $web.Url
                            HasUniquePermissions      = $true
                            RoleAssignmentCount       = $roleAssignmentCount
                            GroupAssignmentCount      = $groupCount
                            DirectUserAssignmentCount = $directUserCount
                            RiskLevel                 = $riskLevel
                            RecommendedAction         = $recommendedAction
                            AssessmentDate            = $assessmentDate
                        }

                        Write-ToolkitLog -Message "  [UNIQUE PERMS] Web: $($web.Title) ($roleAssignmentCount assignments)" -Level Warning
                    }

                    # Check list/library-level permissions
                    foreach ($list in $web.Lists) {
                        try {
                            if ($list.HasUniqueRoleAssignments) {
                                $roleAssignmentCount = $list.RoleAssignments.Count
                                $groupCount = @($list.RoleAssignments | Where-Object {
                                        $_.Member.GetType().Name -eq "SPGroup"
                                    }).Count
                                $directUserCount = $roleAssignmentCount - $groupCount

                                $objectType = if ($list.BaseType -eq "DocumentLibrary") { "Library" } else { "List" }

                                $riskLevel = Get-PermissionRiskLevel -RoleAssignmentCount $roleAssignmentCount

                                $recommendedAction = switch ($riskLevel) {
                                    "Critical" { "Simplify permissions before migration; convert direct assignments to groups" }
                                    "High" { "Review unique permission structure before migration; reduce direct user permissions" }
                                    "Medium" { "Include in permission validation testing" }
                                    default { "Review before migration" }
                                }

                                $results += [PSCustomObject]@{
                                    SiteCollectionUrl         = $site.Url
                                    WebUrl                    = $web.Url
                                    ObjectType                = $objectType
                                    ObjectTitle               = $list.Title
                                    ObjectUrl                 = $list.DefaultViewUrl
                                    HasUniquePermissions      = $true
                                    RoleAssignmentCount       = $roleAssignmentCount
                                    GroupAssignmentCount      = $groupCount
                                    DirectUserAssignmentCount = $directUserCount
                                    RiskLevel                 = $riskLevel
                                    RecommendedAction         = $recommendedAction
                                    AssessmentDate            = $assessmentDate
                                }
                            }
                        }
                        catch {
                            Write-ToolkitLog -Message "    Failed to check permissions on list: $($list.Title) - $($_.Exception.Message)" -Level Warning
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "permissions-summary"
    Write-Host ""
    Write-ToolkitLog -Message "Permissions summary complete." -Level Success
    Write-ToolkitLog -Message "Total objects with unique permissions: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No objects with unique permissions found." -Level Warning
}

Write-Host ""
