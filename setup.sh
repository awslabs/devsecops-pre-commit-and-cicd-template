#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# DevSecOps Setup Script
# Downloads and configures pre-commit hooks and CI/CD pipeline

set -e

VERSION="1.0.0"
REPO_URL="https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git"
TEMP_DIR="$(mktemp -d)/DevSecOps"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo -e "${BLUE}  DevSecOps Setup Script v${VERSION}${NC}"
echo "================================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
MISSING_PREREQS=0

if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}✗ git is not installed${NC}"
    MISSING_PREREQS=1
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo -e "${RED}✗ rsync is not installed${NC}"
    echo "  Install with: brew install rsync (macOS) or apt-get install rsync (Linux)"
    MISSING_PREREQS=1
fi

if [ $MISSING_PREREQS -eq 1 ]; then
    exit 1
fi

if ! command -v pre-commit >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ pre-commit is not installed${NC}"
    echo "  Install with: pip install pre-commit"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ All prerequisites installed${NC}"
fi

echo ""

# Check if user is using Terraform
echo -e "${BLUE}Terraform Usage Check${NC}"
read -p "Are you using Terraform in this project? (y/n) " -n 1 -r
echo ""

USE_TERRAFORM=false
if [[ $REPLY =~ ^[Yy]$ ]]; then
    USE_TERRAFORM=true
    echo "Checking Terraform dependencies..."

    TERRAFORM_MISSING=0
    MISSING_TERRAFORM_TOOLS=()

    # Check for terraform CLI (required for terraform_fmt)
    if ! command -v terraform >/dev/null 2>&1; then
        echo -e "${RED}✗ terraform CLI is not installed${NC}"
        MISSING_TERRAFORM_TOOLS+=("terraform CLI")
        TERRAFORM_MISSING=1
    else
        echo -e "${GREEN}✓ terraform CLI found${NC}"
    fi

    # Check for tflint (not available via pip, must be installed separately)
    if ! command -v tflint >/dev/null 2>&1; then
        echo -e "${RED}✗ tflint is not installed${NC}"
        MISSING_TERRAFORM_TOOLS+=("tflint")
        TERRAFORM_MISSING=1
    else
        echo -e "${GREEN}✓ tflint found${NC}"
    fi

    # Note: Only checking external dependencies (terraform CLI and tflint)
    # Other tools are automatically installed by pre-commit

    if [ $TERRAFORM_MISSING -eq 1 ]; then
        echo ""
        echo -e "${RED}✗ Missing Terraform dependencies${NC}"
        echo ""
        echo "The following tools are required for Terraform support but are not installed:"
        for tool in "${MISSING_TERRAFORM_TOOLS[@]}"; do
            case $tool in
                "terraform CLI")
                    echo -e "  • ${YELLOW}terraform CLI${NC}"
                    echo "    macOS: brew install terraform"
                    echo "    Linux: Download from https://terraform.io/downloads"
                    echo "    Windows: Download from https://terraform.io/downloads"
                    ;;
                "tflint")
                    echo -e "  • ${YELLOW}tflint${NC}"
                    echo "    macOS: brew install tflint"
                    echo "    Linux/Windows: Download from https://github.com/terraform-linters/tflint/releases"
                    ;;

            esac
            echo ""
        done
        echo -e "${YELLOW}Please install the missing dependencies and re-run this script.${NC}"
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ All Terraform dependencies found${NC}"
    fi
else
    echo -e "${BLUE}ℹ Skipping Terraform dependency checks${NC}"
fi

echo ""

# Clone repository
echo "Cloning DevSecOps repository..."
if ! git clone "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
    echo -e "${RED}✗ Failed to clone repository${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Repository Access Required:${NC}"
    echo "  Please ensure you have access to the repository."
    echo ""
    echo "  Steps to resolve:"
    echo "  1. Verify the repository URL is correct"
    echo "  2. Ensure you have proper authentication (SSH keys or credentials)"
    echo "  3. Set DEVSECOPS_REPO_URL environment variable if using a custom URL"
    echo "  4. Re-run this script: ${YELLOW}./setup.sh${NC}"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Repository cloned${NC}"

# Copy .devsecops directory
echo "Copying DevSecOps configuration directory..."
if ! rsync -a "$TEMP_DIR/.devsecops/" .devsecops/ 2>/dev/null; then
    echo -e "${RED}✗ Failed to copy .devsecops directory${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo -e "${GREEN}✓ .devsecops/ directory copied${NC}"

# Copy .github directory
echo "Copying GitHub Actions workflows..."
if [ -d "$TEMP_DIR/.github" ]; then
    if ! rsync -a "$TEMP_DIR/.github/" .github/ 2>/dev/null; then
        echo -e "${RED}✗ Failed to copy .github directory${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    echo -e "${GREEN}✓ .github/ directory copied${NC}"
else
    echo -e "${YELLOW}⚠ .github directory not found in template (skipping)${NC}"
fi

# Copy licensecheck.toml (always safe to copy)
echo "Copying licensecheck.toml..."
if ! cp "$TEMP_DIR/licensecheck.toml" . 2>/dev/null; then
    echo -e "${RED}✗ Failed to copy licensecheck.toml${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo -e "${GREEN}✓ licensecheck.toml copied${NC}"

# Handle .pre-commit-config.yaml with user selection
echo ""
echo -e "${BLUE}Pre-commit Configuration Selection${NC}"
echo "Choose your pre-commit configuration:"
echo ""
echo "1) Security Only - Basic security checks without code formatting"
echo "   • Security scanning (ASH, Ferret)"
echo "   • License compliance"
echo "   • Basic code quality checks"
echo "   • No automatic code formatting"
echo ""
echo "2) Security + Linting - Complete code quality and security"
echo "   • All security checks from option 1"
echo "   • Automatic code formatting (Black, Prettier, etc.)"
echo "   • Language-specific linting (ESLint, Go fmt, etc.)"
echo -e "   ${RED}⚠️  WARNING: This option will automatically modify your code files${NC}"
echo ""

while true; do
    read -p "Select option (1 or 2): " -n 1 -r
    echo ""
    case $REPLY in
        1)
            CONFIG_TYPE="security"
            CONFIG_FILE=".pre-commit-config-security.yaml"
            echo -e "${GREEN}✓ Selected: Security Only configuration${NC}"
            break
            ;;
        2)
            CONFIG_TYPE="security-linting"
            CONFIG_FILE=".pre-commit-config-security-linting.yaml"
            echo -e "${YELLOW}⚠️  WARNING: The selected configuration will automatically format and modify your code files during commits.${NC}"
            echo "   This includes:"
            echo "   • Python: Black formatting"
            echo "   • JavaScript/TypeScript: ESLint fixes + Prettier formatting"
            echo "   • Go: gofmt + goimports formatting"
            echo "   • Java: Pretty formatting"
            echo ""
            read -p "Continue with auto-formatting configuration? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}✓ Selected: Security + Linting configuration${NC}"
                break
            else
                echo "Please select again:"
                continue
            fi
            ;;
        *)
            echo "Invalid selection. Please choose 1 or 2."
            ;;
    esac
done

# Backup existing config if it exists
if [ -f ".pre-commit-config.yaml" ]; then
    echo ""
    echo -e "${YELLOW}⚠ .pre-commit-config.yaml already exists in this repository${NC}"
    echo "Backing up existing .pre-commit-config.yaml to .pre-commit-config.yaml.bak..."
    mv .pre-commit-config.yaml .pre-commit-config.yaml.bak
    echo -e "${GREEN}✓ Existing configuration backed up${NC}"
fi

# Copy the selected configuration
echo "Installing selected pre-commit configuration..."
if [ -f "$TEMP_DIR/$CONFIG_FILE" ]; then
    cp "$TEMP_DIR/$CONFIG_FILE" .pre-commit-config.yaml
    if [ "$USE_TERRAFORM" = true ]; then
        echo -e "${GREEN}✓ Pre-commit configuration installed with Terraform support${NC}"
        echo -e "${BLUE}ℹ Terraform hooks will run automatically when .tf files are present${NC}"
    else
        echo -e "${GREEN}✓ Pre-commit configuration installed${NC}"
        echo -e "${BLUE}ℹ Terraform hooks are included but will only run if .tf files are added later${NC}"
    fi
else
    echo -e "${RED}✗ Configuration file $CONFIG_FILE not found in repository${NC}"
    echo "Using default configuration from repository..."
    if cp "$TEMP_DIR/.pre-commit-config.yaml" . 2>/dev/null; then
        echo -e "${GREEN}✓ Default .pre-commit-config.yaml copied${NC}"
    else
        echo -e "${YELLOW}⚠ Could not copy .pre-commit-config.yaml (continuing)${NC}"
    fi
fi

# Handle .gitlab-ci.yml separately with user prompt
echo ""
if [ -f ".gitlab-ci.yml" ]; then
    echo -e "${YELLOW}⚠ .gitlab-ci.yml already exists in this repository${NC}"
    echo ""
    read -p "Do you want to replace it with DevSecOps .gitlab-ci.yml? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Backing up existing .gitlab-ci.yml to .gitlab-ci.yml.bak..."
        mv .gitlab-ci.yml .gitlab-ci.yml.bak
        cp "$TEMP_DIR/.gitlab-ci.yml" .
        echo -e "${GREEN}✓ .gitlab-ci.yml replaced (backup saved as .gitlab-ci.yml.bak)${NC}"
    else
        echo -e "${BLUE}ℹ Keeping existing .gitlab-ci.yml${NC}"
        echo -e "${YELLOW}⚠ Note: You may need to manually integrate DevSecOps stages into your existing pipeline${NC}"
    fi
else
    echo "Copying .gitlab-ci.yml..."
    if cp "$TEMP_DIR/.gitlab-ci.yml" . 2>/dev/null; then
        echo -e "${GREEN}✓ .gitlab-ci.yml copied${NC}"
    else
        echo -e "${YELLOW}⚠ Could not copy .gitlab-ci.yml (continuing)${NC}"
    fi
fi



# Cleanup
rm -rf "$TEMP_DIR"

# Update .gitignore to exclude generated files
echo ""
echo "Updating .gitignore..."

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    touch .gitignore
    echo -e "${GREEN}✓ Created .gitignore${NC}"
fi

# Check if DevSecOps section already exists
if ! grep -q "# DevSecOps - Generated files" .gitignore 2>/dev/null; then
        cat >> .gitignore << 'EOF'

# DevSecOps - Generated files (safe to ignore)
ferret-sast-report.json
.ash/
.eslintcache

# DevSecOps - Tool cache directories
.ruff_cache/
.mypy_cache/
.pytest_cache/
EOF
        echo -e "${GREEN}✓ Added DevSecOps generated file entries to .gitignore${NC}"

        echo ""
        echo -e "${YELLOW}Note: .devsecops/ and setup.sh were NOT added to .gitignore${NC}"
        echo "  • For internal Amazon repos: You can commit these files to share with your team"
    echo -e "${GREEN}✓ Added DevSecOps entries to .gitignore${NC}"
else
    echo -e "${GREEN}✓ .gitignore already contains DevSecOps entries${NC}"
fi

# Update hooks if pre-commit is installed
if command -v pre-commit >/dev/null 2>&1; then
    echo ""
    echo "Updating pre-commit hooks to latest versions..."
    if pre-commit autoupdate 2>/dev/null; then
        echo -e "${GREEN}✓ Hooks updated successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Could not update hooks (continuing)${NC}"
    fi
fi

# Summary
echo ""
echo "================================================"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Files added/updated in your repository:"
echo "  • .devsecops/ (configuration directory)"
echo "    - eslintrc.json"
echo "    - eslintignore"
echo "  • .github/ (GitHub Actions workflows)"
echo "    - workflows/security-compliance.yml"
echo "  • .pre-commit-config.yaml (${CONFIG_TYPE} configuration)"
echo "  • .gitlab-ci.yml"
echo "  • licensecheck.toml"
echo "  • .gitignore (updated with DevSecOps entries)"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review changes: ${YELLOW}git status${NC}"

if command -v pre-commit >/dev/null 2>&1; then
    echo -e "  2. Install hooks: ${YELLOW}GIT_CONFIG_NOSYSTEM=1 pre-commit install${NC}"
    echo -e "  3. Test hooks: ${YELLOW}pre-commit run --all-files${NC}"
else
    echo -e "  2. Install pre-commit: ${YELLOW}pip install pre-commit${NC}"
    echo -e "  3. Install hooks: ${YELLOW}GIT_CONFIG_NOSYSTEM=1 pre-commit install${NC}"
    echo -e "  4. Test hooks: ${YELLOW}pre-commit run --all-files${NC}"
fi

# Cleanup: Remove setup.sh if it was downloaded (not piped)
# Works with bash (BASH_SOURCE), zsh/sh ($0), and handles piped execution
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if [ -n "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "bash" ] && [ "$SCRIPT_PATH" != "sh" ] && [ "$SCRIPT_PATH" != "-bash" ] && [ "$SCRIPT_PATH" != "-sh" ]; then
    SCRIPT_NAME="$(basename "$SCRIPT_PATH" 2>/dev/null)"
    if [ "$SCRIPT_NAME" = "setup.sh" ] && [ -f "$SCRIPT_PATH" ]; then
        echo -e "${YELLOW}Cleaning up...${NC}"
        echo "Removing setup.sh from repository..."
        rm -f "$SCRIPT_PATH"
        echo -e "${GREEN}✓ Setup script removed${NC}"
        echo ""
    fi
fi
