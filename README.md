# DevSecOps: Pre-commit Hooks & CI/CD Pipeline

This repository provides pre-commit hooks and GitLab CI/CD pipeline configuration to automatically run security, code quality, and formatting checks before each commit and in your CI/CD pipeline.

## Table of Contents

- [Quick Setup - Add to Existing Repository](#quick-setup---add-to-existing-repository)
- [Installation](#installation)
- [What These Pre-commit Hooks Do](#what-these-pre-commit-hooks-do)
- [Usage](#usage)
- [Updating Hooks](#updating-hooks)
- [Running Tools Individually](#running-tools-individually)
- [GitLab CI/CD Integration](#gitlab-cicd-integration)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Quick Setup - Add to Existing Repository

Use the standalone setup script to automatically configure DevSecOps in your repository:

**Quick setup (one command):**

```bash
TEMP_SETUP="$(mktemp -d)" && git clone https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git "$TEMP_SETUP/repo" && bash "$TEMP_SETUP/repo/setup.sh" && rm -rf "$TEMP_SETUP"
```

**Or review before running:**

```bash
TEMP_SETUP="$(mktemp -d)"
git clone https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git "$TEMP_SETUP/repo"
cat "$TEMP_SETUP/repo/setup.sh"
bash "$TEMP_SETUP/repo/setup.sh"
rm -rf "$TEMP_SETUP"
```

**What the setup script does:**

- ✅ Checks prerequisites (git, rsync, pre-commit)
- ✅ Clones the DevSecOps repository
- ✅ **Terraform Usage Detection**: Asks if you're using Terraform and validates dependencies
- ✅ **Interactive Configuration Selection**: Choose between security-only or security + linting
- ✅ **Smart Configuration**: Automatically includes/excludes Terraform hooks based on your usage
- ✅ Copies configuration files (licensecheck.toml, .devsecops/)
- ✅ Prompts before replacing existing .pre-commit-config.yaml or .gitlab-ci.yml (creates backups)
- ✅ Automatically updates .gitignore with DevSecOps entries
- ✅ Updates pre-commit hooks to latest versions
- ✅ Shows clear next steps

## Pre-commit Configuration Options

The setup script offers two pre-commit configuration templates:

### 1. Security Only (`.pre-commit-config-security.yaml`)

**What it includes:**

- ✅ Security scanning (ASH, Ferret Scan)
- ✅ License compliance checking
- ✅ Basic code quality checks (JSON/YAML validation, private key detection)
- ✅ Infrastructure security (CloudFormation + Terraform validation)
- ✅ Python dependency vulnerability scanning

**What it does NOT include:**

- ❌ No automatic code formatting
- ❌ No linting that modifies files
- ❌ No language-specific formatters

**Best for:**

- Teams that prefer manual code formatting
- Existing projects with established formatting standards
- CI/CD pipelines where you only want security checks
- Projects where code style is handled by IDEs or separate tools

### 2. Security + Linting (`.pre-commit-config-security-linting.yaml`)

**What it includes:**

- ✅ Everything from Security Only configuration
- ✅ **Automatic code formatting and fixes:**
  - **Python**: Black formatting
  - **JavaScript/TypeScript**: ESLint auto-fix + Prettier formatting
  - **Go**: gofmt + goimports formatting
  - **Java**: Google Java Style formatting
  - **Terraform**: terraform_fmt + terraform_tflint

**⚠️ Important Warning:**
This configuration **automatically modifies your code files** during commits. The setup script will warn you about this and require confirmation.

**Best for:**

- New projects starting fresh
- Teams that want consistent, automated code formatting
- Projects where all team members agree on auto-formatting
- Codebases that benefit from strict style enforcement

### Choosing the Right Configuration

The setup script will prompt you to choose:

```
Pre-commit Configuration Selection
Choose your pre-commit configuration:

1) Security Only - Basic security checks without code formatting
2) Security + Linting - Complete code quality and security
   ⚠️  WARNING: This option will automatically modify your code files

Select option (1 or 2):
```

**Recommendation:**

- Choose **Security Only** if you're adding DevSecOps to an existing project
- Choose **Security + Linting** for new projects or if your team wants automated formatting

**Prerequisites:**

- `git` must be installed
- `rsync` must be installed (pre-installed on macOS, on Linux: `sudo apt-get install rsync` or `sudo yum install rsync`)
- `pre-commit` recommended but optional (install with: `pip install pre-commit`)

**Additional Prerequisites for Terraform Support:**

If you're using Terraform, the setup script will check for and require:

- `terraform` CLI (install: `brew install terraform` on macOS, or download from https://terraform.io/downloads)
- `tflint` (install: `brew install tflint` on macOS, or download from https://github.com/terraform-linters/tflint/releases)

**Note:** The setup script will automatically detect if you're using Terraform and validate these dependencies. For security scanning and validation, use CI/CD pipelines where proper environment setup is available.

### What Gets Added to Your Repository

The setup script copies these files:

**Configuration Directory:**

- `.devsecops/` - DevSecOps configuration directory containing:
  - `eslintrc.json` - ESLint configuration for JavaScript/TypeScript
  - `eslintignore` - ESLint exclusion patterns

**Root Configuration Files:**

- `.pre-commit-config.yaml` - Pre-commit hooks configuration (prompts if exists, creates backup)
- `.gitlab-ci.yml` - GitLab CI/CD pipeline configuration (prompts if exists, creates backup)
- `licensecheck.toml` - License compliance configuration

And automatically updates `.gitignore` with recommended entries:

```gitignore
# DevSecOps - Generated files (safe to ignore)
ferret-sast-report.json
.ash/
.eslintcache

# DevSecOps - Tool cache directories
.ruff_cache/
.mypy_cache/
.pytest_cache/
```

**Note:** The setup script automatically adds only generated files and cache directories to `.gitignore`. It does NOT add `setup.sh`, `sbom-*.json`, `licenses.json`, or `.devsecops/` to allow teams flexibility in what they commit.

**Note:** The setup script automatically removes itself after completion when downloaded and run locally. When piped directly (`curl | bash`), it never touches disk. Works with bash, sh, and zsh.

## Installation

### 1. Install pre-commit

```bash
# Using pip
pip install pre-commit

# Using Homebrew (macOS)
brew install pre-commit
```

### 2. Install the git hooks

After cloning this repository, run:

```bash
GIT_CONFIG_NOSYSTEM=1 pre-commit install
```

**Note:** The `GIT_CONFIG_NOSYSTEM=1` prefix bypasses system-level git configurations that may conflict with pre-commit installation.

This will install the pre-commit hooks into your local `.git/hooks/` directory.

### 3. (Optional) Run against all files

To run all hooks against all files in the repository:

```bash
pre-commit run --all-files
```

## What These Pre-commit Hooks Do

This configuration includes multiple layers of security scanning, code quality checks, and formatting tools organized by category:

### General Code Quality & Formatting

**Standard Pre-commit Hooks**

- `check-added-large-files`: Prevents files larger than 100MB from being committed
- `check-json`: Validates JSON file syntax
- `check-yaml`: Validates YAML file syntax
- `debug-statements`: Detects debug statements (like `pdb`, `ipdb`) in Python code
- `detect-private-key`: Scans for private keys that shouldn't be committed
- `end-of-file-fixer`: Ensures files end with a newline
- `name-tests-test`: Verifies test files follow naming conventions
- `no-commit-to-branch`: Prevents direct commits to protected branches (main and master)

**Codespell** (Security + Linting configuration only)

- Checks for common misspellings in text files
- Helps maintain professional documentation and code comments
- Runs with verbose output to show detailed spell-checking results
- `requirements-txt-fixer`: Sorts and formats Python requirements.txt files alphabetically
- `trailing-whitespace`: Removes trailing whitespace from files

### Language-Specific: Python

**Black (Python Formatter)**

- The uncompromising Python code formatter
- Automatically reformats Python code to be PEP 8 compliant
- Produces consistent, deterministic formatting across the entire project
- Only runs on `.py` files

**Ruff (Python Linter)**

- Fast Python linter written in Rust
- Replaces Flake8, isort, and other Python linting tools
- Automatically fixes issues where possible
- Extremely fast - 10-100x faster than traditional Python linters

**Python Safety**

- Checks Python dependencies for known security vulnerabilities (CVEs)
- Uses the safety-db database to identify vulnerable packages
- Scans requirements.txt files for packages with known security issues

### Language-Specific: Go

**Go Standard Tools**

- `go-fmt`: Formats Go code according to Go standards
- `go-vet`: Examines Go source code and reports suspicious constructs
- `go-imports`: Updates Go import lines, adding missing ones and removing unreferenced ones
- `go-mod-tidy`: Ensures go.mod matches the source code in the module
- Only runs on `.go` files and `go.mod`/`go.sum`

### Language-Specific: JavaScript/TypeScript

**ESLint**

- Linting and code quality tool for JavaScript and TypeScript
- Includes security plugin (`eslint-plugin-security`) for detecting security issues
- Automatically fixes issues where possible
- Runs on `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs` files
- Configuration: `.eslintrc.json` with security-focused rules

**Prettier**

- Opinionated code formatter for JavaScript, TypeScript, JSON, CSS, Markdown, and YAML
- Ensures consistent code style across the project
- Runs on `.js`, `.jsx`, `.ts`, `.tsx`, `.json`, `.css`, `.md`, `.yaml`, `.yml` files

### Language-Specific: Java

**Google Java Format**

- Formats Java code according to Google Java Style Guide
- Automatically fixes formatting issues
- Only runs on `.java` files

### Security Scanning

**ASH (Automated Security Helper)**

- Comprehensive security scanning tool that integrates multiple open-source security scanners
- Includes Bandit (Python SAST), Semgrep (multi-language SAST), detect-secrets, Checkov (IaC), and more
- Runs in pre-commit mode for fast, targeted scanning of changed files
- Managed via UV tool isolation for automatic installation and dependency management
- Provides unified security scanning across multiple languages and frameworks

**Ferret Scan**

- Sensitive data detection tool that scans files for potential PII and sensitive information
- Detects credit card numbers, passport numbers, SSNs, email addresses, phone numbers, and more
- Uses pattern matching, entropy analysis, and context-aware validation
- Scans multiple file types: Go, JavaScript, Python, Java, YAML, JSON, XML, SQL, Markdown, and shell scripts
- Configured to run with medium and high confidence levels for comprehensive detection
- Limited to specific validators: EMAIL, INTELLECTUAL_PROPERTY, IP_ADDRESS, SECRETS, SOCIAL_MEDIA
- Alternative: Place config in your `~/.ferret-scan` folder for global use

**Note:** ASH includes detect-secrets, Bandit, and Checkov, so these tools have been removed from the pre-commit configuration to avoid duplication. ASH provides a unified scanning experience with all these tools integrated.

### Infrastructure Security

**CFN Lint**

- Validates AWS CloudFormation YAML/JSON templates
- Checks against AWS CloudFormation resource provider schemas
- Validates resource properties, best practices, and proper values
- Supports AWS SAM (Serverless Application Model) transformations

**Terraform Tools**

- `terraform_fmt`: Formats Terraform files according to standard conventions (Security + Linting only)
- `terraform_tflint`: Advanced Terraform linting for best practices and potential errors
  - Configured with `verbose: true` for better visibility of results
  - Uses `--format=compact` for cleaner output
  - Uses `--force` flag to show warnings but not block commits
- Only runs on `.tf` files

**Note:** `terraform_validate` and `terraform_checkov` are intentionally excluded from pre-commit hooks due to:

- `terraform_validate` requires `terraform init` and AWS credentials, causing failures in pre-commit environment
- `terraform_checkov` requires separate checkov installation and can have PATH/environment issues
- Both tools are better suited for CI/CD pipelines where proper environment setup is available

**Note:** Checkov is now included in ASH scanning and has been removed from the standalone pre-commit hooks to avoid duplication.

### License Compliance

**LicenseCheck**

- Validates that project dependencies use approved open source licenses
- Enforces license compliance policy to prevent legal issues
- **Approved Licenses** (Permissive): MIT, Apache 2.0, BSD, ISC, Python Software Foundation, Unlicense, CC0, Boost, NCSA
- **Blocked Licenses** (Copyleft/Viral): GPL, AGPL, LGPL (all versions)
- **Configuration**: `licensecheck.toml` defines allowed and blocked licenses
- **Pre-commit Hook**: Runs automatically before each commit to check dependencies
- **CI/CD Integration**: Runs in GitLab pipeline compliance stage
- **Exit Code**: Returns non-zero (fails build) if blocked licenses are detected

## Usage

### Automatic Execution

Once installed, pre-commit hooks run automatically when you execute `git commit`. If any hook fails:

1. The commit will be blocked
2. You'll see error messages explaining what failed
3. Some hooks (like Black) will auto-fix issues
4. Review the changes and commit again

### Manual Execution

Run all hooks manually:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run black --all-files
pre-commit run bandit --all-files
```

### Skipping Hooks (Not Recommended)

In rare cases where you need to bypass hooks:

```bash
git commit --no-verify
```

**Warning**: Only skip hooks when absolutely necessary, as they protect against security vulnerabilities and code quality issues.

## Updating Hooks

To update all hooks to their latest versions:

```bash
pre-commit autoupdate
```

## Running Tools Individually

You can install and run each tool separately outside of pre-commit for testing or CI/CD pipelines:

### Black (Python Formatter)

```bash
# Install
pip install black

# Run on specific files
black file.py

# Run on directory
black src/

# Check without modifying
black --check .
```

### Detect Secrets

```bash
# Install
pip install detect-secrets

# Scan repository
detect-secrets scan

# Scan specific files
detect-secrets scan file1.py file2.js

# Output as JSON
detect-secrets scan --json
```

### ASH (Automated Security Helper)

```bash
# Install UV (package manager)
curl -sSfL https://astral.sh/uv/install.sh | sh

# Run ASH in local mode
uvx git+https://github.com/awslabs/automated-security-helper.git@v3.1.2 --mode local

# Run ASH in container mode (all tools)
uvx git+https://github.com/awslabs/automated-security-helper.git@v3.1.2 --mode container

# Run ASH in precommit mode (fast)
uvx git+https://github.com/awslabs/automated-security-helper.git@v3.1.2 --mode precommit
```

### Python Safety

```bash
# Install
pip install safety

# Check requirements file
safety check -r requirements.txt

# Check installed packages
safety check

# Generate JSON report
safety check --json
```

### Ferret Scan

```bash
# Install
pip install ferret-scan

# Scan current directory
ferret-scan .

# Scan with config file
ferret-scan --config config.yaml .

# Scan specific files
ferret-scan file1.py file2.js

# Show only medium and high confidence findings with specific checks
ferret-scan --confidence medium,high --checks EMAIL,INTELLECTUAL_PROPERTY,IP_ADDRESS,SECRETS,SOCIAL_MEDIA .
```

### Codespell

```bash
# Install
pip install codespell

# Check for misspellings
codespell

# Check specific files
codespell file1.py file2.md

# Fix misspellings automatically
codespell --write-changes

# Check with custom dictionary
codespell --dictionary custom_dict.txt
```

### CFN Lint (CloudFormation)

```bash
# Install
pip install cfn-lint

# Lint CloudFormation template
cfn-lint template.yaml

# Lint all templates in directory
cfn-lint templates/*.yaml

# Output as JSON
cfn-lint template.yaml --format json
```

### Terraform Tools

```bash
# External dependencies (must be installed separately):

# Install Terraform CLI (required for terraform_fmt)
# macOS: brew install terraform
# Linux: Download from https://terraform.io/downloads
terraform fmt

# Install TFLint (required for terraform_tflint)
# macOS: brew install tflint
# Linux/Windows: Download from https://github.com/terraform-linters/tflint/releases
tflint

# Run Terraform checks via pre-commit
pre-commit run terraform_fmt --all-files
pre-commit run terraform_tflint --all-files

# For validation and security scanning, use CI/CD pipelines:
# terraform validate (requires terraform init and AWS credentials)
# checkov -f main.tf --framework terraform (requires separate installation)
```

### LicenseCheck

```bash
# Install
pip install licensecheck

# Check licenses in current project (reads pyproject.toml or requirements.txt)
licensecheck

# Check with specific requirements file
licensecheck --requirements-paths requirements.txt

# Check and fail on incompatible licenses (for CI/CD)
licensecheck --zero

# Output as JSON
licensecheck --format json

# Show only failing packages
licensecheck --show-only-failing

# Check specific dependency groups (for Poetry/pyproject.toml)
licensecheck --groups dev test
```

## GitLab CI/CD Integration

This repository includes a GitLab CI/CD pipeline (`.gitlab-ci.yml`) that automatically runs comprehensive security scanning on every commit.

### Pipeline Features

- **ASH Security Scanning**: Comprehensive security scanning with Bandit, Semgrep, detect-secrets, Checkov, and more
- **Ferret Scan**: Specialized PII and sensitive data detection
- **GitLab Security Dashboard Integration**: Findings appear in GitLab's Vulnerability Report
- **Merge Request Widgets**: Security findings displayed in MR overview
- **SARIF/SAST Report Format**: Compatible with GitLab's security features
- **Linting Checks**: Ruff linting runs before security scans
- **License Compliance**: Automated license checking
- **Python 3.13**: Uses latest stable Python version
- **Pip Caching**: Faster builds with dependency caching

### Pipeline Stages

1. **developer_tests**: Runs ruff linting checks on all Python files
2. **security**: Runs ASH and Ferret Scan in parallel for comprehensive security coverage
3. **compliance**: Validates license compliance using LicenseCheck to ensure only approved licenses are used

### How It Works

1. **Automatic Execution**: Pipeline runs on every push to any branch
2. **Linting**: Ruff checks Python code quality and style
3. **ASH Scanning**: Comprehensive security scanning across multiple tools and languages
4. **Ferret Scan**: Specialized scanning for PII and sensitive data
5. **Report Generation**: Creates GitLab SAST/SARIF format reports
6. **Artifact Upload**: Reports uploaded to GitLab for analysis
7. **Security Dashboard**: Findings visible in Security & Compliance section

### Viewing Findings

**In Merge Requests:**

- Create a merge request from your branch
- Findings appear in the MR security widget
- Click "View full report" to see details

**In Security Dashboard:**

- Go to Security & Compliance → Vulnerability Report
- View findings from the default branch (main/master)
- Filter by severity, confidence, or file

**In Pipeline Artifacts:**

- Go to CI/CD → Pipelines → Select pipeline
- Click on `ferret-scan` job
- Download `ferret-sast-report.json` from artifacts

### Configuration

Edit `.gitlab-ci.yml` to customize:

```yaml
variables:
  PYTHON_VERSION: "3.13"
  FERRET_SCAN_CONFIDENCE: "medium,high"
  FERRET_SCAN_CHECKS: "EMAIL,INTELLECTUAL_PROPERTY,IP_ADDRESS,SECRETS,SOCIAL_MEDIA"
  FERRET_SCAN_CONFIG: ".devsecops/ferret-scan.yaml"
```

ASH configuration can be customized by overriding the `ash-sast` job or by providing ASH-specific configuration files.

## Troubleshooting

### Hooks are slow

- First run downloads and caches all tools, subsequent runs are faster
- Consider running specific hooks instead of all hooks during development

### Hook fails with installation errors

- Ensure you have Python 3.7+ installed
- All hooks run in isolated Python virtual environments
- Check individual hook documentation for specific requirements

### False positives

- Update the `.pre-commit-config.yaml` to exclude specific files or adjust arguments
- For detect-secrets, use `--exclude-files` argument to skip specific files
- Configure suppressions in `config.yaml` for Ferret Scan

### GitLab CI pipeline fails

- Check job logs for specific error messages
- Enable DEBUG_MODE for detailed output
- Verify `config.yaml` is present
- Ensure Python 3.13 image is accessible

## Setup Script Features

The standalone `setup.sh` script provides:

### Automatic Setup

- ✅ **Prerequisite Checking**: Verifies git, rsync, and pre-commit are installed
- ✅ **File Management**: Copies all required configuration files
- ✅ **Safe Overwrite Protection**: Prompts before replacing existing .pre-commit-config.yaml or .gitlab-ci.yml (creates .bak files)
- ✅ **Gitignore Updates**: Automatically adds DevSecOps entries (idempotent - safe to run multiple times)
- ✅ **Hook Updates**: Updates pre-commit hooks to latest versions
- ✅ **Error Handling**: Clear error messages with solutions

### Usage Examples

**Quick run (one-liner):**

```bash
TEMP_SETUP="$(mktemp -d)" && git clone https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git "$TEMP_SETUP/repo" && bash "$TEMP_SETUP/repo/setup.sh" && rm -rf "$TEMP_SETUP"
```

**Step-by-step (review before running):**

Create secure temp directory:

```bash
TEMP_SETUP="$(mktemp -d)"
```

Clone the repository:

```bash
git clone https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git "$TEMP_SETUP/repo"
```

Review the script:

```bash
cat "$TEMP_SETUP/repo/setup.sh"
```

Run the setup:

```bash
bash "$TEMP_SETUP/repo/setup.sh"
```

Cleanup:

```bash
rm -rf "$TEMP_SETUP"
```

**Re-run to update (if you kept setup.sh):**

```bash
./setup.sh
```

## Additional Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [Pre-commit Hooks Repository](https://github.com/pre-commit/pre-commit-hooks)
- [Black Documentation](https://black.readthedocs.io/)
- [Detect Secrets](https://github.com/Yelp/detect-secrets)
- [Bandit Documentation](https://bandit.readthedocs.io/)
- [CFN Lint](https://github.com/aws-cloudformation/cfn-lint)
- [Checkov Documentation](https://www.checkov.io/)
- [Python Safety](https://github.com/Lucas-C/pre-commit-hooks-safety)
- [Ferret Scan](https://github.com/awslabs/ferret-scan)
- [LicenseCheck](https://github.com/FHPythonUtils/LicenseCheck)
