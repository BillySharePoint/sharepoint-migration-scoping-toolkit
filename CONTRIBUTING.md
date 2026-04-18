# Contributing

Thank you for your interest in contributing to the SharePoint Migration Scoping Toolkit!

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](../../issues) to report bugs or suggest enhancements.
- Include clear steps to reproduce any issues.
- Include the SharePoint version and PowerShell version you are using.

### Suggesting Features

- Open a GitHub Issue with the **enhancement** label.
- Describe the use case and how the feature would help with migration scoping.

### Submitting Changes

1. **Fork** the repository.
2. Create a **feature branch** from `main`:
   ```
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following the coding standards below.
4. **Test** your changes on a SharePoint server (or document that testing was not possible).
5. **Commit** with a clear message:
   ```
   git commit -m "Add: description of your change"
   ```
6. **Push** to your fork and open a **Pull Request**.

## Coding Standards

### PowerShell Style

- Use **approved PowerShell verbs** (Get, Set, Export, etc.)
- Use **clear, descriptive variable names**
- Add **comment-based help** (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`) to all scripts
- Use **functions** for repeated logic
- Avoid hardcoded paths
- Avoid changing SharePoint data — this toolkit is **read-only**
- Handle errors gracefully with `try/catch`
- Dispose of SharePoint objects (`SPSite`, `SPWeb`) properly
- Write progress messages using `Write-Host` with appropriate colors
- Export data using `Export-Csv -NoTypeInformation -Encoding UTF8`

### Naming Conventions

- Script files: `Verb-SPNoun.ps1` (e.g., `Get-SPSiteCollectionInventory.ps1`)
- Output files: `kebab-case-YYYYMMDD-HHmmss.csv`
- Functions: PascalCase with approved verbs

### Script Structure

Each script should:

1. Include `#Requires -Version 5.1`
2. Include comment-based help
3. Define parameters with defaults
4. Import the shared module
5. Initialize SharePoint snap-in
6. Initialize output folder
7. Process data with error handling
8. Export results to CSV
9. Display summary

## Code of Conduct

Be respectful and constructive. This is a community project aimed at helping SharePoint professionals. All contributors are expected to maintain a positive and professional tone.

## Questions?

Open an issue on GitHub if you have questions about contributing.
