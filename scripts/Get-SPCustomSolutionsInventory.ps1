#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies SharePoint farm solutions and customizations for migration planning.

.DESCRIPTION
    Inventories farm solutions deployed in the SharePoint farm. Custom farm solutions
    may not be compatible with SharePoint Online and should be reviewed before migration.

.PARAMETER OutputPath
    Folder path where the CSV report will be saved. Default is .\output.

.EXAMPLE
    .\Get-SPCustomSolutionsInventory.ps1 -OutputPath "C:\Reports"

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
Write-Host " Custom Solutions Inventory" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $solutions = Get-SPSolution -ErrorAction Stop

    Write-ToolkitLog -Message "Found $(@($solutions).Count) farm solutions." -Level Info

    foreach ($solution in $solutions) {
        try {
            Write-ToolkitLog -Message "Processing solution: $($solution.DisplayName)" -Level Progress

            $riskLevel = "High"
            $recommendedAction = "Review customization for SharePoint Online compatibility; replace farm solutions with SPFx, Power Platform, or out-of-the-box alternatives"

            if (-not $solution.Deployed) {
                $riskLevel = "Medium"
                $recommendedAction = "Solution is not deployed; verify if still needed before migration"
            }

            $lastOperationTime = try { $solution.LastOperationEndTime.ToString("yyyy-MM-dd HH:mm:ss") } catch { Write-Verbose "Could not retrieve LastOperationEndTime for $($solution.DisplayName)"; "N/A" }

            $result = [PSCustomObject]@{
                SolutionName                  = $solution.DisplayName
                SolutionId                    = $solution.SolutionId
                Deployed                      = $solution.Deployed
                DeploymentState               = $solution.DeploymentState
                ContainsWebApplicationResource = $solution.ContainsWebApplicationResource
                LastOperationResult           = $solution.LastOperationResult
                LastOperationTime             = $lastOperationTime
                RiskLevel                     = $riskLevel
                RecommendedAction             = $recommendedAction
                AssessmentDate                = $assessmentDate
            }

            $results += $result
        }
        catch {
            Write-ToolkitLog -Message "Failed to process solution: $($solution.DisplayName) - $($_.Exception.Message)" -Level Warning
        }
    }
}
catch {
    Write-ToolkitLog -Message "Error retrieving solutions: $($_.Exception.Message)" -Level Error
    return
}

# Export results
if ($results.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $results -OutputPath $OutputPath -ReportName "custom-solutions-inventory"
    Write-Host ""
    Write-ToolkitLog -Message "Custom solutions inventory complete." -Level Success
    Write-ToolkitLog -Message "Total solutions found: $($results.Count)" -Level Info
    Write-ToolkitLog -Message "Report saved to: $reportPath" -Level Info
}
else {
    Write-ToolkitLog -Message "No farm solutions found." -Level Warning
}

Write-Host ""
