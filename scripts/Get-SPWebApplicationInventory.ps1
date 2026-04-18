#Requires -Version 5.1

<#
.SYNOPSIS
    Collects SharePoint web application inventory for migration scoping.

.DESCRIPTION
    Gathers web application information including URL, application pool,
    authentication providers, content database count, and site collection count.
    Exports results to CSV.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.EXAMPLE
    .\Get-SPWebApplicationInventory.ps1 -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.

    Required permissions: SharePoint farm administrator access.
#>

param(
    [string]$OutputPath = ".\output"
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
Write-Host " Web Application Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $webApps = Get-SPWebApplication -ErrorAction Stop
    $webAppsIncludingCA = @($webApps) + @(Get-SPWebApplication -IncludeCentralAdministration -ErrorAction SilentlyContinue | Where-Object { $_.IsAdministrationWebApplication })

    Write-Host "Found $(@($webAppsIncludingCA).Count) web applications." -ForegroundColor White

    foreach ($webApp in $webAppsIncludingCA) {
        try {
            Write-Host "Processing web application: $($webApp.DisplayName)" -ForegroundColor Cyan

            $authProviders = @()
            foreach ($zone in $webApp.IisSettings.Keys) {
                $iisSettings = $webApp.IisSettings[$zone]
                if ($iisSettings.ClaimsAuthenticationProviders) {
                    foreach ($provider in $iisSettings.ClaimsAuthenticationProviders) {
                        $authProviders += $provider.DisplayName
                    }
                }
            }

            $authProviderString = if ($authProviders.Count -gt 0) { $authProviders -join "; " } else { "N/A" }

            $contentDbCount = @($webApp.ContentDatabases).Count
            $siteCollectionCount = @($webApp.Sites).Count
            $maxUploadSizeMB = $webApp.MaximumFileSize

            $result = [PSCustomObject]@{
                WebApplicationName   = $webApp.DisplayName
                WebApplicationUrl    = $webApp.Url
                ApplicationPool      = $webApp.ApplicationPool.DisplayName
                AuthenticationProvider = $authProviderString
                ContentDatabaseCount = $contentDbCount
                SiteCollectionCount  = $siteCollectionCount
                MaximumFileSizeMB    = $maxUploadSizeMB
                AssessmentDate       = $assessmentDate
            }

            $results += $result
        }
        catch {
            Write-Warning "Failed to process web application: $($webApp.DisplayName) - $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Host "Error retrieving web applications: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "web-application-inventory"
    Write-Host ""
    Write-Host "Web application inventory complete." -ForegroundColor Green
    Write-Host "Total web applications: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No web applications found."
}

Write-Host ""
