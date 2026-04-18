# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do not** open a public GitHub issue for security vulnerabilities.
2. Email the project maintainer directly or use GitHub's private vulnerability reporting feature.
3. Include a clear description of the vulnerability and steps to reproduce it.

### Response Timeline

- We aim to acknowledge security reports within **48 hours**.
- We will work to release a fix or mitigation within **7 days** for critical issues.

## Security Design

The SharePoint Migration Scoping Toolkit is designed with security in mind:

- **Read-only operations** — The toolkit does not modify SharePoint content, permissions, configuration, or site structure.
- **No credentials stored** — The toolkit does not store or transmit credentials.
- **No external network calls** — The toolkit operates entirely within the SharePoint farm and does not make outbound network requests.
- **No data exfiltration** — Reports are saved locally to the specified output folder.

## Best Practices for Users

- **Review scripts** before running them in your environment.
- Run scripts with the **minimum required permissions**.
- Store output reports securely — they may contain site URLs, owner names, and environment details.
- Do not commit output files containing environment-specific data to public repositories.
- Test in a **non-production environment** first.
