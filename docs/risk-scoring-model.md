# Risk Scoring Model

The SharePoint Migration Scoping Toolkit uses a simple, practical risk scoring model to provide a first-pass view of migration complexity. The goal is not to be perfect — it is to give migration teams useful information early in the planning process.

## Risk Levels

| Level        | Description                                                                                          |
| ------------ | ---------------------------------------------------------------------------------------------------- |
| **Low**      | No significant migration concerns identified. Standard migration approach expected.                  |
| **Medium**   | Some migration considerations exist. Review recommended before migration.                            |
| **High**     | Significant migration concerns. Requires detailed review and possibly a modified migration approach. |
| **Critical** | Major migration risk. Requires dedicated planning, testing, or business decision before migration.   |

---

## Risk Rules

### Stale Sites

Sites that have not been modified within a defined period may be candidates for archiving rather than migration.

| Condition                             | Risk Level | Recommended Action                                                 |
| ------------------------------------- | ---------- | ------------------------------------------------------------------ |
| No activity for 365–729 days          | Medium     | Confirm whether site should migrate                                |
| No activity for 730–1094 days         | High       | Consider archive or exclusion from migration                       |
| No activity for 1095+ days (3+ years) | Critical   | Archive candidate; business confirmation required before migration |

### Missing Ownership

Sites without a clear owner are difficult to validate during and after migration.

| Condition                   | Risk Level | Recommended Action                              |
| --------------------------- | ---------- | ----------------------------------------------- |
| Site has no primary owner   | High       | Confirm business owner before migration         |
| Site has no secondary owner | Medium     | Assign secondary owner for migration governance |

### Large Lists and Libraries

Large lists may fail or perform poorly during migration depending on the migration tool and approach.

| Condition             | Risk Level | Recommended Action                                               |
| --------------------- | ---------- | ---------------------------------------------------------------- |
| 5,000–99,999 items    | Medium     | Review views, indexing, and migration approach                   |
| 100,000–999,999 items | High       | Test migration; consider restructuring or batching               |
| 1,000,000+ items      | Critical   | Requires detailed migration strategy; consider splitting content |

### Unique Permissions

Objects with unique (broken inheritance) permissions increase migration complexity and post-migration validation effort.

| Condition                          | Risk Level | Recommended Action                                           |
| ---------------------------------- | ---------- | ------------------------------------------------------------ |
| Web or list has unique permissions | Medium     | Include in permission validation testing                     |
| Object has 50–99 role assignments  | High       | Review permission complexity; reduce direct user assignments |
| Object has 100+ role assignments   | Critical   | Simplify permissions before migration; convert to groups     |

### Versioning

Libraries with versioning enabled and no version limit can have very large version histories that significantly increase migration time and storage.

| Condition                                | Risk Level | Recommended Action                                                            |
| ---------------------------------------- | ---------- | ----------------------------------------------------------------------------- |
| Versioning enabled with no version limit | Medium     | Review version history size; consider setting version limits before migration |

### Workflows

SharePoint on-premises workflows (SharePoint Designer, Nintex, third-party) do not migrate automatically to SharePoint Online. They need to be rebuilt using Power Automate or other solutions.

| Condition                     | Risk Level | Recommended Action                                                                                          |
| ----------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------- |
| Workflow association detected | High       | Review workflow logic; rebuild using Power Automate where appropriate; validate with business process owner |

### Custom Farm Solutions

Farm solutions (.wsp files) deployed to SharePoint on-premises are not supported in SharePoint Online. They must be replaced with modern alternatives.

| Condition                         | Risk Level | Recommended Action                                                                                        |
| --------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------- |
| Custom farm solution deployed     | High       | Assess SharePoint Online compatibility; replace with SPFx, Power Platform, or out-of-the-box alternatives |
| Custom farm solution not deployed | Medium     | Verify if still needed; remove if no longer required                                                      |

### Storage

Large site collections may require extended migration windows and careful batching.

| Condition             | Risk Level | Recommended Action                                                         |
| --------------------- | ---------- | -------------------------------------------------------------------------- |
| 50–99 GB storage used | Medium     | Review migration batching strategy                                         |
| 100+ GB storage used  | High       | Confirm migration batching strategy; may require extended migration window |

---

## How Risk Scores Are Used

1. **Migration Risk Assessment script** (`Get-SPMigrationRiskAssessment.ps1`) evaluates each site collection, web, list, and library against the rules above.
2. Each flagged item is recorded with its `ObjectType`, `ObjectUrl`, `RiskCategory`, `RiskLevel`, `RiskReason`, and `RecommendedAction`.
3. The **Summary Report** (`Export-SPMigrationSummaryReport.ps1`) aggregates risk counts for stakeholder review.

## Customization

Risk thresholds can be adjusted using script parameters:

```powershell
# Adjust stale site threshold
.\Get-SPStaleSitesReport.ps1 -StaleSiteThresholdDays 180

# Adjust large list threshold
.\Get-SPLargeListsReport.ps1 -LargeListThreshold 10000
```

The risk scoring logic is implemented in the shared module (`modules/SPMigrationScopingToolkit/SPMigrationScopingToolkit.psm1`) and can be modified to fit specific organizational requirements.

## Limitations

- Risk scores are based on automated rules and may not capture all business context.
- The toolkit provides a **first-pass** assessment — findings should be reviewed by migration team leads.
- Item-level permission analysis is not included in the initial version to avoid performance impact.
- Workflow detection is best-effort; some third-party workflow products may not be fully detected.
