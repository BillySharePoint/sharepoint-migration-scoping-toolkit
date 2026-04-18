# Tests

## Current Status

The SharePoint Migration Scoping Toolkit currently does not include automated tests because the scripts require a live SharePoint on-premises environment with the SharePoint PowerShell snap-in.

## Testing Recommendations

### Manual Testing

1. **Test on a non-production SharePoint farm** before running against production.
2. **Test individual scripts** against a single site collection before running full farm scans.
3. **Verify CSV output** opens correctly in Excel and contains expected columns.
4. **Compare output** against known environment data to validate accuracy.

### Test Checklist

- [ ] Scripts load the SharePoint snap-in successfully
- [ ] Output folder is created if it does not exist
- [ ] CSV files are generated with correct timestamped names
- [ ] CSV files open in Excel without encoding issues
- [ ] Each script handles errors gracefully (continues on individual failures)
- [ ] SharePoint objects (SPSite, SPWeb) are disposed properly
- [ ] Scripts work with `-WebApplicationUrl` parameter
- [ ] Scripts work with `-SiteCollectionUrl` parameter
- [ ] Main runner script calls all individual scripts
- [ ] Config file values are loaded and applied correctly

### Future Testing Plans

- Add Pester tests for shared module functions (risk scoring, file naming, etc.)
- Add mock-based tests for script logic where feasible
- Add integration test documentation for SharePoint farm validation

## Running Module Tests (Future)

When Pester tests are added:

```powershell
Invoke-Pester -Path .\tests\
```
