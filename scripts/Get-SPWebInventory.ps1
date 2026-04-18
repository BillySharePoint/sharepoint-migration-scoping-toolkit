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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

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
    Write-ToolkitLog -Message "Found $totalSites site collections to scan for webs." -Level Info
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

                    $listCount = @($web.Lists | Where-Object { $_.BaseType -ne "DocumentLibrary" -and -not $_.Hidden }).Count
                    $libraryCount = @($web.Lists | Where-Object { $_.BaseType -eq "DocumentLibrary" -and -not $_.Hidden }).Count

                    $associatedOwnerGroup = if ($web.AssociatedOwnerGroup) { $web.AssociatedOwnerGroup.Name } else { "N/A" }
                    $associatedMemberGroup = if ($web.AssociatedMemberGroup) { $web.AssociatedMemberGroup.Name } else { "N/A" }
                    $associatedVisitorGroup = if ($web.AssociatedVisitorGroup) { $web.AssociatedVisitorGroup.Name } else { "N/A" }

                    $createdDate = try { $web.Created.ToString("yyyy-MM-dd") } catch { Write-Verbose "Could not retrieve CreatedDate for $($web.Url)"; "N/A" }
                    $lastModified = try { $web.LastItemModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { Write-Verbose "Could not retrieve LastItemModifiedDate for $($web.Url)"; "N/A" }

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
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "web-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "Web inventory complete." -Level Success
    Write-ToolkitLog -Message "Total webs processed: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No webs found or processed." -Level Warning
}

Write-Host ""
