#Requires -Version 5.1

<#
.SYNOPSIS
    Main runner script for the SharePoint Migration Scoping Toolkit.

.DESCRIPTION
    Runs the full SharePoint migration scoping assessment by calling individual
    inventory and reporting scripts. Produces CSV reports for migration planning.

    This is the primary entry point for running a complete assessment.

.PARAMETER ConfigPath
    Path to a JSON configuration file. Values in the config file are overridden
    by explicitly specified parameters.

.PARAMETER WebApplicationUrl
    Web application URL to scope the assessment.

.PARAMETER OutputPath
    Folder path where all CSV reports will be saved. Default is .\output.

.PARAMETER SkipPermissions
    Skip the permissions summary scan.

.PARAMETER SkipWorkflows
    Skip the workflow inventory scan.

.PARAMETER SkipCustomSolutions
    Skip the custom solutions inventory scan.

.PARAMETER IncludePersonalSites
    Include personal sites (My Sites) in the assessment.

.PARAMETER IncludeSubsites
    Include subsites in the stale sites analysis.

.PARAMETER StaleSiteThresholdDays
    Number of days to consider a site stale. Default is 365.

.PARAMETER LargeListThreshold
    Item count threshold for large list flagging. Default is 5000.

.EXAMPLE
    .\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports\SPMigrationScope"

.EXAMPLE
    .\Start-SPMigrationScopingAssessment.ps1 -ConfigPath "..\config\sample-config.json"

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content, permissions, or configuration.

    Required permissions: SharePoint farm administrator or appropriate site collection access.
#>

param(
    [string]$ConfigPath,
    [string]$WebApplicationUrl,
    [string]$OutputPath = ".\output",
    [switch]$SkipPermissions,
    [switch]$SkipWorkflows,
    [switch]$SkipCustomSolutions,
    [switch]$IncludePersonalSites,
    [switch]$IncludeSubsites,
    [int]$StaleSiteThresholdDays = 365,
    [int]$LargeListThreshold = 5000
)

$ErrorActionPreference = "Continue"
$scriptStartTime = Get-Date

# Import shared module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\SPMigrationScopingToolkit\SPMigrationScopingToolkit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Error "Shared module not found at: $modulePath. Please ensure the repository structure is intact."
    return
}

# ============================================================
# Banner
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SharePoint Migration Scoping Toolkit" -ForegroundColor Cyan
Write-Host "  Full Assessment Runner" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Initialize logging early (before other init steps)
Initialize-ToolkitLog -OutputPath $OutputPath

# ============================================================
# Load Configuration
# ============================================================
$config = $null
if ($ConfigPath) {
    Write-ToolkitLog -Message "Loading configuration from: $ConfigPath" -Level Info
    try {
        $config = Import-ToolkitConfig -ConfigPath $ConfigPath
    }
    catch {
        Write-ToolkitLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level Error
        return
    }
}

# Merge config with parameters
$defaults = @{
    OutputPath              = ".\output"
    StaleSiteThresholdDays  = 365
    LargeListThreshold      = 5000
    IncludePersonalSites    = $false
    IncludeSubsites         = $false
}

$settings = Merge-ConfigWithParameters -Config $config -BoundParameters $PSBoundParameters -Defaults $defaults

# Apply merged settings
$OutputPath = $settings["OutputPath"]
if ($settings.ContainsKey("WebApplicationUrl") -and -not $PSBoundParameters.ContainsKey("WebApplicationUrl")) {
    $WebApplicationUrl = $settings["WebApplicationUrl"]
}
if ($settings.ContainsKey("StaleSiteThresholdDays")) {
    $StaleSiteThresholdDays = [int]$settings["StaleSiteThresholdDays"]
}
if ($settings.ContainsKey("LargeListThreshold")) {
    $LargeListThreshold = [int]$settings["LargeListThreshold"]
}

# ============================================================
# Validate Environment
# ============================================================
Write-ToolkitLog -Message "Validating SharePoint environment..." -Level Info
try {
    Initialize-SPSnapin
}
catch {
    Write-ToolkitLog -Message "Failed to initialize SharePoint snap-in: $($_.Exception.Message)" -Level Error
    return
}

Write-ToolkitLog -Message "Initializing output folder..." -Level Info
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

Write-Host ""
Write-ToolkitLog -Message "Assessment Settings:" -Level Info
Write-Host "  Output Path:              $OutputPath" -ForegroundColor Gray
Write-Host "  Web Application:          $(if ($WebApplicationUrl) { $WebApplicationUrl } else { 'All' })" -ForegroundColor Gray
Write-Host "  Stale Site Threshold:     $StaleSiteThresholdDays days" -ForegroundColor Gray
Write-Host "  Large List Threshold:     $LargeListThreshold items" -ForegroundColor Gray
Write-Host "  Include Personal Sites:   $IncludePersonalSites" -ForegroundColor Gray
Write-Host "  Include Subsites (stale): $IncludeSubsites" -ForegroundColor Gray
Write-Host "  Skip Permissions:         $SkipPermissions" -ForegroundColor Gray
Write-Host "  Skip Workflows:           $SkipWorkflows" -ForegroundColor Gray
Write-Host "  Skip Custom Solutions:    $SkipCustomSolutions" -ForegroundColor Gray
Write-Host ""

# ============================================================
# Build Script Arguments
# ============================================================
$commonArgs = @{
    OutputPath = $OutputPath
}

if ($WebApplicationUrl) {
    $commonArgs["WebApplicationUrl"] = $WebApplicationUrl
}

if ($IncludePersonalSites) {
    $commonArgs["IncludePersonalSites"] = $true
}

$scriptsDir = $PSScriptRoot
$completedReports = @()
$failedReports = @()

# ============================================================
# Helper Function - Run Script
# ============================================================
function Invoke-AssessmentScript {
    param(
        [string]$ScriptName,
        [string]$DisplayName,
        [hashtable]$Arguments
    )

    $scriptPath = Join-Path $scriptsDir $ScriptName

    if (-not (Test-Path $scriptPath)) {
        Write-ToolkitLog -Message "Script not found: $scriptPath - Skipping $DisplayName" -Level Warning
        $script:failedReports += $DisplayName
        return
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  Running: $DisplayName" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

    try {
        & $scriptPath @Arguments
        $script:completedReports += $DisplayName
    }
    catch {
        Write-ToolkitLog -Message "Failed to run $DisplayName : $($_.Exception.Message)" -Level Warning
        $script:failedReports += $DisplayName
    }
}

# ============================================================
# Run Assessment Scripts
# ============================================================

# 1. Site Collection Inventory
$args1 = $commonArgs.Clone()
Invoke-AssessmentScript -ScriptName "Get-SPSiteCollectionInventory.ps1" -DisplayName "Site Collection Inventory" -Arguments $args1

# 2. Web/Subsite Inventory
$args2 = $commonArgs.Clone()
Invoke-AssessmentScript -ScriptName "Get-SPWebInventory.ps1" -DisplayName "Web / Subsite Inventory" -Arguments $args2

# 3. List & Library Inventory
$args3 = $commonArgs.Clone()
$args3["LargeListThreshold"] = $LargeListThreshold
Invoke-AssessmentScript -ScriptName "Get-SPListLibraryInventory.ps1" -DisplayName "List & Library Inventory" -Arguments $args3

# 4. Large Lists Report
$args4 = $commonArgs.Clone()
$args4["LargeListThreshold"] = $LargeListThreshold
Invoke-AssessmentScript -ScriptName "Get-SPLargeListsReport.ps1" -DisplayName "Large Lists Report" -Arguments $args4

# 5. Permissions Summary
if (-not $SkipPermissions) {
    $args5 = $commonArgs.Clone()
    Invoke-AssessmentScript -ScriptName "Get-SPPermissionsSummary.ps1" -DisplayName "Permissions Summary" -Arguments $args5
}
else {
    Write-ToolkitLog -Message "`nSkipping Permissions Summary (SkipPermissions flag set)." -Level Info
}

# 6. Stale Sites Report
$args6 = $commonArgs.Clone()
$args6["StaleSiteThresholdDays"] = $StaleSiteThresholdDays
if ($IncludeSubsites) { $args6["IncludeSubsites"] = $true }
Invoke-AssessmentScript -ScriptName "Get-SPStaleSitesReport.ps1" -DisplayName "Stale Sites Report" -Arguments $args6

# 7. Migration Risk Assessment
$args7 = $commonArgs.Clone()
$args7["StaleSiteThresholdDays"] = $StaleSiteThresholdDays
$args7["LargeListThreshold"] = $LargeListThreshold
Invoke-AssessmentScript -ScriptName "Get-SPMigrationRiskAssessment.ps1" -DisplayName "Migration Risk Assessment" -Arguments $args7

# 8. Farm Inventory (Phase 2 - run if available)
Invoke-AssessmentScript -ScriptName "Get-SPFarmInventory.ps1" -DisplayName "Farm Inventory" -Arguments @{ OutputPath = $OutputPath }

# 9. Web Application Inventory (Phase 2 - run if available)
Invoke-AssessmentScript -ScriptName "Get-SPWebApplicationInventory.ps1" -DisplayName "Web Application Inventory" -Arguments @{ OutputPath = $OutputPath }

# 10. Content Database Inventory (Phase 2 - run if available)
Invoke-AssessmentScript -ScriptName "Get-SPContentDatabaseInventory.ps1" -DisplayName "Content Database Inventory" -Arguments @{ OutputPath = $OutputPath }

# 11. Workflow Inventory (Phase 2)
if (-not $SkipWorkflows) {
    $args11 = $commonArgs.Clone()
    Invoke-AssessmentScript -ScriptName "Get-SPWorkflowInventory.ps1" -DisplayName "Workflow Inventory" -Arguments $args11
}
else {
    Write-ToolkitLog -Message "`nSkipping Workflow Inventory (SkipWorkflows flag set)." -Level Info
}

# 12. Custom Solutions Inventory (Phase 2)
if (-not $SkipCustomSolutions) {
    Invoke-AssessmentScript -ScriptName "Get-SPCustomSolutionsInventory.ps1" -DisplayName "Custom Solutions Inventory" -Arguments @{ OutputPath = $OutputPath }
}
else {
    Write-ToolkitLog -Message "`nSkipping Custom Solutions Inventory (SkipCustomSolutions flag set)." -Level Info
}

# 13. Feature Inventory (Phase 2 - run if available)
$args13 = $commonArgs.Clone()
Invoke-AssessmentScript -ScriptName "Get-SPFeatureInventory.ps1" -DisplayName "Feature Inventory" -Arguments $args13

# 14. Summary Report
Invoke-AssessmentScript -ScriptName "Export-SPMigrationSummaryReport.ps1" -DisplayName "Migration Summary Report" -Arguments @{ OutputPath = $OutputPath }

# ============================================================
# Final Summary
# ============================================================
$scriptEndTime = Get-Date
$duration = $scriptEndTime - $scriptStartTime

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Assessment Complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-ToolkitLog -Message "Duration: $($duration.ToString('hh\:mm\:ss'))" -Level Info
Write-ToolkitLog -Message "Output folder: $OutputPath" -Level Info
Write-ToolkitLog -Message "Reports completed: $($completedReports.Count)" -Level Success

if ($failedReports.Count -gt 0) {
    Write-ToolkitLog -Message "Reports failed: $($failedReports.Count)" -Level Warning
    foreach ($failed in $failedReports) {
        Write-Host "    - $failed" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  Output files:" -ForegroundColor White
Get-ChildItem -Path $OutputPath -Filter "*.csv" | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Name)" -ForegroundColor Gray
}

Write-Host ""
Write-ToolkitLog -Message "Assessment reports are ready for review." -Level Success
Write-Host ""
