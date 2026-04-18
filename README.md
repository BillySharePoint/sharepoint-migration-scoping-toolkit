# SharePoint Migration Scoping Toolkit

## Overview

The SharePoint Migration Scoping Toolkit is a PowerShell-based discovery and reporting toolkit for assessing on-premises SharePoint environments before migration to SharePoint Online / Microsoft 365.

It helps SharePoint administrators, migration consultants, and technical analysts collect key discovery information such as site collections, subsites, lists, libraries, permissions, stale sites, large lists, workflows, and customization risks.

This project is designed to support better migration planning, cleaner scoping, and more informed stakeholder conversations before starting a SharePoint migration project.

> **This toolkit does not migrate SharePoint content. It helps collect inventory, identify risks, and prepare better migration scope documentation before using a migration platform or tool.**

## What This Toolkit Does

- Inventories SharePoint on-premises site collections and subsites
- Reports list and library size, configuration, and migration concerns
- Identifies large lists and libraries
- Identifies stale or inactive sites
- Summarizes unique permissions
- Detects possible workflow and customization risks
- Generates CSV reports for migration planning
- Provides a simple risk assessment model
- Optionally generates HTML summary dashboards
- Optionally exports Excel workbooks (requires ImportExcel module)

## What This Toolkit Does Not Do

- It does not migrate SharePoint content
- It does not replace a full migration platform such as ShareGate, SPMT, Quest, or AvePoint
- It does not guarantee SharePoint Online compatibility
- It does not perform deep item-level permission auditing in the initial version
- It does not modify SharePoint content

## Why This Project Exists

Pre-migration discovery is one of the most important steps in any SharePoint migration project. Without clear inventory and risk data, migration teams often encounter surprises during execution — large lists that fail to migrate, sites with no clear owner, complex permission structures, or workflows with no replacement plan.

This toolkit provides a practical, scriptable way to collect that discovery data so that migration planning is grounded in real information.

## Supported SharePoint Versions

- SharePoint Server 2013
- SharePoint Server 2016
- SharePoint Server 2019
- SharePoint Server Subscription Edition

## Requirements

### Software

- Windows PowerShell 5.1
- SharePoint Management Shell
- SharePoint Server PowerShell snap-in

### Permissions

- SharePoint farm administrator access (for full farm inventory)
- Read access to web applications, site collections, and content databases
- Permission to run SharePoint Management Shell commands

> **Note:** Some reports require elevated privileges. Run scripts on a SharePoint server where the SharePoint PowerShell snap-in is available.

### Optional

- [ImportExcel](https://github.com/dfinke/ImportExcel) PowerShell module (for Excel workbook export)

## Quick Start

1. **Clone or download** this repository to a SharePoint server.

2. **Open SharePoint Management Shell** (Run as Administrator).

3. **Run the full assessment:**

```powershell
cd .\scripts
.\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports\SPMigrationScope"
```

4. **Or use a configuration file:**

```powershell
.\Start-SPMigrationScopingAssessment.ps1 -ConfigPath "..\config\sample-config.json"
```

5. **Find your reports** in the output folder as timestamped CSV files.

## Example Usage

### Run individual reports

```powershell
# Site collection inventory
.\Get-SPSiteCollectionInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"

# Large lists report with custom threshold
.\Get-SPLargeListsReport.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -LargeListThreshold 10000

# Stale sites with 180-day threshold including subsites
.\Get-SPStaleSitesReport.ps1 -StaleSiteThresholdDays 180 -IncludeSubsites

# Migration risk assessment
.\Get-SPMigrationRiskAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com"

# Generate summary with HTML dashboard
.\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports" -ExportHtml
```

### Full assessment with options

```powershell
.\Start-SPMigrationScopingAssessment.ps1 `
    -WebApplicationUrl "https://sharepoint.contoso.com" `
    -OutputPath "C:\Reports\SPMigrationScope" `
    -StaleSiteThresholdDays 180 `
    -LargeListThreshold 5000 `
    -IncludeSubsites `
    -SkipWorkflows
```

## Reports Generated

| Report                     | Script                                | Description                                                   |
| -------------------------- | ------------------------------------- | ------------------------------------------------------------- |
| Farm Inventory             | `Get-SPFarmInventory.ps1`             | Farm build version, servers, roles, and services              |
| Web Application Inventory  | `Get-SPWebApplicationInventory.ps1`   | Web applications, app pools, authentication, database counts  |
| Content Database Inventory | `Get-SPContentDatabaseInventory.ps1`  | Content databases, sizes, site counts, status                 |
| Site Collection Inventory  | `Get-SPSiteCollectionInventory.ps1`   | Site collections, owners, storage, templates, last modified   |
| Web / Subsite Inventory    | `Get-SPWebInventory.ps1`              | Subsites, templates, permissions, list/library counts         |
| List & Library Inventory   | `Get-SPListLibraryInventory.ps1`      | Lists, libraries, item counts, versioning, migration concerns |
| Large Lists Report         | `Get-SPLargeListsReport.ps1`          | Lists/libraries exceeding item count threshold                |
| Permissions Summary        | `Get-SPPermissionsSummary.ps1`        | Objects with unique (broken inheritance) permissions          |
| Stale Sites Report         | `Get-SPStaleSitesReport.ps1`          | Sites not modified within threshold period                    |
| Workflow Inventory         | `Get-SPWorkflowInventory.ps1`         | Workflow associations on webs and lists                       |
| Custom Solutions Inventory | `Get-SPCustomSolutionsInventory.ps1`  | Farm solutions and deployment status                          |
| Feature Inventory          | `Get-SPFeatureInventory.ps1`          | Activated features at all scopes                              |
| Migration Risk Assessment  | `Get-SPMigrationRiskAssessment.ps1`   | Consolidated risk analysis with recommendations               |
| Migration Summary          | `Export-SPMigrationSummaryReport.ps1` | High-level metrics and stakeholder summary                    |

## Migration Risk Scoring

The toolkit uses a simple risk model to flag potential migration concerns:

| Condition                        | Risk Level  | Recommended Action                                 |
| -------------------------------- | ----------- | -------------------------------------------------- |
| Site has no clear owner          | High        | Confirm business owner before migration            |
| No activity for 365–729 days     | Medium      | Confirm whether site should migrate                |
| No activity for 730–1094 days    | High        | Consider archive or exclusion                      |
| No activity for 1095+ days       | Critical    | Archive candidate / business confirmation required |
| List has 5,000–99,999 items      | Medium      | Review views, indexing, and migration approach     |
| List has 100,000–999,999 items   | High        | Test migration and consider restructuring          |
| List has 1,000,000+ items        | Critical    | Requires detailed migration strategy               |
| Object has unique permissions    | Medium      | Include in permission validation                   |
| Object has 50+ role assignments  | High        | Review permission complexity                       |
| Object has 100+ role assignments | Critical    | Simplify permissions before migration              |
| Workflow detected                | High        | Review and rebuild if needed                       |
| Custom farm solution detected    | High        | Assess SharePoint Online compatibility             |
| Large storage usage              | Medium/High | Confirm migration batching strategy                |

For full details, see [docs/risk-scoring-model.md](docs/risk-scoring-model.md).

## Recommended Migration Scoping Process

1. **Run the full assessment** using the main runner script
2. **Review the site collection inventory** — confirm ownership and identify gaps
3. **Review stale sites** — decide what to archive vs. migrate
4. **Review large lists** — plan migration batching and test early
5. **Review permissions** — simplify complex permission structures where possible
6. **Review workflows** — plan Power Automate replacements
7. **Review custom solutions** — assess SPO compatibility
8. **Use the risk assessment** — prioritize migration waves by risk level
9. **Share the summary report** with stakeholders and project sponsors

## Sample Output

Reports are exported as timestamped CSV files that can be opened directly in Excel:

```text
output/
├── site-collection-inventory-20260417-143000.csv
├── web-inventory-20260417-143015.csv
├── list-library-inventory-20260417-143045.csv
├── large-lists-report-20260417-143100.csv
├── permissions-summary-20260417-143130.csv
├── stale-sites-report-20260417-143145.csv
├── migration-risk-assessment-20260417-143200.csv
└── migration-summary-20260417-143215.csv
```

See [docs/output-examples.md](docs/output-examples.md) for sample report data.

## Repository Structure

```text
sharepoint-migration-scoping-toolkit/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── config/
│   └── sample-config.json
├── docs/
│   ├── setup-guide.md
│   ├── usage-guide.md
│   ├── output-examples.md
│   ├── migration-scoping-checklist.md
│   ├── risk-scoring-model.md
│   └── troubleshooting.md
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
├── modules/
│   └── SPMigrationScopingToolkit/
│       ├── SPMigrationScopingToolkit.psm1
│       └── SPMigrationScopingToolkit.psd1
├── output-samples/
└── tests/
```

## Roadmap

### Version 0.1.0
- Initial repository setup, README, and documentation
- Site collection, web, list/library inventory
- Large lists, stale sites, and permissions reports
- CSV exports

### Version 0.2.0
- Main runner script with config file support
- Risk assessment and summary reports

### Version 0.3.0
- Farm, web application, and content database inventory
- Workflow and custom solutions inventory

### Version 0.4.0
- Optional HTML summary dashboard
- Optional Excel export
- Improved documentation and sample screenshots

### Version 1.0.0
- Stable script set with polished documentation
- Validated output examples and clear risk model
- Public release

## Contributing

Contributions are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).

## Disclaimer

This project is provided as-is and should be tested in a non-production or controlled environment before being used in production. Always review scripts before running them in your SharePoint farm. The toolkit is designed to perform read-only discovery. It should not modify SharePoint content, permissions, configuration, or site structure.
