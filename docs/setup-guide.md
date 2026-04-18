# Setup Guide

## Prerequisites

### SharePoint Server

The SharePoint Migration Scoping Toolkit must be run on a SharePoint server where the SharePoint PowerShell snap-in is available.

Supported versions:
- SharePoint Server 2013
- SharePoint Server 2016
- SharePoint Server 2019
- SharePoint Server Subscription Edition

### PowerShell

- Windows PowerShell 5.1 (pre-installed on Windows Server 2016+)
- SharePoint Management Shell

### Permissions

For a full farm assessment, the account running the scripts should have:

- **SharePoint farm administrator** access
- **Read access** to all web applications, site collections, and content databases
- Permission to run **SharePoint Management Shell** commands

> Some individual reports (such as site collection inventory) can be run with site collection administrator access for a specific scope.

### Script Execution Policy

If PowerShell script execution is restricted on your server, you may need to adjust the execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass for the current session:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Start-SPMigrationScopingAssessment.ps1
```

## Download

### Option 1: Git Clone

```powershell
git clone https://github.com/yourname/sharepoint-migration-scoping-toolkit.git
```

### Option 2: Download ZIP

1. Go to the GitHub repository
2. Click **Code** > **Download ZIP**
3. Extract to a folder on the SharePoint server

## Running the Scripts

### Step 1: Open SharePoint Management Shell

Open **SharePoint Management Shell** as Administrator. This ensures the SharePoint PowerShell snap-in is available.

Alternatively, open a regular PowerShell window and the scripts will load the snap-in automatically.

### Step 2: Navigate to the Scripts Folder

```powershell
cd C:\path\to\sharepoint-migration-scoping-toolkit\scripts
```

### Step 3: Run the Full Assessment

```powershell
.\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -OutputPath "C:\Reports\SPMigrationScope"
```

### Step 4: Or Use a Configuration File

Edit `config/sample-config.json` with your environment settings, then:

```powershell
.\Start-SPMigrationScopingAssessment.ps1 -ConfigPath "..\config\sample-config.json"
```

### Step 5: Review Output

Reports are saved as timestamped CSV files in the specified output folder. Open them in Excel for review.

## Configuration File

The configuration file (`config/sample-config.json`) allows you to set default values:

```json
{
  "OutputPath": ".\\output",
  "WebApplicationUrl": "https://sharepoint.contoso.com",
  "IncludeSubsites": true,
  "IncludePersonalSites": false,
  "StaleSiteThresholdDays": 365,
  "LargeListThreshold": 5000,
  "VeryLargeListThreshold": 100000,
  "ExportCsv": true,
  "ExportHtml": false,
  "ExportExcel": false
}
```

Configuration file values are overridden by any explicitly specified command-line parameters.

## Optional: Excel Export

To enable Excel workbook export, install the ImportExcel module:

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

Then run the summary report with the `-ExportExcel` flag:

```powershell
.\Export-SPMigrationSummaryReport.ps1 -OutputPath "C:\Reports" -ExportExcel
```
