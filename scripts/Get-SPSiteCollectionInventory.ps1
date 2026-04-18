#Requires -Version 5.1

<#
.SYNOPSIS
    Generates an inventory of SharePoint site collections for migration scoping.

.DESCRIPTION
    Collects site collection information including URL, owners, storage usage,
    template, content database, and last modified date. Exports results to CSV.

    This is one of the most important scripts in the toolkit. The site collection
    inventory provides the foundation for migration wave planning and scoping.

.PARAMETER WebApplicationUrl
    Optional web application URL to limit the scan to a specific web application.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the inventory.

.EXAMPLE
    .\Get-SPSiteCollectionInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

.EXAMPLE
    .\Get-SPSiteCollectionInventory.ps1 -OutputPath "C:\Reports" -IncludePersonalSites

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.

    Required permissions: SharePoint farm administrator or site collection administrator access.
#>

param(
    [string]$WebApplicationUrl,
    [string]$OutputPath = ".\output",
    [switch]$IncludePersonalSites
)

# Import shared module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\SPMigrationScopingToolkit\SPMigrationScopingToolkit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Warning "Shared module not found at: $modulePath. Some helper functions may not be available."
}

# Initialize SharePoint snap-in
Initialize-SPSnapin

# Initialize output folder
Initialize-OutputFolder -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Site Collection Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get site collections
    if ($WebApplicationUrl) {
        Write-Host "Scanning web application: $WebApplicationUrl" -ForegroundColor Cyan
        $sites = Get-SPSite -WebApplication $WebApplicationUrl -Limit All -ErrorAction Stop
    }
    else {
        Write-Host "Scanning all web applications..." -ForegroundColor Cyan
        $sites = Get-SPSite -Limit All -ErrorAction Stop
    }

    $totalSites = @($sites).Count
    Write-Host "Found $totalSites site collections to process." -ForegroundColor White
    $counter = 0

    foreach ($site in $sites) {
        $counter++
        try {
            # Skip personal sites if not included
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                Write-Verbose "Skipping personal site: $($site.Url)"
                continue
            }

            Write-Host "Processing site collection ($counter/$totalSites): $($site.Url)" -ForegroundColor Cyan

            $storageUsedMB = [math]::Round($site.Usage.Storage / 1MB, 2)
            $storageQuotaMB = if ($site.Quota.StorageMaximumLevel -gt 0) {
                [math]::Round($site.Quota.StorageMaximumLevel / 1MB, 2)
            }
            else {
                0
            }

            $primaryOwner = if ($site.Owner) { $site.Owner.LoginName } else { "N/A" }
            $secondaryOwner = if ($site.SecondaryContact) { $site.SecondaryContact.LoginName } else { "N/A" }
            $ownerEmail = if ($site.Owner) { $site.Owner.Email } else { "N/A" }

            $rootWeb = $site.RootWeb
            $rootWebTitle = if ($rootWeb) { $rootWeb.Title } else { "N/A" }
            $rootWebTemplate = if ($rootWeb) { "$($rootWeb.WebTemplate)#$($rootWeb.Configuration)" } else { "N/A" }

            $createdDate = try { $rootWeb.Created.ToString("yyyy-MM-dd") } catch { "N/A" }
            $lastModified = try { $site.LastContentModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { "N/A" }

            $result = [PSCustomObject]@{
                SiteCollectionUrl       = $site.Url
                Title                   = $rootWebTitle
                PrimaryOwner            = $primaryOwner
                SecondaryOwner          = $secondaryOwner
                OwnerEmail              = $ownerEmail
                ContentDatabase         = $site.ContentDatabase.Name
                Template                = $rootWebTemplate
                CompatibilityLevel      = $site.CompatibilityLevel
                StorageUsedMB           = $storageUsedMB
                StorageQuotaMB          = $storageQuotaMB
                LastContentModifiedDate = $lastModified
                CreatedDate             = $createdDate
                LockState               = $site.LockState
                IsReadOnly              = $site.ReadOnly
                WebCount                = $site.AllWebs.Count
                RootWebTitle            = $rootWebTitle
                RootWebTemplate         = $rootWebTemplate
                AssessmentDate          = $assessmentDate
            }

            $results += $result

            # Dispose of root web
            if ($rootWeb) { $rootWeb.Dispose() }
        }
        catch {
            Write-Warning "Failed to process site collection: $($site.Url) - $($_.Exception.Message)"
        }
        finally {
            # Dispose of site object
            if ($site) { $site.Dispose() }
        }
    }
}
catch {
    Write-Host "Error retrieving site collections: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "site-collection-inventory"
    Write-Host ""
    Write-Host "Site collection inventory complete." -ForegroundColor Green
    Write-Host "Total site collections processed: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No site collections found or processed."
}

Write-Host ""
