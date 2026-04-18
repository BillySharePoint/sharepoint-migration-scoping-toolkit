#Requires -Version 5.1

<#
.SYNOPSIS
    Generates a high-level migration summary report from assessment output files.

.DESCRIPTION
    Reads CSV output files from the SharePoint Migration Scoping Toolkit and
    creates a summary report with key metrics for stakeholder review.

    Optionally generates an Excel workbook (if ImportExcel module is installed)
    or an HTML dashboard.

.PARAMETER OutputPath
    Folder path where CSV reports were saved and where the summary will be created.
    Default is .\output.

.PARAMETER ExportExcel
    Generate an Excel workbook with multiple tabs (requires ImportExcel module).

.PARAMETER ExportHtml
    Generate an HTML summary dashboard.

.EXAMPLE
    .\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports"

.EXAMPLE
    .\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports" -ExportExcel -ExportHtml

.NOTES
    This script is intended for SharePoint on-premises discovery and reporting only.
    Run this after completing the full assessment to get consolidated metrics.
#>

param(
    [string]$OutputPath = ".\output",
    [switch]$ExportExcel,
    [switch]$ExportHtml
)

# Import shared module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\SPMigrationScopingToolkit\SPMigrationScopingToolkit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Warning "Shared module not found at: $modulePath"
}

# Initialize output folder
Initialize-OutputFolder -OutputPath $OutputPath
Initialize-ToolkitLog -OutputPath $OutputPath

$assessmentDate = Get-AssessmentDate
$summaryResults = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Migration Summary Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Helper: Find latest CSV matching a pattern
# ============================================================
function Get-LatestReport {
    param([string]$Pattern)
    $files = Get-ChildItem -Path $OutputPath -Filter "$Pattern*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($files) {
        return $files[0].FullName
    }
    return $null
}

function Add-Metric {
    param([string]$Metric, $Value)
    $script:summaryResults += [PSCustomObject]@{
        Metric         = $Metric
        Value          = $Value
        AssessmentDate = $assessmentDate
    }
    Write-Host "  $Metric : $Value" -ForegroundColor White
}

# ============================================================
# Collect Summary Metrics
# ============================================================

Write-ToolkitLog -Message "Collecting summary metrics from output files..." -Level Progress
Write-Host ""

# --- Web Application Inventory ---
$waFile = Get-LatestReport -Pattern "web-application-inventory"
if ($waFile) {
    $waData = Import-Csv $waFile
    Add-Metric -Metric "Total Web Applications" -Value $waData.Count
}
else {
    Add-Metric -Metric "Total Web Applications" -Value "Report not found"
}

# --- Content Database Inventory ---
$cdbFile = Get-LatestReport -Pattern "content-database-inventory"
if ($cdbFile) {
    $cdbData = Import-Csv $cdbFile
    Add-Metric -Metric "Total Content Databases" -Value $cdbData.Count
}
else {
    Add-Metric -Metric "Total Content Databases" -Value "Report not found"
}

# --- Site Collection Inventory ---
$scFile = Get-LatestReport -Pattern "site-collection-inventory"
if ($scFile) {
    $scData = Import-Csv $scFile
    Add-Metric -Metric "Total Site Collections" -Value $scData.Count

    $totalStorageGB = ($scData | ForEach-Object {
        if ($_.StorageUsedMB -and $_.StorageUsedMB -ne "N/A") { [double]$_.StorageUsedMB } else { 0 }
    } | Measure-Object -Sum).Sum / 1024
    Add-Metric -Metric "Total Storage Used (GB)" -Value ([math]::Round($totalStorageGB, 2))
}
else {
    Add-Metric -Metric "Total Site Collections" -Value "Report not found"
}

# --- Web Inventory ---
$webFile = Get-LatestReport -Pattern "web-inventory"
if ($webFile) {
    $webData = Import-Csv $webFile
    Add-Metric -Metric "Total Webs / Subsites" -Value $webData.Count
}
else {
    Add-Metric -Metric "Total Webs / Subsites" -Value "Report not found"
}

# --- List & Library Inventory ---
$llFile = Get-LatestReport -Pattern "list-library-inventory"
if ($llFile) {
    $llData = Import-Csv $llFile
    Add-Metric -Metric "Total Lists and Libraries" -Value $llData.Count
}
else {
    Add-Metric -Metric "Total Lists and Libraries" -Value "Report not found"
}

# --- Large Lists Report ---
$lgFile = Get-LatestReport -Pattern "large-lists-report"
if ($lgFile) {
    $lgData = Import-Csv $lgFile
    Add-Metric -Metric "Total Large Lists / Libraries" -Value $lgData.Count
}
else {
    Add-Metric -Metric "Total Large Lists / Libraries" -Value "Report not found"
}

# --- Stale Sites Report ---
$ssFile = Get-LatestReport -Pattern "stale-sites-report"
if ($ssFile) {
    $ssData = Import-Csv $ssFile
    Add-Metric -Metric "Total Stale Sites" -Value $ssData.Count
}
else {
    Add-Metric -Metric "Total Stale Sites" -Value "Report not found"
}

# --- Permissions Summary ---
$psFile = Get-LatestReport -Pattern "permissions-summary"
if ($psFile) {
    $psData = Import-Csv $psFile
    Add-Metric -Metric "Total Objects with Unique Permissions" -Value $psData.Count
}
else {
    Add-Metric -Metric "Total Objects with Unique Permissions" -Value "Report not found"
}

# --- Workflow Inventory ---
$wfFile = Get-LatestReport -Pattern "workflow-inventory"
if ($wfFile) {
    $wfData = Import-Csv $wfFile
    Add-Metric -Metric "Total Workflow Associations" -Value $wfData.Count
}
else {
    Add-Metric -Metric "Total Workflow Associations" -Value "Report not found"
}

# --- Custom Solutions Inventory ---
$csFile = Get-LatestReport -Pattern "custom-solutions-inventory"
if ($csFile) {
    $csData = Import-Csv $csFile
    Add-Metric -Metric "Total Custom Farm Solutions" -Value $csData.Count
}
else {
    Add-Metric -Metric "Total Custom Farm Solutions" -Value "Report not found"
}

# --- Risk Assessment ---
$raFile = Get-LatestReport -Pattern "migration-risk-assessment"
if ($raFile) {
    $raData = Import-Csv $raFile
    $lowCount = @($raData | Where-Object { $_.RiskLevel -eq "Low" }).Count
    $mediumCount = @($raData | Where-Object { $_.RiskLevel -eq "Medium" }).Count
    $highCount = @($raData | Where-Object { $_.RiskLevel -eq "High" }).Count
    $criticalCount = @($raData | Where-Object { $_.RiskLevel -eq "Critical" }).Count

    Add-Metric -Metric "Risk Items - Low" -Value $lowCount
    Add-Metric -Metric "Risk Items - Medium" -Value $mediumCount
    Add-Metric -Metric "Risk Items - High" -Value $highCount
    Add-Metric -Metric "Risk Items - Critical" -Value $criticalCount
    Add-Metric -Metric "Risk Items - Total" -Value $raData.Count
}
else {
    Add-Metric -Metric "Risk Assessment" -Value "Report not found"
}

# ============================================================
# Export CSV Summary
# ============================================================
if ($summaryResults.Count -gt 0) {
    $reportPath = Export-ReportCsv -Data $summaryResults -OutputPath $OutputPath -ReportName "migration-summary"
    Write-Host ""
    Write-ToolkitLog -Message "Summary report exported to: $reportPath" -Level Success
}

# ============================================================
# Optional: Excel Export
# ============================================================
if ($ExportExcel) {
    if (Get-Module -ListAvailable -Name ImportExcel) {
        Write-Host ""
    Write-ToolkitLog -Message "Generating Excel workbook..." -Level Progress
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $excelPath = Join-Path $OutputPath "migration-assessment-$timestamp.xlsx"

        try {
            # Summary tab
            $summaryResults | Export-Excel -Path $excelPath -WorksheetName "Summary" -AutoSize -BoldTopRow

            # Add each report as a tab
            $reportFiles = @{
                "Farm Inventory"      = Get-LatestReport -Pattern "farm-inventory"
                "Web Applications"    = $waFile
                "Content Databases"   = $cdbFile
                "Site Collections"    = $scFile
                "Webs"                = $webFile
                "Lists and Libraries" = $llFile
                "Large Lists"         = $lgFile
                "Permissions"         = $psFile
                "Stale Sites"         = $ssFile
                "Workflows"           = $wfFile
                "Custom Solutions"    = $csFile
                "Risk Assessment"     = $raFile
            }

            foreach ($tabName in $reportFiles.Keys) {
                $filePath = $reportFiles[$tabName]
                if ($filePath -and (Test-Path $filePath)) {
                    $data = Import-Csv $filePath
                    if ($data.Count -gt 0) {
                        $data | Export-Excel -Path $excelPath -WorksheetName $tabName -AutoSize -BoldTopRow -Append
                    }
                }
            }

            Write-ToolkitLog -Message "Excel workbook saved to: $excelPath" -Level Success
        }
        catch {
            Write-ToolkitLog -Message "Failed to generate Excel workbook: $($_.Exception.Message)" -Level Warning
        }
    }
    else {
        Write-ToolkitLog -Message "ImportExcel module not found. Skipping Excel export. Install with: Install-Module ImportExcel" -Level Warning
    }
}

# ============================================================
# Optional: HTML Report
# ============================================================
if ($ExportHtml) {
    Write-Host ""
    Write-ToolkitLog -Message "Generating HTML summary dashboard..." -Level Progress

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $htmlPath = Join-Path $OutputPath "migration-summary-$timestamp.html"

    try {
        $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SharePoint Migration Scoping Assessment</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background-color: #f5f5f5; color: #333; }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #0078d4; margin-top: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; margin-top: 20px; }
        .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card .metric { font-size: 14px; color: #666; margin-bottom: 4px; }
        .card .value { font-size: 28px; font-weight: bold; color: #0078d4; }
        .risk-low { color: #107c10; }
        .risk-medium { color: #ff8c00; }
        .risk-high { color: #d83b01; }
        .risk-critical { color: #a80000; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px 12px; border-bottom: 1px solid #eee; }
        tr:hover { background-color: #f0f0f0; }
        .footer { margin-top: 40px; font-size: 12px; color: #999; }
    </style>
</head>
<body>
    <h1>SharePoint Migration Scoping Assessment</h1>
    <p><strong>Assessment Date:</strong> $assessmentDate</p>

    <h2>Summary Metrics</h2>
    <div class="summary-grid">
"@

        foreach ($metric in $summaryResults) {
            $cssClass = ""
            if ($metric.Metric -match "Critical") { $cssClass = "risk-critical" }
            elseif ($metric.Metric -match "High") { $cssClass = "risk-high" }
            elseif ($metric.Metric -match "Medium") { $cssClass = "risk-medium" }
            elseif ($metric.Metric -match "Low Risk") { $cssClass = "risk-low" }

            $htmlContent += @"

        <div class="card">
            <div class="metric">$($metric.Metric)</div>
            <div class="value $cssClass">$($metric.Value)</div>
        </div>
"@
        }

        $htmlContent += @"

    </div>

    <h2>Recommended Next Steps</h2>
    <table>
        <tr><th>#</th><th>Action</th></tr>
        <tr><td>1</td><td>Review site collection inventory and confirm ownership</td></tr>
        <tr><td>2</td><td>Review stale sites with business owners</td></tr>
        <tr><td>3</td><td>Assess large lists for migration feasibility</td></tr>
        <tr><td>4</td><td>Review unique permissions and simplify where possible</td></tr>
        <tr><td>5</td><td>Assess workflows for Power Automate replacement</td></tr>
        <tr><td>6</td><td>Review custom solutions for SharePoint Online compatibility</td></tr>
        <tr><td>7</td><td>Define migration waves based on risk assessment</td></tr>
        <tr><td>8</td><td>Plan pilot migration for low-risk site collections</td></tr>
    </table>

    <div class="footer">
        Generated by SharePoint Migration Scoping Toolkit | $assessmentDate
    </div>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-ToolkitLog -Message "HTML summary dashboard saved to: $htmlPath" -Level Success
    }
    catch {
        Write-ToolkitLog -Message "Failed to generate HTML report: $($_.Exception.Message)" -Level Warning
    }
}

Write-Host ""
Write-ToolkitLog -Message "Summary report generation complete." -Level Success
Write-Host ""
