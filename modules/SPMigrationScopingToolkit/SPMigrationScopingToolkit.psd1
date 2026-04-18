@{
    RootModule        = 'SPMigrationScopingToolkit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'SharePoint Migration Scoping Toolkit Contributors'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026. All rights reserved. MIT License.'
    Description       = 'Shared helper functions for the SharePoint Migration Scoping Toolkit. Provides logging, output handling, configuration loading, risk scoring, and SharePoint snap-in management.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('SharePoint', 'Migration', 'Scoping', 'Inventory', 'Assessment')
            ProjectUri = 'https://github.com/yourname/sharepoint-migration-scoping-toolkit'
        }
    }
}
