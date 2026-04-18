# Usage Guide

## Running the Full Assessment

The main runner script executes all available inventory and reporting scripts in sequence.

### Basic Usage

```powershell
cd .\scripts
.\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports\SPMigrationScope"
```

### Using a Configuration File

```powershell
.\Start-SPMigrationScopingAssessment.ps1 -ConfigPath "..\config\sample-config.json"
```

### Full Assessment Parameters

| Parameter                 | Type   | Default    | Description                                           |
| ------------------------- | ------ | ---------- | ----------------------------------------------------- |
| `-ConfigPath`             | String |            | Path to JSON configuration file                       |
| `-WebApplicationUrl`      | String |            | Limit scan to a specific web application              |
| `-OutputPath`             | String | `.\output` | Folder for CSV reports                                |
| `-SkipPermissions`        | Switch | `$false`   | Skip permissions summary scan                         |
| `-SkipWorkflows`          | Switch | `$false`   | Skip workflow inventory scan                          |
| `-SkipCustomSolutions`    | Switch | `$false`   | Skip custom solutions inventory                       |
| `-IncludePersonalSites`   | Switch | `$false`   | Include My Sites in the scan                          |
| `-IncludeSubsites`        | Switch | `$false`   | Include subsites in stale site analysis               |
| `-StaleSiteThresholdDays` | Int    | `365`      | Days since last modification for stale site detection |
| `-LargeListThreshold`     | Int    | `5000`     | Item count threshold for large list flagging          |

### Example: Skip Slow Scans

```powershell
.\Start-SPMigrationScopingAssessment.ps1 `
    -WebApplicationUrl "https://sharepoint.contoso.com" `
    -OutputPath "C:\Reports" `
    -SkipPermissions `
    -SkipWorkflows
```

---

## Running Individual Scripts

Each script can be run independently for targeted reporting.

### Site Collection Inventory

```powershell
.\Get-SPSiteCollectionInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

Include personal (My Sites):

```powershell
.\Get-SPSiteCollectionInventory.ps1 -OutputPath "C:\Reports" -IncludePersonalSites
```

### Web / Subsite Inventory

```powershell
.\Get-SPWebInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

Scan a single site collection:

```powershell
.\Get-SPWebInventory.ps1 -SiteCollectionUrl "https://sharepoint.contoso.com/sites/hr" -OutputPath "C:\Reports"
```

### List & Library Inventory

```powershell
.\Get-SPListLibraryInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

Include hidden lists:

```powershell
.\Get-SPListLibraryInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -IncludeHiddenLists
```

### Large Lists Report

```powershell
.\Get-SPLargeListsReport.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

Custom threshold:

```powershell
.\Get-SPLargeListsReport.ps1 -LargeListThreshold 10000 -OutputPath "C:\Reports"
```

### Permissions Summary

```powershell
.\Get-SPPermissionsSummary.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

### Stale Sites Report

```powershell
.\Get-SPStaleSitesReport.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -StaleSiteThresholdDays 180
```

Include subsites in stale analysis:

```powershell
.\Get-SPStaleSitesReport.ps1 -StaleSiteThresholdDays 365 -IncludeSubsites
```

### Migration Risk Assessment

```powershell
.\Get-SPMigrationRiskAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

### Farm Inventory

```powershell
.\Get-SPFarmInventory.ps1 -OutputPath "C:\Reports"
```

### Web Application Inventory

```powershell
.\Get-SPWebApplicationInventory.ps1 -OutputPath "C:\Reports"
```

### Content Database Inventory

```powershell
.\Get-SPContentDatabaseInventory.ps1 -OutputPath "C:\Reports"
```

### Workflow Inventory

```powershell
.\Get-SPWorkflowInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

### Custom Solutions Inventory

```powershell
.\Get-SPCustomSolutionsInventory.ps1 -OutputPath "C:\Reports"
```

### Feature Inventory

```powershell
.\Get-SPFeatureInventory.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports"
```

### Summary Report

```powershell
.\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports"
```

With HTML dashboard:

```powershell
.\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports" -ExportHtml
```

With Excel workbook (requires ImportExcel module):

```powershell
.\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports" -ExportExcel
```

---

## Tips

### Performance

- **Large environments** may take significant time to scan. Use `-WebApplicationUrl` or `-SiteCollectionUrl` to limit scope.
- **Skip slow scans** (permissions, workflows) during initial discovery and run them separately later.
- The toolkit uses `-Limit All` for `Get-SPSite` — in very large farms, this can consume significant memory.

### Output Files

- All reports are timestamped CSV files.
- Running the assessment multiple times creates new files (does not overwrite).
- Open CSVs in Excel for sorting, filtering, and analysis.

### Filtering Results

Parameters like `-WebApplicationUrl` and `-SiteCollectionUrl` allow you to focus on specific parts of the environment. This is useful for:

- Testing on a single site collection before running farm-wide
- Breaking large assessments into smaller, manageable scans
- Targeting specific web applications
