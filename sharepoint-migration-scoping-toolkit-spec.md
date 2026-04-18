# SharePoint Migration Scoping Toolkit - Build Specification

## Project Name

**SharePoint Migration Scoping Toolkit**

Suggested GitHub repository name:

```text
sharepoint-migration-scoping-toolkit
```

## Short Description

A PowerShell-based discovery and reporting toolkit for assessing on-premises SharePoint environments before migration to SharePoint Online / Microsoft 365.

## Purpose of the Project

This open-source project is intended to help SharePoint administrators, migration consultants, technical analysts, and business analysts collect useful discovery data from on-premises SharePoint environments before starting a SharePoint migration.

The toolkit should focus on **migration scoping, inventory, readiness assessment, and risk identification**. It is not intended to actually migrate content. Instead, it should help teams answer important pre-migration questions such as:

- What SharePoint farms, web applications, site collections, subsites, lists, and libraries exist?
- How large is the environment?
- Which sites are active and which ones are stale?
- Which sites have missing or unclear ownership?
- Which lists or libraries may be difficult to migrate?
- Which sites have unique permissions?
- Are there custom workflows, features, solutions, or unsupported customization risks?
- What content should be migrated, archived, cleaned up, or reviewed?
- What migration effort and risk level should be expected?

The project should be practical, professional, and useful for real-world SharePoint migration planning.

---

# Target Audience

This toolkit is for:

- SharePoint administrators
- Microsoft 365 consultants
- SharePoint migration consultants
- Technical analysts
- Business analysts working on SharePoint migration projects
- IT teams preparing to migrate from SharePoint Server to SharePoint Online
- Organizations needing a high-level inventory before using migration tools such as ShareGate, Microsoft SPMT, Quest, AvePoint, or other migration products

---

# Supported SharePoint Versions

The toolkit should be designed for on-premises SharePoint environments, primarily:

- SharePoint Server 2013
- SharePoint Server 2016
- SharePoint Server 2019
- SharePoint Server Subscription Edition

Where possible, scripts should avoid version-specific dependencies unless clearly documented.

---

# Technology Requirements

## Main Technology

- Windows PowerShell 5.1
- SharePoint Management Shell
- SharePoint Server PowerShell snap-in/module

## PowerShell Requirements

The scripts should run from a SharePoint server where the SharePoint PowerShell snap-in is available.

At the beginning of the scripts, check whether the SharePoint PowerShell snap-in is loaded:

```powershell
if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapin Microsoft.SharePoint.PowerShell
}
```

## Permissions Required

The user running the scripts should have appropriate SharePoint farm-level or site collection-level permissions depending on the report being generated.

For full farm inventory, the account should typically have:

- SharePoint farm administrator access
- Read access to web applications, site collections, and content databases
- Permission to run SharePoint Management Shell commands

The README should clearly state that some reports require elevated privileges.

---

# Important Project Positioning

This project should be positioned as a **pre-migration discovery and scoping toolkit**, not as a migration engine.

Use this language in the README:

> This toolkit does not migrate SharePoint content. It helps collect inventory, identify risks, and prepare better migration scope documentation before using a migration platform or tool.

---

# Recommended Repository Structure

```text
sharepoint-migration-scoping-toolkit/
│
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
│
├── config/
│   └── sample-config.json
│
├── docs/
│   ├── setup-guide.md
│   ├── usage-guide.md
│   ├── output-examples.md
│   ├── migration-scoping-checklist.md
│   ├── risk-scoring-model.md
│   └── troubleshooting.md
│
├── scripts/
│   ├── Start-SPMigrationScopingAssessment.ps1
│   ├── Get-SPFarmInventory.ps1
│   ├── Get-SPWebApplicationInventory.ps1
│   ├── Get-SPContentDatabaseInventory.ps1
│   ├── Get-SPSiteCollectionInventory.ps1
│   ├── Get-SPWebInventory.ps1
│   ├── Get-SPListLibraryInventory.ps1
│   ├── Get-SPLargeListsReport.ps1
│   ├── Get-SPPermissionsSummary.ps1
│   ├── Get-SPStaleSitesReport.ps1
│   ├── Get-SPWorkflowInventory.ps1
│   ├── Get-SPCustomSolutionsInventory.ps1
│   ├── Get-SPFeatureInventory.ps1
│   ├── Get-SPMigrationRiskAssessment.ps1
│   └── Export-SPMigrationSummaryReport.ps1
│
├── modules/
│   └── SPMigrationScopingToolkit/
│       ├── SPMigrationScopingToolkit.psm1
│       └── SPMigrationScopingToolkit.psd1
│
├── output-samples/
│   ├── farm-inventory.csv
│   ├── web-application-inventory.csv
│   ├── content-database-inventory.csv
│   ├── site-collection-inventory.csv
│   ├── web-inventory.csv
│   ├── list-library-inventory.csv
│   ├── large-lists-report.csv
│   ├── permissions-summary.csv
│   ├── stale-sites-report.csv
│   ├── workflow-inventory.csv
│   ├── custom-solutions-inventory.csv
│   └── migration-risk-assessment.csv
│
└── tests/
    └── README.md
```

---

# Development Approach

The project should be built in phases.

## Phase 1 - Minimum Viable Product

Build the most useful migration scoping scripts first:

1. `Start-SPMigrationScopingAssessment.ps1`
2. `Get-SPSiteCollectionInventory.ps1`
3. `Get-SPWebInventory.ps1`
4. `Get-SPListLibraryInventory.ps1`
5. `Get-SPLargeListsReport.ps1`
6. `Get-SPPermissionsSummary.ps1`
7. `Get-SPStaleSitesReport.ps1`
8. `Get-SPMigrationRiskAssessment.ps1`

Phase 1 should produce CSV reports that can be opened in Excel.

## Phase 2 - Expanded Farm Discovery

Add:

1. `Get-SPFarmInventory.ps1`
2. `Get-SPWebApplicationInventory.ps1`
3. `Get-SPContentDatabaseInventory.ps1`
4. `Get-SPWorkflowInventory.ps1`
5. `Get-SPCustomSolutionsInventory.ps1`
6. `Get-SPFeatureInventory.ps1`

## Phase 3 - Reporting Enhancements

Add:

1. Summary report generation
2. Optional Excel export if ImportExcel module is installed
3. HTML summary dashboard
4. Better risk scoring
5. Documentation improvements
6. Sample screenshots

---

# General Script Requirements

Every script should follow these standards:

## Required Parameters

Each script should include parameters where appropriate:

```powershell
param(
    [string]$WebApplicationUrl,
    [string]$SiteCollectionUrl,
    [string]$OutputPath = ".\\output",
    [switch]$IncludeSubsites,
    [switch]$IncludePersonalSites,
    [int]$StaleSiteThresholdDays = 365,
    [int]$LargeListThreshold = 5000,
    [switch]$VerboseLogging
)
```

Not every parameter applies to every script, but this is the general style.

## Output Folder Handling

Every script should verify that the output folder exists. If it does not exist, create it.

```powershell
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}
```

## Error Handling

Scripts should use practical error handling:

```powershell
try {
    # operation here
}
catch {
    Write-Warning "Failed to process item: $($_.Exception.Message)"
}
```

The script should continue processing other sites/lists when one object fails.

## Logging

Each script should write progress to the console:

```powershell
Write-Host "Processing site collection: $($site.Url)" -ForegroundColor Cyan
```

For errors or warnings:

```powershell
Write-Warning "Unable to access list: $($list.Title)"
```

Optional log file support can be added later.

## CSV Export

Every script should export results to CSV using UTF-8 encoding where possible:

```powershell
$results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
```

## Consistent Output Naming

Use timestamped file names:

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportPath = Join-Path $OutputPath "site-collection-inventory-$timestamp.csv"
```

---

# Configuration File

Create `config/sample-config.json`.

Example:

```json
{
  "OutputPath": ".\\output",
  "WebApplicationUrl": "https://sharepoint.contoso.com",
  "IncludeSubsites": true,
  "IncludePersonalSites": false,
  "StaleSiteThresholdDays": 365,
  "LargeListThreshold": 5000,
  "VeryLargeListThreshold": 100000,
  "UniquePermissionWarningThreshold": 50,
  "UniquePermissionHighRiskThreshold": 100,
  "ExportCsv": true,
  "ExportHtml": false,
  "ExportExcel": false
}
```

The main runner script should optionally accept a config file:

```powershell
.\\Start-SPMigrationScopingAssessment.ps1 -ConfigPath ".\\config\\sample-config.json"
```

---

# Main Runner Script

## Script Name

`scripts/Start-SPMigrationScopingAssessment.ps1`

## Purpose

This should be the main script that runs the full assessment and calls the other scripts or internal functions.

## Example Usage

```powershell
.\\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\\Reports\\SPMigrationScope"
```

Or using config:

```powershell
.\\Start-SPMigrationScopingAssessment.ps1 -ConfigPath ".\\config\\sample-config.json"
```

## Main Runner Responsibilities

The main script should:

1. Load configuration settings.
2. Validate SharePoint PowerShell availability.
3. Validate output folder.
4. Run selected inventory scripts.
5. Export all CSV reports.
6. Generate a summary report.
7. Display final output location.

## Suggested Parameters

```powershell
param(
    [string]$ConfigPath,
    [string]$WebApplicationUrl,
    [string]$OutputPath = ".\\output",
    [switch]$SkipPermissions,
    [switch]$SkipWorkflows,
    [switch]$SkipCustomSolutions,
    [switch]$IncludePersonalSites,
    [int]$StaleSiteThresholdDays = 365,
    [int]$LargeListThreshold = 5000
)
```

---

# Individual Script Details

## 1. Get-SPFarmInventory.ps1

### Purpose

Collect high-level farm information.

### Data to Capture

- Farm ID
- Farm build version
- Configuration database name
- Servers in farm
- Server role, if available
- Installed products, if available
- Services running on each server
- Current date/time of assessment

### Suggested Output Columns

```text
FarmId
BuildVersion
ConfigDatabaseName
ServerName
ServerRole
ServiceName
ServiceStatus
AssessmentDate
```

### Notes

Use SharePoint cmdlets such as:

```powershell
Get-SPFarm
Get-SPServer
Get-SPServiceInstance
```

---

## 2. Get-SPWebApplicationInventory.ps1

### Purpose

Collect all web applications and their key properties.

### Data to Capture

- Web application display name
- URL
- Application pool name
- Authentication providers
- Number of content databases
- Total site collections
- Maximum upload size
- Claims/classic authentication indication, if available

### Suggested Output Columns

```text
WebApplicationName
WebApplicationUrl
ApplicationPool
AuthenticationProvider
ContentDatabaseCount
SiteCollectionCount
MaximumFileSizeMB
AssessmentDate
```

### Notes

Use:

```powershell
Get-SPWebApplication
```

---

## 3. Get-SPContentDatabaseInventory.ps1

### Purpose

Collect content database information relevant to migration scoping.

### Data to Capture

- Content database name
- Web application URL
- Database server
- Current site count
- Warning site count
- Maximum site count
- Database size, if available
- Database status

### Suggested Output Columns

```text
ContentDatabaseName
WebApplicationUrl
DatabaseServer
CurrentSiteCount
WarningSiteCount
MaximumSiteCount
Status
AssessmentDate
```

### Notes

Use:

```powershell
Get-SPContentDatabase
```

Database size may require SQL access. If not available, document that limitation and leave the field blank or mark it as `NotCollected`.

---

## 4. Get-SPSiteCollectionInventory.ps1

### Purpose

Collect site collection-level inventory.

This is one of the most important scripts in the toolkit.

### Data to Capture

- Site collection URL
- Title
- Primary site collection administrator
- Secondary site collection administrator
- Owner email, if available
- Content database
- Template
- Compatibility level
- Storage used
- Storage quota
- Last content modified date
- Created date, if available
- Lock state
- Read-only status
- Number of webs/subsites
- Root web title
- Root web template

### Suggested Output Columns

```text
SiteCollectionUrl
Title
PrimaryOwner
SecondaryOwner
OwnerEmail
ContentDatabase
Template
CompatibilityLevel
StorageUsedMB
StorageQuotaMB
LastContentModifiedDate
CreatedDate
LockState
IsReadOnly
WebCount
RootWebTitle
RootWebTemplate
AssessmentDate
```

### Useful Cmdlets / Objects

```powershell
Get-SPSite
$site.RootWeb
$site.Usage.Storage
$site.Quota.StorageMaximumLevel
$site.LastContentModifiedDate
```

### Important Handling

Dispose of SPSite and SPWeb objects where needed to avoid memory leaks:

```powershell
$site.Dispose()
```

When using `Get-SPSite -Limit All`, be careful in large environments.

---

## 5. Get-SPWebInventory.ps1

### Purpose

Collect subsite/web-level inventory.

### Data to Capture

- Parent site collection URL
- Web URL
- Web title
- Description
- Template
- Language
- Created date
- Last item modified date
- Has unique permissions
- Associated owner group
- Associated member group
- Associated visitor group
- List count
- Library count

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
WebTitle
Description
Template
Language
CreatedDate
LastItemModifiedDate
HasUniquePermissions
AssociatedOwnerGroup
AssociatedMemberGroup
AssociatedVisitorGroup
ListCount
LibraryCount
AssessmentDate
```

### Notes

Use:

```powershell
$site.AllWebs
```

Dispose of web objects properly.

---

## 6. Get-SPListLibraryInventory.ps1

### Purpose

Collect information about lists and document libraries.

This report is highly useful for migration scoping because list size, library size, versioning, and content types can affect migration complexity.

### Data to Capture

- Site collection URL
- Web URL
- List/library title
- List/library URL
- Base type
- Base template
- Item count
- Hidden status
- Versioning enabled
- Major version limit
- Minor versioning enabled
- Content approval enabled
- Force checkout enabled
- Has unique role assignments
- Enable attachments
- Last item modified date

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
ListTitle
ListUrl
BaseType
BaseTemplate
ItemCount
Hidden
EnableVersioning
MajorVersionLimit
EnableMinorVersions
EnableModeration
ForceCheckout
HasUniqueRoleAssignments
EnableAttachments
LastItemModifiedDate
AssessmentDate
```

### Migration Risk Indicators

The script should mark a list or library as potentially risky if:

- Item count is greater than 5,000
- Item count is greater than 100,000
- Unique permissions are enabled
- Versioning is enabled with no version limit
- Library requires checkout
- List is hidden but has many items

Add optional output columns:

```text
MigrationConcern
RiskLevel
RecommendedAction
```

Example values:

```text
MigrationConcern: Large list over threshold
RiskLevel: Medium
RecommendedAction: Review list structure, views, indexing, and migration batch strategy
```

---

## 7. Get-SPLargeListsReport.ps1

### Purpose

Identify lists and libraries with item counts over a defined threshold.

### Default Threshold

Default should be 5,000 items.

```powershell
[int]$LargeListThreshold = 5000
```

### Data to Capture

- Site collection URL
- Web URL
- List title
- List URL
- Item count
- Base type
- Has unique permissions
- Versioning enabled
- Last modified date
- Risk level
- Recommended action

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
ListTitle
ListUrl
ItemCount
BaseType
HasUniqueRoleAssignments
EnableVersioning
LastItemModifiedDate
RiskLevel
RecommendedAction
AssessmentDate
```

### Risk Logic

Suggested rules:

```text
Item count 5,000 - 99,999 = Medium
Item count 100,000 - 999,999 = High
Item count 1,000,000+ = Critical
```

### Recommended Actions

Examples:

- Review indexed columns and views
- Confirm whether all content needs to migrate
- Consider splitting content into multiple libraries
- Review metadata and folder structure
- Validate migration tool limitations
- Run test migration for this list/library

---

## 8. Get-SPPermissionsSummary.ps1

### Purpose

Identify sites, lists, and libraries with unique permissions.

This is useful because complex permissions can increase migration complexity and post-migration validation effort.

### Scope

The first version should focus on summary-level permissions, not a full user-by-user permission matrix.

### Data to Capture

- Site collection URL
- Web URL
- Object type
- Object title
- Object URL
- Has unique permissions
- Role assignment count
- SharePoint groups count
- Direct user assignment count, if practical
- Risk level
- Recommended action

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
ObjectType
ObjectTitle
ObjectUrl
HasUniquePermissions
RoleAssignmentCount
GroupAssignmentCount
DirectUserAssignmentCount
RiskLevel
RecommendedAction
AssessmentDate
```

### Object Types

Possible object types:

```text
Web
List
Library
```

Do not attempt item-level permissions in the first version because that can be very slow and risky in large environments.

### Risk Logic

Suggested rules:

```text
Unique permissions on web = Medium
Unique permissions on list/library = Medium
More than 50 role assignments = High
More than 100 role assignments = Critical
```

### Recommended Actions

Examples:

- Review unique permission structure before migration
- Confirm site owners and access groups
- Reduce direct user permissions where possible
- Convert direct assignments to SharePoint groups or Microsoft Entra ID groups where appropriate
- Include this site in permission validation testing

---

## 9. Get-SPStaleSitesReport.ps1

### Purpose

Identify site collections and subsites that may be inactive or stale.

### Default Threshold

Default stale threshold should be 365 days.

```powershell
[int]$StaleSiteThresholdDays = 365
```

### Data to Capture

- Site collection URL
- Web URL
- Title
- Last content modified date
- Days since last modified
- Primary owner
- Secondary owner
- Storage used
- Suggested action

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
Title
LastContentModifiedDate
DaysSinceLastModified
PrimaryOwner
SecondaryOwner
StorageUsedMB
RiskLevel
RecommendedAction
AssessmentDate
```

### Risk Logic

Suggested rules:

```text
No activity for 365 - 729 days = Medium
No activity for 730 - 1094 days = High
No activity for 1095+ days = Critical / Archive Candidate
```

### Recommended Actions

Examples:

- Confirm with business owner before migration
- Archive instead of migrate
- Exclude from migration scope if no longer required
- Move to records/archive process
- Validate whether site is still required for compliance reasons

---

## 10. Get-SPWorkflowInventory.ps1

### Purpose

Identify potential workflow dependencies before migration.

### Data to Capture

- Site collection URL
- Web URL
- List title
- Workflow name
- Workflow association count
- Workflow type, if available
- Enabled status
- Risk level
- Recommended action

### Suggested Output Columns

```text
SiteCollectionUrl
WebUrl
ListTitle
WorkflowName
WorkflowAssociationCount
WorkflowType
Enabled
RiskLevel
RecommendedAction
AssessmentDate
```

### Notes

SharePoint Designer workflows and third-party workflows can be complicated to detect consistently. The first version can provide best-effort detection.

### Recommended Actions

Examples:

- Review workflow logic before migration
- Rebuild using Power Automate where appropriate
- Validate business process owner
- Include workflow testing in UAT

---

## 11. Get-SPCustomSolutionsInventory.ps1

### Purpose

Identify farm solutions and customizations that may affect migration planning.

### Data to Capture

- Solution name
- Solution ID
- Deployed status
- Deployment state
- Contains web application resource
- Last operation result
- Last operation time

### Suggested Output Columns

```text
SolutionName
SolutionId
Deployed
DeploymentState
ContainsWebApplicationResource
LastOperationResult
LastOperationTime
RiskLevel
RecommendedAction
AssessmentDate
```

### Useful Cmdlet

```powershell
Get-SPSolution
```

### Recommended Actions

Examples:

- Review customization for SharePoint Online compatibility
- Replace farm solutions with SPFx, Power Platform, or out-of-the-box alternatives
- Include customization review in migration planning

---

## 12. Get-SPFeatureInventory.ps1

### Purpose

Inventory activated SharePoint features at farm, web application, site collection, and web level where practical.

### Data to Capture

- Scope
- Feature display name
- Feature ID
- Compatibility level
- Site collection URL
- Web URL
- Risk level
- Recommended action

### Suggested Output Columns

```text
Scope
FeatureName
FeatureId
CompatibilityLevel
SiteCollectionUrl
WebUrl
RiskLevel
RecommendedAction
AssessmentDate
```

### Notes

This script can be added later because feature inventory across all webs may be slow.

---

# Migration Risk Assessment Script

## Script Name

`Get-SPMigrationRiskAssessment.ps1`

## Purpose

Generate a summary risk assessment based on the inventory outputs.

The goal is not to be perfect. The goal is to give a useful first-pass view of migration complexity.

## Risk Categories

Use these categories:

```text
Low
Medium
High
Critical
```

## Suggested Risk Rules

| Condition | Risk Level | Recommended Action |
|---|---|---|
| Site has no clear owner | High | Confirm business owner before migration |
| Site has not been modified in 365+ days | Medium | Confirm whether site should migrate |
| Site has not been modified in 730+ days | High | Consider archive or exclusion |
| Site has not been modified in 1095+ days | Critical | Archive candidate / business confirmation required |
| List/library has more than 5,000 items | Medium | Review views, indexing, and migration approach |
| List/library has more than 100,000 items | High | Test migration and consider restructuring |
| List/library has more than 1,000,000 items | Critical | Requires detailed migration strategy |
| Site/web/list has unique permissions | Medium | Include in permission validation |
| Object has more than 50 role assignments | High | Review permission complexity |
| Object has more than 100 role assignments | Critical | Simplify permissions before migration |
| Workflow detected | High | Review and rebuild if needed |
| Custom farm solution detected | High | Assess SharePoint Online compatibility |
| Large amount of storage used | Medium/High | Confirm migration batching strategy |

## Suggested Output Columns

```text
ObjectType
ObjectUrl
ObjectTitle
RiskCategory
RiskLevel
RiskReason
RecommendedAction
AssessmentDate
```

## Example Output

```text
ObjectType: List
ObjectUrl: https://sharepoint.contoso.com/sites/hr/Documents
ObjectTitle: HR Documents
RiskCategory: Large List
RiskLevel: High
RiskReason: Library contains 245,000 items
RecommendedAction: Review migration batching strategy and run test migration
```

---

# Summary Report

## Script Name

`Export-SPMigrationSummaryReport.ps1`

## Purpose

Create a high-level migration summary that can be shared with stakeholders.

## Suggested Summary Metrics

The summary report should include:

- Total web applications scanned
- Total content databases scanned
- Total site collections scanned
- Total subsites/webs scanned
- Total lists and libraries scanned
- Total large lists/libraries found
- Total stale sites found
- Total sites with unique permissions
- Total workflows detected
- Total custom solutions detected
- Count of low-risk items
- Count of medium-risk items
- Count of high-risk items
- Count of critical-risk items

## Output Format

Phase 1:

- CSV summary file

Future phase:

- HTML report
- Excel workbook with multiple tabs

## Suggested Output Columns

```text
Metric
Value
AssessmentDate
```

Example:

```text
Total Site Collections,128,2026-04-17
Total Large Lists,34,2026-04-17
Total High Risk Items,19,2026-04-17
```

---

# Optional HTML Report

In a future phase, generate a simple HTML dashboard with:

- Assessment date
- Environment scanned
- Summary cards
- Risk counts
- Top 10 largest site collections
- Top 10 largest lists/libraries
- Stale sites count
- Unique permissions count
- Recommended next steps

This should be optional and not required for the initial version.

---

# Optional Excel Export

If the `ImportExcel` PowerShell module is installed, the toolkit can optionally export an Excel workbook with multiple tabs.

Suggested workbook tabs:

```text
Summary
Farm Inventory
Web Applications
Content Databases
Site Collections
Webs
Lists and Libraries
Large Lists
Permissions Summary
Stale Sites
Workflows
Custom Solutions
Risk Assessment
```

The script should not require ImportExcel by default. It should detect whether the module is available.

```powershell
if (Get-Module -ListAvailable -Name ImportExcel) {
    # export Excel
}
else {
    Write-Warning "ImportExcel module not found. Skipping Excel export. CSV reports will still be created."
}
```

---

# README.md Requirements

The README should be polished and professional.

## README Structure

Use this structure:

```md
# SharePoint Migration Scoping Toolkit

## Overview
## What This Toolkit Does
## What This Toolkit Does Not Do
## Why This Project Exists
## Supported SharePoint Versions
## Requirements
## Quick Start
## Example Usage
## Reports Generated
## Migration Risk Scoring
## Recommended Migration Scoping Process
## Sample Output
## Roadmap
## Contributing
## License
## Disclaimer
```

## README Opening Paragraph

Use language similar to this:

```md
The SharePoint Migration Scoping Toolkit is a PowerShell-based discovery and reporting toolkit for assessing on-premises SharePoint environments before migration to SharePoint Online / Microsoft 365.

It helps SharePoint administrators, migration consultants, and technical analysts collect key discovery information such as site collections, subsites, lists, libraries, permissions, stale sites, large lists, workflows, and customization risks.

This project is designed to support better migration planning, cleaner scoping, and more informed stakeholder conversations before starting a SharePoint migration project.
```

## What This Toolkit Does

```md
- Inventories SharePoint on-premises site collections and subsites
- Reports list and library size, configuration, and migration concerns
- Identifies large lists and libraries
- Identifies stale or inactive sites
- Summarizes unique permissions
- Detects possible workflow and customization risks
- Generates CSV reports for migration planning
- Provides a simple risk assessment model
```

## What This Toolkit Does Not Do

```md
- It does not migrate SharePoint content
- It does not replace a full migration platform such as ShareGate, SPMT, Quest, or AvePoint
- It does not guarantee SharePoint Online compatibility
- It does not perform deep item-level permission auditing in the initial version
- It does not modify SharePoint content
```

## Quick Start Example

```powershell
cd .\\scripts
.\\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\\Reports\\SPMigrationScope"
```

## Disclaimer Text

```md
This project is provided as-is and should be tested in a non-production or controlled environment before being used in production. Always review scripts before running them in your SharePoint farm. The toolkit is intended for discovery and reporting only and should not modify SharePoint content.
```

---

# Documentation Files

## docs/setup-guide.md

Should explain:

- How to download the repository
- Where to run the scripts
- Required permissions
- How to open SharePoint Management Shell
- How to run the main script
- How to use the config file
- Where output files are saved

## docs/usage-guide.md

Should explain:

- How to run each script individually
- How to run the full assessment
- Parameter examples
- Example commands

## docs/output-examples.md

Should include sample table outputs for each CSV report.

## docs/migration-scoping-checklist.md

Should include a practical checklist:

```md
# SharePoint Migration Scoping Checklist

## Environment Discovery
- [ ] Confirm SharePoint version
- [ ] Confirm number of farms
- [ ] Confirm web applications
- [ ] Confirm content databases
- [ ] Confirm site collections

## Content Discovery
- [ ] Identify large sites
- [ ] Identify large lists/libraries
- [ ] Identify stale sites
- [ ] Identify archived content candidates

## Ownership and Governance
- [ ] Confirm site owners
- [ ] Identify sites with missing owners
- [ ] Review unique permissions
- [ ] Confirm business ownership for each site

## Technical Risk
- [ ] Identify custom workflows
- [ ] Identify farm solutions
- [ ] Identify custom features
- [ ] Identify unsupported customizations

## Migration Planning
- [ ] Group sites by migration wave
- [ ] Identify pilot migration sites
- [ ] Define UAT approach
- [ ] Define rollback/issue process
- [ ] Confirm communication plan
```

## docs/risk-scoring-model.md

Should document all risk rules clearly.

## docs/troubleshooting.md

Should include common issues:

- SharePoint snap-in not loaded
- Access denied
- Script execution policy blocks script
- Large farm performance concerns
- Out of memory issues
- CSV file locked by Excel
- Long-running reports

---

# Coding Standards

## PowerShell Style

Use readable PowerShell.

- Use approved verbs where possible
- Use clear variable names
- Add comment-based help to each script
- Use functions for repeated logic
- Avoid hardcoded paths
- Avoid changing SharePoint data
- Prefer read-only operations

## Comment-Based Help

Every script should include comment-based help.

Example:

```powershell
<#
.SYNOPSIS
Generates an inventory of SharePoint site collections for migration scoping.

.DESCRIPTION
Collects site collection information including URL, owners, storage usage, template, content database, and last modified date. Exports results to CSV.

.PARAMETER WebApplicationUrl
Optional web application URL to limit the scan.

.PARAMETER OutputPath
Folder path where the CSV report will be saved.

.EXAMPLE
.\\Get-SPSiteCollectionInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\\Reports"

.NOTES
This script is intended for SharePoint on-premises discovery and reporting only.
#>
```

---

# Performance Considerations

SharePoint farms can be large, so scripts should be designed carefully.

## Important Guidelines

- Avoid item-level scanning in the first version.
- Use `-Limit All` carefully and document the impact.
- Allow filtering by web application URL or site collection URL.
- Dispose of SharePoint objects properly.
- Continue on errors instead of stopping the whole scan.
- Write progress messages so the user knows what is happening.
- Document that large environments may take a long time to scan.

## Avoid in Version 1

Do not perform deep scans of:

- Every document
- Every list item
- Every item-level permission
- Every file version

These can cause long runtime and performance issues.

---

# Security and Safety Requirements

The toolkit should be read-only.

## Do Not Include Scripts That:

- Delete sites
- Delete lists
- Modify permissions
- Modify content
- Change workflows
- Disable features
- Change site collection administrators
- Perform migration actions

## Add a Safety Statement

Add this to README:

```md
The toolkit is designed to perform read-only discovery. It should not modify SharePoint content, permissions, configuration, or site structure.
```

---

# Sample Risk Assessment Output

Example CSV data:

```csv
ObjectType,ObjectUrl,ObjectTitle,RiskCategory,RiskLevel,RiskReason,RecommendedAction,AssessmentDate
SiteCollection,https://sharepoint.contoso.com/sites/hr,HR Portal,Stale Site,Medium,No activity in 420 days,Confirm with business owner before migration,2026-04-17
Library,https://sharepoint.contoso.com/sites/hr/Documents,HR Documents,Large Library,High,Library contains 245000 items,Review migration batching strategy and run test migration,2026-04-17
Web,https://sharepoint.contoso.com/sites/finance,Finance,Unique Permissions,Medium,Site has unique permissions,Include in permission validation testing,2026-04-17
Workflow,https://sharepoint.contoso.com/sites/legal,Contract Approval,Workflow Detected,High,Workflow association detected,Review and rebuild using Power Automate if needed,2026-04-17
```

---

# Sample Site Collection Inventory Output

```csv
SiteCollectionUrl,Title,PrimaryOwner,SecondaryOwner,OwnerEmail,ContentDatabase,Template,CompatibilityLevel,StorageUsedMB,StorageQuotaMB,LastContentModifiedDate,LockState,WebCount,AssessmentDate
https://sharepoint.contoso.com/sites/hr,HR Portal,CONTOSO\\jdoe,CONTOSO\\asmith,jdoe@contoso.com,WSS_Content_01,STS#0,15,2450,10240,2026-03-15,Unlock,12,2026-04-17
```

---

# Sample List and Library Inventory Output

```csv
SiteCollectionUrl,WebUrl,ListTitle,ListUrl,BaseType,BaseTemplate,ItemCount,Hidden,EnableVersioning,MajorVersionLimit,EnableMinorVersions,EnableModeration,ForceCheckout,HasUniqueRoleAssignments,LastItemModifiedDate,MigrationConcern,RiskLevel,RecommendedAction,AssessmentDate
https://sharepoint.contoso.com/sites/hr,https://sharepoint.contoso.com/sites/hr,Documents,/sites/hr/Documents,DocumentLibrary,101,245000,False,True,100,False,False,False,True,2026-03-10,Large library over threshold,High,Review migration batching strategy and run test migration,2026-04-17
```

---

# Roadmap

## Version 0.1.0

- Initial repository setup
- README and documentation
- Site collection inventory
- Web/subsite inventory
- List/library inventory
- Large lists report
- Stale sites report
- Permissions summary
- CSV exports

## Version 0.2.0

- Main runner script
- Config file support
- Risk assessment report
- Summary report

## Version 0.3.0

- Farm inventory
- Web application inventory
- Content database inventory
- Workflow inventory
- Custom solutions inventory

## Version 0.4.0

- Optional HTML summary report
- Optional Excel export
- Improved documentation
- Sample screenshots

## Version 1.0.0

- Stable script set
- Polished documentation
- Validated output examples
- Clear risk model
- Public release announcement

---

# Suggested License

Use the MIT License.

Reason:

- Simple and widely understood
- Good for open-source PowerShell scripts
- Allows others to use, modify, and contribute
- Looks professional for GitHub

---

# Suggested GitHub Topics

Add these repository topics:

```text
sharepoint
sharepoint-online
sharepoint-server
microsoft-365
powershell
migration
sharepoint-migration
spfx
m365
governance
inventory
assessment
technical-analysis
```

---

# Suggested GitHub About Description

Use this in the GitHub repository About section:

```text
PowerShell toolkit for assessing and scoping on-premises SharePoint environments before migration to SharePoint Online and Microsoft 365.
```

---

# Personal Branding Angle

This project should help demonstrate practical SharePoint migration experience.

The project should show skills in:

- SharePoint on-premises administration
- SharePoint migration planning
- Microsoft 365 readiness assessment
- PowerShell scripting
- Discovery and inventory reporting
- Governance and permissions review
- Technical analysis
- Business analysis support
- Migration scoping and documentation

The README and documentation should sound professional and practical, not overly academic.

---

# Suggested Website/Portfolio Description

Use this on a personal website or portfolio:

```md
I created the SharePoint Migration Scoping Toolkit as an open-source PowerShell project to help organizations assess their on-premises SharePoint environments before migrating to SharePoint Online. The toolkit collects discovery data such as site collections, subsites, lists, libraries, large lists, stale sites, permissions, workflows, and customization risks to support better migration planning and scoping.
```

---

# Suggested LinkedIn Announcement Draft

```md
I started building a new open-source project for SharePoint migration planning: the SharePoint Migration Scoping Toolkit.

The goal is simple: help SharePoint admins, consultants, and technical analysts collect useful discovery data from on-premises SharePoint environments before moving to SharePoint Online / Microsoft 365.

The toolkit is PowerShell-based and focused on pre-migration scoping, including:

- Site collection inventory
- Subsite inventory
- List and library inventory
- Large list detection
- Stale site reporting
- Unique permissions summary
- Workflow and customization risk indicators
- Migration readiness/risk assessment

This is not a migration tool. It is designed to support the discovery and planning stage before migration begins.

I wanted to create something practical based on the kind of questions that come up early in real SharePoint migration projects:

What do we have?
What should we migrate?
What should we clean up first?
Where are the risks?
Who owns each site?

I will continue improving it and adding more reports over time.
```

---

# Final Instruction to Coding Agent

Build this project as a clean, professional, public GitHub repository.

Focus first on practical working PowerShell scripts that generate useful CSV reports. Keep the first version simple, read-only, and reliable. Avoid overengineering. The project should look polished enough to be shared with recruiters, hiring managers, SharePoint professionals, and potential clients.

The most important goal is to create a toolkit that demonstrates real understanding of SharePoint migration scoping and discovery.
