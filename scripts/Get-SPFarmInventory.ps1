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

# Initialize output folder
Initialize-OutputFolder -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Farm Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $farm = Get-SPFarm -ErrorAction Stop
    Write-Host "Farm ID: $($farm.Id)" -ForegroundColor White
    Write-Host "Build Version: $($farm.BuildVersion)" -ForegroundColor White

    $configDb = $farm.Name

    # Get servers and services
    $servers = Get-SPServer -ErrorAction Stop

    foreach ($server in $servers) {
        try {
            Write-Host "Processing server: $($server.DisplayName)" -ForegroundColor Cyan

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
            Write-Warning "Failed to process server: $($server.DisplayName) - $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Host "Error retrieving farm information: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "farm-inventory"
    Write-Host ""
    Write-Host "Farm inventory complete." -ForegroundColor Green
    Write-Host "Total records: $($results.Count)" -ForegroundColor White
    Write-Host "Report saved to: $reportPath" -ForegroundColor White
}
else {
    Write-Warning "No farm data collected."
}

Write-Host ""
