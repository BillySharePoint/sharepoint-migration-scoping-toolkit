# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-04-17

### Added

- Initial repository setup with README and documentation
- Shared PowerShell module (`SPMigrationScopingToolkit`) with helper functions
- Sample configuration file (`config/sample-config.json`)
- Main runner script (`Start-SPMigrationScopingAssessment.ps1`)

#### Phase 1 - Core Inventory Scripts
- `Get-SPSiteCollectionInventory.ps1` - Site collection inventory
- `Get-SPWebInventory.ps1` - Web / subsite inventory
- `Get-SPListLibraryInventory.ps1` - List and library inventory with migration risk indicators
- `Get-SPLargeListsReport.ps1` - Large list detection and reporting
- `Get-SPPermissionsSummary.ps1` - Unique permissions summary
- `Get-SPStaleSitesReport.ps1` - Stale / inactive site detection
- `Get-SPMigrationRiskAssessment.ps1` - Consolidated risk assessment

#### Phase 2 - Expanded Farm Discovery Scripts
- `Get-SPFarmInventory.ps1` - Farm-level inventory
- `Get-SPWebApplicationInventory.ps1` - Web application inventory
- `Get-SPContentDatabaseInventory.ps1` - Content database inventory
- `Get-SPWorkflowInventory.ps1` - Workflow association inventory
- `Get-SPCustomSolutionsInventory.ps1` - Farm solutions inventory
- `Get-SPFeatureInventory.ps1` - Feature inventory at all scopes

#### Reporting
- `Export-SPMigrationSummaryReport.ps1` - Summary report with optional HTML and Excel export

#### Documentation
- Setup guide
- Usage guide
- Output examples
- Migration scoping checklist
- Risk scoring model documentation
- Troubleshooting guide
- Contributing guidelines
- Security policy
