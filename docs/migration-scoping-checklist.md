# SharePoint Migration Scoping Checklist

Use this checklist to guide pre-migration discovery and scoping. Each item can be addressed using reports from the SharePoint Migration Scoping Toolkit.

---

## Environment Discovery

- [ ] Confirm SharePoint version and build number
- [ ] Confirm number of farms
- [ ] Confirm web applications and URLs
- [ ] Confirm content databases and sizes
- [ ] Confirm total site collections
- [ ] Confirm total subsites / webs
- [ ] Document server topology and roles

## Content Discovery

- [ ] Identify total lists and libraries
- [ ] Identify large sites by storage usage
- [ ] Identify large lists / libraries by item count
- [ ] Identify stale sites (no activity in 365+ days)
- [ ] Identify archived content candidates
- [ ] Identify personal sites (My Sites) and decide migration strategy
- [ ] Review content types and metadata usage

## Ownership and Governance

- [ ] Confirm site collection owners for all sites
- [ ] Identify sites with missing or unclear owners
- [ ] Identify sites with missing secondary owners
- [ ] Review unique permissions across webs and lists
- [ ] Confirm business ownership for each site collection
- [ ] Identify sites that require compliance or records management review
- [ ] Document governance model for post-migration

## Technical Risk

- [ ] Identify custom workflows (SharePoint Designer, Nintex, etc.)
- [ ] Identify farm solutions (.wsp)
- [ ] Identify custom features activated at any scope
- [ ] Identify unsupported customizations for SharePoint Online
- [ ] Review InfoPath forms usage
- [ ] Review BCS / External Content Types usage
- [ ] Document third-party product dependencies

## Permissions Review

- [ ] Identify webs with unique (broken inheritance) permissions
- [ ] Identify lists / libraries with unique permissions
- [ ] Identify objects with 50+ role assignments
- [ ] Identify objects with 100+ role assignments
- [ ] Review direct user assignments vs. group assignments
- [ ] Plan permission simplification where possible

## Migration Planning

- [ ] Group sites into migration waves by risk level
- [ ] Identify pilot migration candidates (low-risk sites)
- [ ] Define success criteria for pilot migrations
- [ ] Define User Acceptance Testing (UAT) approach
- [ ] Define rollback / issue resolution process
- [ ] Confirm communication plan for site owners
- [ ] Define migration scheduling and downtime windows
- [ ] Confirm migration tool (ShareGate, SPMT, Quest, AvePoint, etc.)
- [ ] Plan for DNS changes, vanity URLs, and redirects
- [ ] Plan for post-migration validation checks

## Stakeholder Communication

- [ ] Share summary report with project sponsors
- [ ] Share risk assessment with technical team
- [ ] Confirm business owner sign-off for each migration wave
- [ ] Communicate stale site cleanup plan
- [ ] Communicate workflow replacement plan
- [ ] Document decisions on archive vs. migrate for flagged sites

## Post-Migration Validation

- [ ] Verify content integrity in SharePoint Online
- [ ] Verify permissions migrated correctly
- [ ] Test key workflows and business processes
- [ ] Confirm search is indexing migrated content
- [ ] Validate external sharing settings
- [ ] Confirm compliance and retention policies
