# Security Policy

## Automated Security Scanning

This repository uses multiple automated security scanning tools to identify and address vulnerabilities:

### Code Scanning

#### CodeQL Analysis
- **What**: Semantic code analysis for supported languages
- **When**: On push to main, pull requests, and weekly schedule
- **Languages**: Python (shell scripts not supported by CodeQL)
- **Coverage**: Security vulnerabilities, code quality issues
- **Results**: Available in the Security tab under "Code scanning alerts"

#### ShellCheck Analysis
- **What**: Static analysis specifically for shell scripts
- **When**: On push to main, pull requests, and weekly schedule
- **Coverage**: Common shell scripting errors, security issues, best practices
- **Configuration**: Uses `.shellcheckrc` in the repository root
- **Results**: Uploaded to Security tab as SARIF format

#### Trivy Scanning
Multiple Trivy scans run to ensure comprehensive security coverage:

1. **Repository Scan**
   - Scans for vulnerabilities in dependencies
   - Detects misconfigurations in IaC files
   - Identifies hardcoded secrets
   - Severity: CRITICAL, HIGH, MEDIUM

2. **DevContainer Scan**
   - Scans the development container image
   - Identifies vulnerabilities in base image and installed packages
   - Severity: CRITICAL, HIGH

#### Dependency Review
- **What**: Analyzes dependency changes in pull requests
- **When**: Automatically on all pull requests
- **Coverage**: Known vulnerabilities, license compliance
- **Action**: Fails PRs with moderate or higher severity vulnerabilities

### Dependabot

Automated dependency updates are configured for:
- GitHub Actions (weekly)
- Docker base images (weekly)
- DevContainer features (weekly)

See `.github/dependabot.yml` for configuration details.

## Reporting a Vulnerability

If you discover a security vulnerability in this project:

1. **DO NOT** open a public issue
2. **DO** report it privately using one of these methods:
   - Use GitHub's [private vulnerability reporting](https://github.com/austyle-io/file-assoc/security/advisories/new) (preferred)
   - Email the maintainers directly (see CODEOWNERS or commit history)

### What to Include

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

### Response Time

- **Initial Response**: Within 3 business days
- **Status Update**: Within 7 business days
- **Fix Timeline**: Depends on severity (critical issues prioritized)

## Security Best Practices

When contributing to this project:

1. **Shell Scripts**
   - Always use `set -euo pipefail` at the top of scripts
   - Quote variables to prevent word splitting: `"$variable"`
   - Use ShellCheck locally before committing
   - Avoid `eval` unless absolutely necessary

2. **Dependencies**
   - Keep dependencies up to date
   - Review Dependabot PRs promptly
   - Check for known vulnerabilities before adding new dependencies

3. **Secrets**
   - Never commit secrets, API keys, or credentials
   - Use environment variables or secure secret management
   - Review Trivy secret scan results

4. **Code Review**
   - All PRs require review before merge
   - Security-related changes need extra scrutiny
   - Check for common vulnerabilities (injection, XSS, etc.)

## Security Scanning Results

View security scanning results in:
- **Security Tab**: https://github.com/austyle-io/file-assoc/security
- **Code Scanning**: https://github.com/austyle-io/file-assoc/security/code-scanning
- **Dependabot**: https://github.com/austyle-io/file-assoc/security/dependabot

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < main  | :x:                |

Security updates are only provided for the main branch. Users should always use the latest version.

## Additional Resources

- [GitHub Security Documentation](https://docs.github.com/en/code-security)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
