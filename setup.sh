#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# DevSecOps Setup Script
# Downloads and configures pre-commit hooks and CI/CD pipeline

set -e

VERSION="1.0.0"
REPO_URL="https://github.com/awslabs/devsecops-pre-commit-and-cicd-template.git"
TEMP_DIR="$(mktemp -d)/DevSecOps"

# Ensure temp directory is always cleaned up on exit
TEMP_PARENT="$(dirname "$TEMP_DIR")"
trap 'rm -rf "$TEMP_PARENT"' EXIT

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

# ============================================================================
# PROACTIVE PROJECT TYPE DETECTION
# ============================================================================
echo -e "${BLUE}Detecting Project Type...${NC}"
echo ""

DETECTED_TERRAFORM=false
DETECTED_NODE=false
DETECTED_GO=false
DETECTED_JAVA=false

# Detect Terraform
if [ -n "$(find . -maxdepth 3 -name '*.tf' -print -quit 2>/dev/null)" ]; then
    DETECTED_TERRAFORM=true
    echo -e "${BLUE}✓ Detected Terraform files (.tf)${NC}"
fi

# Detect Node.js/JavaScript/TypeScript (package.json is the reliable indicator)
if [ -f "package.json" ]; then
    DETECTED_NODE=true
    echo -e "${BLUE}✓ Detected Node.js project (package.json)${NC}"
elif [ -f "tsconfig.json" ]; then
    DETECTED_NODE=true
    echo -e "${BLUE}✓ Detected TypeScript project (tsconfig.json)${NC}"
fi

# Detect Go
if [ -f "go.mod" ] || [ -n "$(find . -maxdepth 3 -name '*.go' -print -quit 2>/dev/null)" ]; then
    DETECTED_GO=true
    echo -e "${BLUE}✓ Detected Go project${NC}"
fi

# Detect Java
if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -n "$(find . -maxdepth 3 -name '*.java' -print -quit 2>/dev/null)" ]; then
    DETECTED_JAVA=true
    echo -e "${BLUE}✓ Detected Java project${NC}"
fi

if [ "$DETECTED_TERRAFORM" = false ] && [ "$DETECTED_NODE" = false ] && [ "$DETECTED_GO" = false ] && [ "$DETECTED_JAVA" = false ]; then
    echo -e "${YELLOW}ℹ No specific project type detected (Python-only or other)${NC}"
fi

echo ""

# ============================================================================
# DEPENDENCY VALIDATION
# ============================================================================
echo -e "${BLUE}Validating Dependencies...${NC}"
echo ""

MISSING_DEPS=0
MISSING_TOOLS=()
MISSING_INSTRUCTIONS=()

# Terraform dependencies
if [ "$DETECTED_TERRAFORM" = true ]; then
    echo "Checking Terraform dependencies..."

    if ! command -v terraform >/dev/null 2>&1; then
        echo -e "${RED}✗ terraform CLI is not installed${NC}"
        MISSING_TOOLS+=("terraform")
        MISSING_INSTRUCTIONS+=("Terraform CLI|macOS: brew install terraform|Linux: Download from https://terraform.io/downloads|Windows: Download from https://terraform.io/downloads")
        MISSING_DEPS=1
    else
        echo -e "${GREEN}✓ terraform CLI found${NC}"
    fi

    if ! command -v tflint >/dev/null 2>&1; then
        echo -e "${RED}✗ tflint is not installed${NC}"
        MISSING_TOOLS+=("tflint")
        MISSING_INSTRUCTIONS+=("tflint|macOS: brew install tflint|Linux/Windows: Download from https://github.com/terraform-linters/tflint/releases")
        MISSING_DEPS=1
    else
        echo -e "${GREEN}✓ tflint found${NC}"
    fi
fi

# Node.js dependencies
if [ "$DETECTED_NODE" = true ]; then
    echo "Checking Node.js dependencies..."

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}✗ Node.js is not installed${NC}"
        MISSING_TOOLS+=("node")
        MISSING_INSTRUCTIONS+=("Node.js|macOS: brew install node|Linux: Use your package manager (apt/yum) or download from https://nodejs.org|Windows: Download from https://nodejs.org")
        MISSING_DEPS=1
    else
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✓ Node.js found ($NODE_VERSION)${NC}"
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}✗ npm is not installed${NC}"
        MISSING_TOOLS+=("npm")
        MISSING_INSTRUCTIONS+=("npm|Typically installed with Node.js|If missing, reinstall Node.js from https://nodejs.org")
        MISSING_DEPS=1
    else
        NPM_VERSION=$(npm --version)
        echo -e "${GREEN}✓ npm found (v$NPM_VERSION)${NC}"
    fi

    # Check if package.json exists and node_modules is missing
    if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}⚠ package.json found but node_modules is missing${NC}"
        echo -e "${YELLOW}  Run 'npm install' before committing (ESLint hooks need it)${NC}"
    elif [ -f "package.json" ] && [ -d "node_modules" ]; then
        echo -e "${GREEN}✓ node_modules found${NC}"
    fi
fi

# Go dependencies
if [ "$DETECTED_GO" = true ]; then
    echo "Checking Go dependencies..."

    if ! command -v go >/dev/null 2>&1; then
        echo -e "${RED}✗ Go is not installed${NC}"
        MISSING_TOOLS+=("go")
        MISSING_INSTRUCTIONS+=("Go|macOS: brew install go|Linux: Download from https://go.dev/dl/|Windows: Download from https://go.dev/dl/")
        MISSING_DEPS=1
    else
        GO_VERSION=$(go version | awk '{print $3}')
        echo -e "${GREEN}✓ Go found ($GO_VERSION)${NC}"
    fi
fi

# Java dependencies
if [ "$DETECTED_JAVA" = true ]; then
    echo "Checking Java dependencies..."

    if ! command -v java >/dev/null 2>&1; then
        echo -e "${RED}✗ Java is not installed${NC}"
        MISSING_TOOLS+=("java")
        MISSING_INSTRUCTIONS+=("Java JDK|macOS: brew install openjdk|Linux: apt-get install default-jdk or yum install java-devel|Windows: Download from https://adoptium.net/")
        MISSING_DEPS=1
    else
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ Java found ($JAVA_VERSION)${NC}"
    fi
fi

# If any dependencies are missing, show detailed instructions and exit
if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ MISSING REQUIRED DEPENDENCIES${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "The following tools/dependencies are required but not found:"
    echo ""

    for instruction in "${MISSING_INSTRUCTIONS[@]}"; do
        IFS='|' read -r tool_name mac_install linux_install windows_install <<< "$instruction"
        echo -e "${YELLOW}▸ ${tool_name}${NC}"
        echo "  $mac_install"
        if [ -n "$linux_install" ]; then
            echo "  $linux_install"
        fi
        if [ -n "$windows_install" ]; then
            echo "  $windows_install"
        fi
        echo ""
    done

    echo -e "${BLUE}After installing the missing dependencies, re-run this script:${NC}"
    echo -e "  ${YELLOW}./setup.sh${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All required dependencies are installed${NC}"
echo ""

# Clone repository
echo "Cloning DevSecOps repository..."
if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
    echo -e "${RED}✗ Failed to clone repository${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Repository Access Required:${NC}"
    echo "  Please ensure you have access to the repository."
    echo ""
    echo "  Steps to resolve:"
    echo "  1. Verify the repository URL is correct"
    echo "  2. Ensure you have proper authentication (SSH keys or credentials)"
    echo "  3. Re-run this script: ${YELLOW}./setup.sh${NC}"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Repository cloned${NC}"

# Copy .devsecops directory
echo "Copying DevSecOps configuration directory..."
if ! rsync -a "$TEMP_DIR/.devsecops/" .devsecops/ 2>/dev/null; then
    echo -e "${RED}✗ Failed to copy .devsecops directory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ .devsecops/ directory copied${NC}"

# ============================================================================
# CI/CD PLATFORM SELECTION
# ============================================================================
echo ""
echo -e "${BLUE}CI/CD Platform Selection${NC}"
echo "Which CI/CD platform(s) do you use?"
echo ""
echo "1) GitHub Actions"
echo "2) GitLab CI/CD"
echo "3) Azure DevOps Pipelines"
echo "4) All of the above"
echo "5) None (skip CI/CD pipeline setup)"
echo ""

while true; do
    read -p "Select option (1-5): " -n 1 -r
    echo ""
    case $REPLY in
        1) INSTALL_GITHUB=true; INSTALL_GITLAB=false; INSTALL_AZURE=false; break ;;
        2) INSTALL_GITHUB=false; INSTALL_GITLAB=true; INSTALL_AZURE=false; break ;;
        3) INSTALL_GITHUB=false; INSTALL_GITLAB=false; INSTALL_AZURE=true; break ;;
        4) INSTALL_GITHUB=true; INSTALL_GITLAB=true; INSTALL_AZURE=true; break ;;
        5) INSTALL_GITHUB=false; INSTALL_GITLAB=false; INSTALL_AZURE=false; break ;;
        *) echo "Invalid selection. Please choose 1-5." ;;
    esac
done

# Copy GitHub Actions workflows
if [ "$INSTALL_GITHUB" = true ]; then
    echo ""
    echo "Copying GitHub Actions workflows..."
    if [ -d "$TEMP_DIR/.github" ]; then
        if ! rsync -a "$TEMP_DIR/.github/" .github/ 2>/dev/null; then
            echo -e "${RED}✗ Failed to copy .github directory${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ .github/ directory copied${NC}"
    else
        echo -e "${YELLOW}⚠ .github directory not found in template (skipping)${NC}"
    fi
fi

# Copy licensecheck.toml (always safe to copy)
echo "Copying licensecheck.toml..."
if ! cp "$TEMP_DIR/licensecheck.toml" . 2>/dev/null; then
    echo -e "${RED}✗ Failed to copy licensecheck.toml${NC}"
    exit 1
fi
echo -e "${GREEN}✓ licensecheck.toml copied${NC}"

# Handle .pre-commit-config.yaml
echo ""
CONFIG_SKIPPED=false

# Check if existing config exists FIRST, before asking which type
if [ -f ".pre-commit-config.yaml" ]; then
    echo -e "${YELLOW}⚠ .pre-commit-config.yaml already exists in this repository${NC}"
    echo ""
    read -p "Do you want to replace it with the DevSecOps configuration? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Backing up existing .pre-commit-config.yaml to .pre-commit-config.yaml.bak..."
        mv .pre-commit-config.yaml .pre-commit-config.yaml.bak
        echo -e "${GREEN}✓ Existing configuration backed up${NC}"
    else
        echo -e "${BLUE}ℹ Keeping existing .pre-commit-config.yaml${NC}"
        echo -e "${YELLOW}⚠ Note: You may need to manually integrate DevSecOps hooks into your existing config${NC}"
        CONFIG_SKIPPED=true
    fi
fi

# Only show selection menu if we're actually installing a new config
if [ "$CONFIG_SKIPPED" = false ]; then
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

    # Copy the selected configuration
    if [ -f "$TEMP_DIR/$CONFIG_FILE" ]; then
        echo "Installing selected pre-commit configuration..."
        cp "$TEMP_DIR/$CONFIG_FILE" .pre-commit-config.yaml
        if [ "$DETECTED_TERRAFORM" = true ]; then
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
fi

# Handle .gitlab-ci.yml (only if selected)
if [ "$INSTALL_GITLAB" = true ]; then
    echo ""
    if [ -f ".gitlab-ci.yml" ]; then
        echo -e "${YELLOW}⚠ .gitlab-ci.yml already exists in this repository${NC}"
        echo ""
        read -p "Do you want to replace it with DevSecOps .gitlab-ci.yml? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Backing up existing .gitlab-ci.yml to .gitlab-ci.yml.bak..."
            mv .gitlab-ci.yml .gitlab-ci.yml.bak
            if cp "$TEMP_DIR/.gitlab-ci.yml" . 2>/dev/null; then
                echo -e "${GREEN}✓ .gitlab-ci.yml replaced (backup saved as .gitlab-ci.yml.bak)${NC}"
            else
                echo -e "${RED}✗ Failed to copy .gitlab-ci.yml from template${NC}"
                echo "  Restoring backup..."
                mv .gitlab-ci.yml.bak .gitlab-ci.yml
                echo -e "${YELLOW}⚠ Original .gitlab-ci.yml restored${NC}"
            fi
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
fi

# Handle azure-pipelines.yml (only if selected)
if [ "$INSTALL_AZURE" = true ]; then
    echo ""
    if [ -f "azure-pipelines.yml" ]; then
        echo -e "${YELLOW}⚠ azure-pipelines.yml already exists in this repository${NC}"
        echo ""
        read -p "Do you want to replace it with DevSecOps azure-pipelines.yml? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Backing up existing azure-pipelines.yml to azure-pipelines.yml.bak..."
            mv azure-pipelines.yml azure-pipelines.yml.bak
            if cp "$TEMP_DIR/azure-pipelines.yml" . 2>/dev/null; then
                echo -e "${GREEN}✓ azure-pipelines.yml replaced (backup saved as azure-pipelines.yml.bak)${NC}"
            else
                echo -e "${RED}✗ Failed to copy azure-pipelines.yml from template${NC}"
                echo "  Restoring backup..."
                mv azure-pipelines.yml.bak azure-pipelines.yml
                echo -e "${YELLOW}⚠ Original azure-pipelines.yml restored${NC}"
            fi
        else
            echo -e "${BLUE}ℹ Keeping existing azure-pipelines.yml${NC}"
            echo -e "${YELLOW}⚠ Note: You may need to manually integrate DevSecOps stages into your existing pipeline${NC}"
        fi
    else
        echo "Copying azure-pipelines.yml..."
        if cp "$TEMP_DIR/azure-pipelines.yml" . 2>/dev/null; then
            echo -e "${GREEN}✓ azure-pipelines.yml copied${NC}"
        else
            echo -e "${YELLOW}⚠ Could not copy azure-pipelines.yml (continuing)${NC}"
        fi
    fi
fi

# Cleanup temp directory (trap handles this too, but be explicit)
rm -rf "$TEMP_PARENT"

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
ferret-scan-results.sarif
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
else
    echo -e "${GREEN}✓ .gitignore already contains DevSecOps entries${NC}"
fi

# Optionally update hooks if pre-commit is installed and we installed a new config
if command -v pre-commit >/dev/null 2>&1 && [ "$CONFIG_SKIPPED" != true ]; then
    echo ""
    echo -e "${YELLOW}⚠ Running 'pre-commit autoupdate' will update hook versions to latest.${NC}"
    echo "  This may change versions from the template defaults."
    read -p "Run pre-commit autoupdate now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating pre-commit hooks to latest versions..."
        if pre-commit autoupdate 2>/dev/null; then
            echo -e "${GREEN}✓ Hooks updated successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Could not update hooks (continuing)${NC}"
        fi
    else
        echo -e "${BLUE}ℹ Skipping autoupdate — using template versions${NC}"
    fi
fi

# Summary
echo ""
echo "================================================"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "================================================"
echo ""

# Show detected project types
if [ "$DETECTED_TERRAFORM" = true ] || [ "$DETECTED_NODE" = true ] || [ "$DETECTED_GO" = true ] || [ "$DETECTED_JAVA" = true ]; then
    echo -e "${BLUE}Detected project types:${NC}"
    [ "$DETECTED_TERRAFORM" = true ] && echo "  • Terraform"
    [ "$DETECTED_NODE" = true ] && echo "  • Node.js/JavaScript/TypeScript"
    [ "$DETECTED_GO" = true ] && echo "  • Go"
    [ "$DETECTED_JAVA" = true ] && echo "  • Java"
    echo ""
fi

echo "Files added/updated in your repository:"
echo "  • .devsecops/ (configuration directory)"
echo "    - eslintrc.json"
echo "    - eslintignore"
[ "$INSTALL_GITHUB" = true ] && echo "  • .github/ (GitHub Actions workflows)"
[ "$INSTALL_GITHUB" = true ] && echo "    - workflows/security-compliance.yml"
if [ "$CONFIG_SKIPPED" = true ]; then
    echo "  • .pre-commit-config.yaml (kept existing)"
else
    echo "  • .pre-commit-config.yaml (${CONFIG_TYPE} configuration)"
fi
[ "$INSTALL_GITLAB" = true ] && echo "  • .gitlab-ci.yml"
[ "$INSTALL_AZURE" = true ] && echo "  • azure-pipelines.yml"
echo "  • licensecheck.toml"
echo "  • .gitignore (updated with DevSecOps entries)"
echo ""

# Add Node.js specific warning if detected
if [ "$DETECTED_NODE" = true ] && [ -f "package.json" ]; then
    echo -e "${YELLOW}⚠ IMPORTANT for Node.js projects:${NC}"
    echo -e "  Before committing, ensure you run: ${YELLOW}npm install${NC}"
    echo "  ESLint pre-commit hooks require node_modules to be present"
    echo ""
fi

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

# Cleanup: Remove setup.sh if it was downloaded into a target project
# Only deletes if the file is NOT tracked by git (i.e., not part of the repo source)
# Works with bash (BASH_SOURCE), zsh/sh ($0), and handles piped execution
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if [ -n "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "bash" ] && [ "$SCRIPT_PATH" != "sh" ] && [ "$SCRIPT_PATH" != "-bash" ] && [ "$SCRIPT_PATH" != "-sh" ]; then
    SCRIPT_NAME="$(basename "$SCRIPT_PATH" 2>/dev/null)"
    if [ "$SCRIPT_NAME" = "setup.sh" ] && [ -f "$SCRIPT_PATH" ] && ! git ls-files --error-unmatch "$SCRIPT_PATH" >/dev/null 2>&1; then
        echo -e "${YELLOW}Cleaning up...${NC}"
        echo "Removing setup.sh from repository..."
        rm -f "$SCRIPT_PATH"
        echo -e "${GREEN}✓ Setup script removed${NC}"
        echo ""
    fi
fi
