# Troubleshooting

Common issues and solutions when running the SharePoint Migration Scoping Toolkit.

---

## SharePoint Snap-in Not Loaded

**Error:** `The term 'Get-SPSite' is not recognized as the name of a cmdlet`

**Cause:** The SharePoint PowerShell snap-in is not loaded.

**Solution:**
- Run the script from **SharePoint Management Shell** (not regular PowerShell).
- Or ensure you are running on a SharePoint server where the snap-in is installed.
- The toolkit scripts automatically attempt to load the snap-in, but this requires that the SharePoint server binaries are present.

```powershell
# Manually load the snap-in
Add-PSSnapin Microsoft.SharePoint.PowerShell
```

---

## Access Denied

**Error:** `Access is denied` or `The current user does not have sufficient permissions`

**Cause:** The account running the script does not have adequate permissions.

**Solution:**
- For full farm inventory, run as a **SharePoint farm administrator**.
- For site collection-level reports, ensure the account is a **site collection administrator** on the target sites.
- Run SharePoint Management Shell as **Administrator**.

---

## Script Execution Policy Blocks Script

**Error:** `cannot be loaded because running scripts is disabled on this system`

**Cause:** PowerShell execution policy prevents running unsigned scripts.

**Solution:**

```powershell
# Option 1: Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Option 2: Bypass for the current session
PowerShell.exe -ExecutionPolicy Bypass -File .\Start-SPMigrationScopingAssessment.ps1

# Option 3: Unblock downloaded files
Get-ChildItem -Path "C:\path\to\toolkit" -Recurse | Unblock-File
```

---

## Large Farm Performance Concerns

**Symptom:** Scripts run very slowly or appear to hang.

**Cause:** The toolkit uses `Get-SPSite -Limit All` and iterates through all webs and lists, which can be slow in large environments.

**Solutions:**
- **Limit scope** using `-WebApplicationUrl` or `-SiteCollectionUrl` parameters.
- **Skip slow reports** using `-SkipPermissions` or `-SkipWorkflows` on the main runner.
- **Run individual scripts** for specific site collections instead of full farm scans.
- **Run during off-peak hours** to minimize impact on the SharePoint farm.
- Start with the **Site Collection Inventory** to understand the environment size before running detailed scans.

---

## Out of Memory Issues

**Symptom:** PowerShell process consumes excessive memory or crashes with out-of-memory errors.

**Cause:** Processing many `SPSite` and `SPWeb` objects without proper disposal, or scanning very large farms.

**Solutions:**
- The toolkit scripts dispose of SharePoint objects after processing. If you encounter memory issues, try:
  - Scanning one web application at a time
  - Scanning one site collection at a time
  - Running from a 64-bit PowerShell session
  - Restarting PowerShell between large runs
- On SharePoint servers with limited RAM, avoid scanning the entire farm in a single run.

---

## CSV File Locked by Excel

**Error:** `The process cannot access the file because it is being used by another process`

**Cause:** A previously generated CSV file is open in Excel, and the script is trying to write a new file with the same name.

**Solution:**
- The toolkit uses timestamped file names, so this should be rare.
- Close the CSV file in Excel before re-running.
- If the issue persists, specify a different output folder.

---

## Long-Running Reports

**Symptom:** Certain reports (permissions, features, workflows) take a very long time.

**Expected behavior:** These reports need to iterate through every web and list, which is inherently slow in large environments.

**Solutions:**
- Use the `-SiteCollectionUrl` parameter to run against a single site collection for testing.
- Skip slow reports during initial discovery and run them separately:

```powershell
# Run the main assessment without slow scans
.\Start-SPMigrationScopingAssessment.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -SkipPermissions -SkipWorkflows

# Run permissions separately later
.\Get-SPPermissionsSummary.ps1 -WebApplicationUrl "https://sharepoint.contoso.com"
```

---

## Module Not Found

**Error:** `Shared module not found at: ...`

**Cause:** The script cannot find the shared module file.

**Solution:**
- Ensure the repository structure is intact and the `modules/SPMigrationScopingToolkit/` folder exists.
- Run scripts from the `scripts/` folder so relative paths resolve correctly.
- If you moved scripts to a different location, update the module path or copy the module folder.

---

## Incorrect Data or Missing Values

**Symptom:** Some columns show `N/A` or unexpected values.

**Cause:** Some SharePoint properties may not be available in all versions or configurations.

**Solutions:**
- `N/A` values indicate the property was not accessible (common for missing owners or certain metadata).
- `NotCollected` in database size fields means the toolkit could not determine the size without SQL access.
- Review the specific script's documentation for known limitations.

---

## Running on a Non-SharePoint Server

**Error:** Various errors about missing assemblies or snap-ins.

**Cause:** The toolkit must be run on a server where SharePoint Server is installed.

**Solution:**
- Copy the scripts to a SharePoint server in the target farm.
- Remote PowerShell to SharePoint servers is not supported by the SharePoint snap-in — scripts must run locally.

---

## Still Having Issues?

1. Check the PowerShell error output for specific error messages.
2. Run with `-Verbose` flag for additional diagnostic output.
3. Test with a single site collection first to isolate the issue.
4. Open an issue on the GitHub repository with the error details.
