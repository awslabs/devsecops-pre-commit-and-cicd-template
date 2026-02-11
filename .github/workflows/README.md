# GitHub Actions Workflows

This directory contains GitHub Actions workflows that mirror the GitLab CI/CD pipeline functionality.

## Workflow

### Security and Compliance (`security-compliance.yml`)

Runs comprehensive security scanning and license compliance checks.

**Triggers:**

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch

**Jobs:**

#### ASH Security Scan

- Runs Automated Security Helper (ASH) for comprehensive security scanning
- Includes: Bandit, Semgrep, detect-secrets, Checkov, and more
- Uses UV package manager for isolated tool execution
- Uploads results as artifacts
- **Continues on error** to allow other checks to run

#### Ferret Scan (Sensitive Data)

- Scans for PII and sensitive information
- Detects: credit cards, SSNs, emails, IP addresses, secrets, social media handles
- Uses configuration from `.devsecops/ferret-scan.yaml`
- Outputs SARIF format for GitHub Security integration
- Uploads results to GitHub Security tab
- **Continues on error** to allow other checks to run

#### License Compliance

- Validates project dependencies against approved licenses
- Uses `licensecheck` with configuration from `licensecheck.toml`
- **Fails the build** if blocked licenses are detected
- Approved licenses: MIT, Apache 2.0, BSD, ISC, PSF, Unlicense, CC0, Boost, NCSA
- Blocked licenses: GPL, AGPL, LGPL (all versions)

**Permissions:**

- `contents: read` - Read repository contents
- `security-events: write` - Upload security scan results
- `actions: read` - Read workflow information

**Artifacts:**

- ASH security results (7 days retention)
- Ferret Scan SARIF report (7 days retention)
- License compliance report (7 days retention)

---

## Differences from GitLab CI

### Similarities

- Same Python version (3.13)
- Same Ferret Scan configuration and checks
- Same license compliance validation
- Equivalent security scanning with ASH
- Similar caching strategies

### Key Differences

1. **SARIF vs GitLab SAST Format**
   - GitHub uses SARIF format for security results
   - GitLab uses gitlab-sast format
   - Both integrate with their respective security dashboards

2. **Artifact Storage**
   - GitHub: Uses `actions/upload-artifact` with 7-day retention
   - GitLab: Uses `artifacts` with 1-week expiration

3. **Caching**
   - GitHub: Uses `actions/setup-python` with built-in pip caching
   - GitLab: Uses explicit cache configuration with keys

4. **Security Dashboard Integration**
   - GitHub: Uses `github/codeql-action/upload-sarif` for Security tab
   - GitLab: Uses `reports: sast:` for Security Dashboard

5. **Workflow Organization**
   - GitHub: Single workflow with three jobs (ASH, Ferret Scan, License Compliance)
   - GitLab: Single pipeline with two stages (security, compliance)

6. **Permissions**
   - GitHub: Explicit permissions per job
   - GitLab: Implicit permissions based on runner configuration

---

## Viewing Results

### Security Scan Results

1. Go to repository **Security** tab
2. Click **Code scanning alerts**
3. Filter by tool: `ferret-scan`, `ash`, etc.

### Workflow Artifacts

1. Go to **Actions** tab
2. Click on a workflow run
3. Scroll to **Artifacts** section
4. Download reports for detailed analysis

### Pull Request Checks

- All checks appear as status checks on pull requests
- Failed checks block merging (except those marked `continue-on-error`)
- Click "Details" to see specific failures

---

## Configuration

### Environment Variables

Edit the `env` section in workflow files:

```yaml
env:
  PYTHON_VERSION: "3.13"
  FERRET_SCAN_CONFIDENCE: "medium,high"
  FERRET_SCAN_CHECKS: "EMAIL,INTELLECTUAL_PROPERTY,IP_ADDRESS,SECRETS,SOCIAL_MEDIA"
  FERRET_SCAN_CONFIG: ".devsecops/ferret-scan.yaml"
```

### Trigger Branches

Modify the `on` section to change which branches trigger workflows:

```yaml
on:
  push:
    branches:
      - main
      - develop
      - feature/* # Add pattern matching
```

### Job Conditions

Adjust conditional execution in job `if` statements:

```yaml
if: |
  contains(github.event.head_commit.message, '.py') ||
  github.event_name == 'pull_request'
```

---

## Troubleshooting

### Workflow Not Running

- Check branch protection rules
- Verify workflow file syntax with `yamllint`
- Ensure workflows are enabled in repository settings

### Permission Errors

- Add required permissions to job or workflow level
- Check repository settings → Actions → General → Workflow permissions

### Cache Issues

- Clear cache: Settings → Actions → Caches
- Caches are scoped to branches and expire after 7 days

### Security Upload Failures

- Ensure `security-events: write` permission is set
- SARIF files must be valid (validate with online tools)
- Check file size limits (10MB for SARIF files)

---

## Best Practices

1. **Use Branch Protection**
   - Require status checks to pass before merging
   - Enable "Require branches to be up to date"

2. **Review Security Alerts**
   - Regularly check Security tab for findings
   - Triage and dismiss false positives
   - Create issues for legitimate findings

3. **Monitor Workflow Performance**
   - Review workflow run times
   - Optimize caching strategies
   - Use conditional execution for faster feedback

4. **Keep Dependencies Updated**
   - Use Dependabot for automated updates
   - Review and test updates before merging
   - Pin versions for reproducibility

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [SARIF Format Specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
- [Code Scanning Documentation](https://docs.github.com/en/code-security/code-scanning)
- [ASH Documentation](https://github.com/awslabs/automated-security-helper)
- [Ferret Scan Documentation](https://github.com/awslabs/ferret-scan)
