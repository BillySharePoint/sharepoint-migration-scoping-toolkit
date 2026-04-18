#Requires -Version 5.1

<#
.SYNOPSIS
    Generates an inventory of SharePoint webs (subsites) for migration scoping.

.DESCRIPTION
    Collects web/subsite information including URL, title, template, language,
    permissions, and list/library counts. Exports results to CSV.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan.

.PARAMETER SiteCollectionUrl
    Optional site collection URL to limit the scan to a single site collection.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the inventory.

.EXAMPLE
    .\Get-SPWebInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.EXAMPLE
    .\Get-SPWebInventory.ps1 -SiteCollectionUrl "https://sharepoint.contoso.com/sites/hr" -OutputPath "C:\Reports"

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
Write-Host " Web / Subsite Inventory" -ForegroundColor Cyan
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
    Write-Host "Found $totalSites site collections to scan for webs." -ForegroundColor White
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

                    $listCount = @($web.Lists | Where-Object { $_.BaseType -ne "DocumentLibrary" -and -not $_.Hidden }).Count
                    $libraryCount = @($web.Lists | Where-Object { $_.BaseType -eq "DocumentLibrary" -and -not $_.Hidden }).Count

                    $associatedOwnerGroup = if ($web.AssociatedOwnerGroup) { $web.AssociatedOwnerGroup.Name } else { "N/A" }
                    $associatedMemberGroup = if ($web.AssociatedMemberGroup) { $web.AssociatedMemberGroup.Name } else { "N/A" }
                    $associatedVisitorGroup = if ($web.AssociatedVisitorGroup) { $web.AssociatedVisitorGroup.Name } else { "N/A" }

                    $createdDate = try { $web.Created.ToString("yyyy-MM-dd") } catch { "N/A" }
                    $lastModified = try { $web.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { "N/A" }

                    $result = [PSCustomObject]@{
                        SiteCollectionUrl      = $site.Url
                        WebUrl                 = $web.Url
                        WebTitle               = $web.Title
                        Description            = ($web.Description -replace "`r`n|`n|`r", " ")
                        Template               = "$($web.WebTemplate)#$($web.Configuration)"
                        Language               = $web.Language
                        CreatedDate            = $createdDate
                        LastItemModifiedDate   = $lastModified
                        HasUniquePermissions   = $web.HasUniqueRoleAssignments
                        AssociatedOwnerGroup   = $associatedOwnerGroup
                        AssociatedMemberGroup  = $associatedMemberGroup
                        AssociatedVisitorGroup = $associatedVisitorGroup
                        ListCount              = $listCount
                        LibraryCount           = $libraryCount
                        AssessmentDate         = $assessmentDate
                    }

                    $results += $result
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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "web-inventory"
    Write-Host ""
    Write-Host "Web inventory complete." -ForegroundColor Green
    Write-Host "Total webs processed: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No webs found or processed."
}

Write-Host ""
