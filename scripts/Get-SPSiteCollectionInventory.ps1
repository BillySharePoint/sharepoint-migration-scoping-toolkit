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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

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
        Write-ToolkitLog -Message "Scanning web application: $WebApplicationUrl" -Level Progress
        $sites = Get-SPSite -WebApplication $WebApplicationUrl -Limit All -ErrorAction Stop
    }
    else {
        Write-ToolkitLog -Message "Scanning all web applications..." -Level Progress
        $sites = Get-SPSite -Limit All -ErrorAction Stop
    }

    $totalSites = @($sites).Count
    Write-ToolkitLog -Message "Found $totalSites site collections to process." -Level Info
    $counter = 0

    foreach ($site in $sites) {
        $counter++
        try {
            # Skip personal sites if not included
            if (-not $IncludePersonalSites -and $site.Url -match "/personal/") {
                Write-Verbose "Skipping personal site: $($site.Url)"
                continue
            }

            Write-ToolkitLog -Message "Processing site collection ($counter/$totalSites): $($site.Url)" -Level Progress

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

            $createdDate = try { $rootWeb.Created.ToString("yyyy-MM-dd") } catch { Write-Verbose "Could not retrieve CreatedDate for $($site.Url)"; "N/A" }
            $lastModified = try { $site.LastContentModifiedDate.ToString("yyyy-MM-dd HH:mm:ss") } catch { Write-Verbose "Could not retrieve LastContentModifiedDate for $($site.Url)"; "N/A" }

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
            Write-ToolkitLog -Message "Failed to process site collection: $($site.Url) - $($_.Exception.Message)" -Level Warning
        }
        finally {
            # Dispose of site object
            if ($site) { $site.Dispose() }
        }
    }
}
catch {
    Write-ToolkitLog -Message "Error retrieving site collections: $($_.Exception.Message)" -Level Error
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "site-collection-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "Site collection inventory complete." -Level Success
    Write-ToolkitLog -Message "Total site collections processed: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No site collections found or processed." -Level Warning
}

Write-Host ""
