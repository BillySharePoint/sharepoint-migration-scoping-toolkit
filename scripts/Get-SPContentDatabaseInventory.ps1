#Requires -Version 5.1

<#
.SYNOPSIS
    Collects SharePoint content database inventory for migration scoping.

.DESCRIPTION
    Gathers content database information including database name, server,
    site count, capacity settings, and status. Exports results to CSV.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.EXAMPLE
    .\Get-SPContentDatabaseInventory.ps1 -OutputPath "C:\Reports"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content.

    Database size may require SQL access. If not available, the field will be marked as NotCollected.

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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Content Database Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $contentDatabases = Get-SPContentDatabase -ErrorAction Stop

    Write-ToolkitLog -Message "Found $(@($contentDatabases).Count) content databases." -Level Info

    foreach ($db in $contentDatabases) {
        try {
            Write-ToolkitLog -Message "Processing content database: $($db.Name)" -Level Progress

            # Attempt to get database size
            $dbSizeMB = "NotCollected"
            try {
                if ($db.DiskSizeRequired) {
                    $dbSizeMB = [math]::Round($db.DiskSizeRequired / 1MB, 2)
                }
            }
            catch {
                Write-ToolkitLog -Message "Could not retrieve disk size for database: $($db.Name) - $($_.Exception.Message)" -Level Warning
                $dbSizeMB = "NotCollected"
            }

            $result = [PSCustomObject]@{
                ContentDatabaseName = $db.Name
                WebApplicationUrl   = $db.WebApplication.Url
                DatabaseServer      = $db.Server
                CurrentSiteCount    = $db.CurrentSiteCount
                WarningSiteCount    = $db.WarningSiteCount
                MaximumSiteCount    = $db.MaximumSiteCount
                DatabaseSizeMB      = $dbSizeMB
                Status              = $db.Status
                AssessmentDate      = $assessmentDate
            }

            $results += $result
        }
        catch {
            Write-ToolkitLog -Message "Failed to process content database: $($db.Name) - $($_.Exception.Message)" -Level Warning
        }
    }
}
catch {
    Write-ToolkitLog -Message "Error retrieving content databases: $($_.Exception.Message)" -Level Error
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "content-database-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "Content database inventory complete." -Level Success
    Write-ToolkitLog -Message "Total content databases: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No content databases found." -Level Warning
}

Write-Host ""
