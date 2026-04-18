#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies SharePoint workflow associations for migration scoping.

.DESCRIPTION
    Scans lists and libraries for workflow associations to identify potential
    workflow dependencies before migration. SharePoint Designer workflows and
    third-party workflows can be complicated to detect consistently; this
    provides best-effort detection.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the scan.

.EXAMPLE
    .\Get-SPWorkflowInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.
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
Write-Host " Workflow Inventory" -ForegroundColor Cyan
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
    Write-Host "Scanning $totalSites site collections for workflows..." -ForegroundColor White
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
                    # Check web-level workflow associations
                    if ($web.WorkflowAssociations -and $web.WorkflowAssociations.Count -gt 0) {
                        foreach ($wfAssoc in $web.WorkflowAssociations) {
                            $results += [PSCustomObject]@{
                                SiteCollectionUrl        = $site.Url
                                WebUrl                   = $web.Url
                                ListTitle                = "N/A (Web-level)"
                                WorkflowName             = $wfAssoc.Name
                                WorkflowAssociationCount = 1
                                WorkflowType             = "Web Association"
                                Enabled                  = $wfAssoc.Enabled
                                RiskLevel                = "High"
                                RecommendedAction        = "Review workflow logic before migration; rebuild using Power Automate where appropriate"
                                AssessmentDate           = $assessmentDate
                            }
                        }
                    }

                    # Check list-level workflow associations
                    foreach ($list in $web.Lists) {
                        try {
                            if ($list.WorkflowAssociations -and $list.WorkflowAssociations.Count -gt 0) {
                                foreach ($wfAssoc in $list.WorkflowAssociations) {
                                    $results += [PSCustomObject]@{
                                        SiteCollectionUrl        = $site.Url
                                        WebUrl                   = $web.Url
                                        ListTitle                = $list.Title
                                        WorkflowName             = $wfAssoc.Name
                                        WorkflowAssociationCount = 1
                                        WorkflowType             = "List Association"
                                        Enabled                  = $wfAssoc.Enabled
                                        RiskLevel                = "High"
                                        RecommendedAction        = "Review workflow logic; validate business process owner; include workflow testing in UAT"
                                        AssessmentDate           = $assessmentDate
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Warning "    Failed to check workflows on list: $($list.Title) - $($_.Exception.Message)"
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "workflow-inventory"
    Write-Host ""
    Write-Host "Workflow inventory complete." -ForegroundColor Green
    Write-Host "Total workflow associations found: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Host "No workflow associations found." -ForegroundColor Green
}

Write-Host ""
