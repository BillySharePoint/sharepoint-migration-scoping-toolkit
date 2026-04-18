#Requires -Version 5.1

<#
.SYNOPSIS
    Shared module for the SharePoint Migration Scoping Toolkit.

.DESCRIPTION
    Contains shared helper functions used across all scripts in the
    SharePoint Migration Scoping Toolkit. Provides consistent logging,
    output handling, configuration loading, risk scoring, and
    SharePoint snap-in management.

.NOTES
    This module is intended for SharePoint on-premises discovery and reporting only.
    It does not modify SharePoint content, permissions, or configuration.
#>

#region SharePoint Snap-in

function Initialize-SPSnapin {
    <#
    .SYNOPSIS
        Ensures the SharePoint PowerShell snap-in is loaded.
    #>
    [CmdletBinding()]
    param()

    if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
        try {
            Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop
            Write-Host "SharePoint PowerShell snap-in loaded successfully." -ForegroundColor Green
        }
        catch {
            throw "Failed to load SharePoint PowerShell snap-in. Ensure this script is run on a SharePoint server with the Management Shell installed. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Verbose "SharePoint PowerShell snap-in is already loaded."
    }
}

#endregion

#region Output Helpers

function Initialize-OutputFolder {
    <#
    .SYNOPSIS
        Ensures the output folder exists. Creates it if it does not.
    .PARAMETER OutputPath
        The path to the output folder.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Host "Created output folder: $OutputPath" -ForegroundColor Green
    }
    else {
        Write-Verbose "Output folder already exists: $OutputPath"
    }
}

function Get-TimestampedFileName {
    <#
    .SYNOPSIS
        Generates a timestamped file name for report output.
    .PARAMETER BaseName
        The base name for the file (e.g., 'site-collection-inventory').
    .PARAMETER Extension
        The file extension (default: 'csv').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseName,

        [string]$Extension = "csv"
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return "$BaseName-$timestamp.$Extension"
}

function Export-ReportCsv {
    <#
    .SYNOPSIS
        Exports report data to a UTF-8 CSV file with consistent formatting.
    .PARAMETER Data
        The collection of objects to export.
    .PARAMETER OutputPath
        The folder path for the output file.
    .PARAMETER ReportName
        The base name for the report file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Data,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$ReportName
    )

    Initialize-OutputFolder -OutputPath $OutputPath
    $fileName = Get-TimestampedFileName -BaseName $ReportName
    $filePath = Join-Path $OutputPath $fileName

    $Data | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported: $filePath" -ForegroundColor Green
    return $filePath
}

#endregion

#region Configuration

function Import-ToolkitConfig {
    <#
    .SYNOPSIS
        Loads configuration from a JSON config file.
    .PARAMETER ConfigPath
        Path to the JSON configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (!(Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green
        return $config
    }
    catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

function Merge-ConfigWithParameters {
    <#
    .SYNOPSIS
        Merges configuration file values with script parameters,
        giving priority to explicitly specified parameters.
    .PARAMETER Config
        The configuration object from Import-ToolkitConfig.
    .PARAMETER BoundParameters
        The $PSBoundParameters from the calling script.
    .PARAMETER Defaults
        A hashtable of default values to use as a fallback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Config,

        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters,

        [Parameter(Mandatory = $true)]
        [hashtable]$Defaults
    )

    $merged = @{}

    # Start with defaults
    foreach ($key in $Defaults.Keys) {
        $merged[$key] = $Defaults[$key]
    }

    # Overlay config file values
    if ($Config) {
        foreach ($property in $Config.PSObject.Properties) {
            $merged[$property.Name] = $property.Value
        }
    }

    # Overlay explicitly bound parameters (highest priority)
    foreach ($key in $BoundParameters.Keys) {
        if ($key -ne 'ConfigPath') {
            $merged[$key] = $BoundParameters[$key]
        }
    }

    return $merged
}

#endregion

#region Risk Scoring

function Get-RiskLevel {
    <#
    .SYNOPSIS
        Determines the risk level based on a numeric value and threshold ranges.
    .PARAMETER Value
        The numeric value to evaluate.
    .PARAMETER MediumThreshold
        Threshold for Medium risk.
    .PARAMETER HighThreshold
        Threshold for High risk.
    .PARAMETER CriticalThreshold
        Threshold for Critical risk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$Value,

        [long]$MediumThreshold = 0,
        [long]$HighThreshold = 0,
        [long]$CriticalThreshold = 0
    )

    if ($CriticalThreshold -gt 0 -and $Value -ge $CriticalThreshold) {
        return "Critical"
    }
    elseif ($HighThreshold -gt 0 -and $Value -ge $HighThreshold) {
        return "High"
    }
    elseif ($MediumThreshold -gt 0 -and $Value -ge $MediumThreshold) {
        return "Medium"
    }
    else {
        return "Low"
    }
}

function Get-ListRiskLevel {
    <#
    .SYNOPSIS
        Determines the risk level for a list or library based on item count.
    .PARAMETER ItemCount
        The number of items in the list or library.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$ItemCount
    )

    return Get-RiskLevel -Value $ItemCount -MediumThreshold 5000 -HighThreshold 100000 -CriticalThreshold 1000000
}

function Get-StaleSiteRiskLevel {
    <#
    .SYNOPSIS
        Determines the risk level for a stale site based on days since last modification.
    .PARAMETER DaysSinceLastModified
        Number of days since the site was last modified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DaysSinceLastModified
    )

    return Get-RiskLevel -Value $DaysSinceLastModified -MediumThreshold 365 -HighThreshold 730 -CriticalThreshold 1095
}

function Get-PermissionRiskLevel {
    <#
    .SYNOPSIS
        Determines the risk level based on role assignment count.
    .PARAMETER RoleAssignmentCount
        The number of role assignments on the object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$RoleAssignmentCount
    )

    return Get-RiskLevel -Value $RoleAssignmentCount -MediumThreshold 1 -HighThreshold 50 -CriticalThreshold 100
}

function Get-ListMigrationConcerns {
    <#
    .SYNOPSIS
        Evaluates a list/library and returns migration concerns, risk level, and recommended action.
    .PARAMETER ItemCount
        Number of items in the list.
    .PARAMETER HasUniquePermissions
        Whether the list has unique role assignments.
    .PARAMETER EnableVersioning
        Whether versioning is enabled.
    .PARAMETER MajorVersionLimit
        The major version limit (0 means no limit).
    .PARAMETER ForceCheckout
        Whether checkout is required.
    .PARAMETER IsHidden
        Whether the list is hidden.
    .PARAMETER LargeListThreshold
        The threshold above which a list is considered large (default: 5000).
    #>
    [CmdletBinding()]
    param(
        [long]$ItemCount = 0,
        [bool]$HasUniquePermissions = $false,
        [bool]$EnableVersioning = $false,
        [int]$MajorVersionLimit = 0,
        [bool]$ForceCheckout = $false,
        [bool]$IsHidden = $false,
        [int]$LargeListThreshold = 5000
    )

    $concerns = @()
    $highestRisk = "Low"
    $actions = @()

    # Large list check
    if ($ItemCount -ge 1000000) {
        $concerns += "Very large list over 1M items"
        $highestRisk = "Critical"
        $actions += "Requires detailed migration strategy"
    }
    elseif ($ItemCount -ge 100000) {
        $concerns += "Large list over 100K items"
        if ($highestRisk -ne "Critical") { $highestRisk = "High" }
        $actions += "Test migration and consider restructuring"
    }
    elseif ($ItemCount -ge $LargeListThreshold) {
        $concerns += "Large list over threshold"
        if ($highestRisk -notin @("Critical", "High")) { $highestRisk = "Medium" }
        $actions += "Review list structure, views, indexing, and migration batch strategy"
    }

    # Unique permissions
    if ($HasUniquePermissions) {
        $concerns += "Unique permissions"
        if ($highestRisk -notin @("Critical", "High")) { $highestRisk = "Medium" }
        $actions += "Include in permission validation testing"
    }

    # Versioning with no limit
    if ($EnableVersioning -and $MajorVersionLimit -eq 0) {
        $concerns += "Versioning enabled with no version limit"
        if ($highestRisk -notin @("Critical", "High")) { $highestRisk = "Medium" }
        $actions += "Review version history size and consider setting version limits"
    }

    # Force checkout
    if ($ForceCheckout) {
        $concerns += "Library requires checkout"
        if ($highestRisk -eq "Low") { $highestRisk = "Low" }
        $actions += "Validate checkout behavior post-migration"
    }

    # Hidden with many items
    if ($IsHidden -and $ItemCount -gt 1000) {
        $concerns += "Hidden list with many items"
        if ($highestRisk -eq "Low") { $highestRisk = "Medium" }
        $actions += "Verify whether hidden list content should be migrated"
    }

    return @{
        MigrationConcern  = ($concerns -join "; ")
        RiskLevel         = $highestRisk
        RecommendedAction = ($actions -join "; ")
    }
}

#endregion

#region Logging

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Writes a formatted log message to the console.
    .PARAMETER Message
        The message to display.
    .PARAMETER Level
        The severity level: Info, Warning, Error, Success, Progress.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Error", "Success", "Progress")]
        [string]$Level = "Info"
    )

    switch ($Level) {
        "Info" { Write-Host $Message -ForegroundColor White }
        "Warning" { Write-Warning $Message }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Progress" { Write-Host $Message -ForegroundColor Cyan }
    }
}

#endregion

#region Assessment Date

function Get-AssessmentDate {
    <#
    .SYNOPSIS
        Returns the current date formatted for report output.
    #>
    return (Get-Date -Format "yyyy-MM-dd")
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Initialize-SPSnapin',
    'Initialize-OutputFolder',
    'Get-TimestampedFileName',
    'Export-ReportCsv',
    'Import-ToolkitConfig',
    'Merge-ConfigWithParameters',
    'Get-RiskLevel',
    'Get-ListRiskLevel',
    'Get-StaleSiteRiskLevel',
    'Get-PermissionRiskLevel',
    'Get-ListMigrationConcerns',
    'Write-ToolkitLog',
    'Get-AssessmentDate'
)
