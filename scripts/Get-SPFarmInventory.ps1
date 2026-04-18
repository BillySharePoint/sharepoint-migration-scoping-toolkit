#Requires -Version 5.1

<#
.SYNOPSIS
    Collects high-level SharePoint farm information for migration scoping.

.DESCRIPTION
    Gathers farm-level details including build version, servers, roles,
    and services running on each server. Exports results to CSV.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.EXAMPLE
    .\Get-SPFarmInventory.ps1 -OutputPath "C:\Reports"

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

# Initialize output folder and logging
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Farm Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $farm = Get-SPFarm -ErrorAction Stop
    Write-ToolkitLog -Message "Farm ID: $($farm.Id)" -Level Info
    Write-ToolkitLog -Message "Build Version: $($farm.BuildVersion)" -Level Info

    $configDb = $farm.Name

    # Get servers and services
    $servers = Get-SPServer -ErrorAction Stop

    foreach ($server in $servers) {
        try {
            Write-ToolkitLog -Message "Processing server: $($server.DisplayName)" -Level Progress

            $role = $server.Role

            # Get service instances on this server
            $serviceInstances = Get-SPServiceInstance -Server $server -ErrorAction SilentlyContinue

            if ($serviceInstances) {
                foreach ($svc in $serviceInstances) {
                    $results += [PSCustomObject]@{
                        FarmId             = $farm.Id
                        BuildVersion       = $farm.BuildVersion.ToString()
                        ConfigDatabaseName = $configDb
                        ServerName         = $server.DisplayName
                        ServerRole         = $role
                        ServiceName        = $svc.TypeName
                        ServiceStatus      = $svc.Status
                        AssessmentDate     = $assessmentDate
                    }
                }
            }
            else {
                # Record server even if no services found
                $results += [PSCustomObject]@{
                    FarmId             = $farm.Id
                    BuildVersion       = $farm.BuildVersion.ToString()
                    ConfigDatabaseName = $configDb
                    ServerName         = $server.DisplayName
                    ServerRole         = $role
                    ServiceName        = "N/A"
                    ServiceStatus      = "N/A"
                    AssessmentDate     = $assessmentDate
                }
            }
        }
        catch {
            Write-ToolkitLog -Message "Failed to process server: $($server.DisplayName) - $($_.Exception.Message)" -Level Warning
        }
    }
}
catch {
    Write-ToolkitLog -Message "Error retrieving farm information: $($_.Exception.Message)" -Level Error
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "farm-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "Farm inventory complete." -Level Success
    Write-ToolkitLog -Message "Total records: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No farm data collected." -Level Warning
}

Write-Host ""
