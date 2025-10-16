#!/bin/bash
# Setup script for individual repositories to install secret leak protection
# This script should be copied to each repository and run once to set up protection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CORE_REPO_URL="https://raw.githubusercontent.com/mrrusik/gitleaks-protection-poc/main/.github/templates"
REPO_NAME=$(basename "$(git config --get remote.origin.url)" .git)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Version comparison helper function
version_compare() {
    local version1=$1
    local version2=$2
    
    # Convert versions to comparable format
    local ver1_major=$(echo "$version1" | cut -d. -f1)
    local ver1_minor=$(echo "$version1" | cut -d. -f2)
    local ver1_patch=$(echo "$version1" | cut -d. -f3)
    
    local ver2_major=$(echo "$version2" | cut -d. -f1)
    local ver2_minor=$(echo "$version2" | cut -d. -f2)
    local ver2_patch=$(echo "$version2" | cut -d. -f3)
    
    # Compare major version
    if [ "$ver1_major" -lt "$ver2_major" ]; then
        return 1
    elif [ "$ver1_major" -gt "$ver2_major" ]; then
        return 0
    fi
    
    # Compare minor version
    if [ "$ver1_minor" -lt "$ver2_minor" ]; then
        return 1
    elif [ "$ver1_minor" -gt "$ver2_minor" ]; then
        return 0
    fi
    
    # Compare patch version
    if [ "$ver1_patch" -lt "$ver2_patch" ]; then
        return 1
    fi
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "This is not a Git repository"
        exit 1
    fi

    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi

    # Check if pip is installed
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 is required but not installed"
        exit 1
    fi

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        log_error "Go is required for Gitleaks but not installed"
        log_info "Please install Go from https://golang.org/doc/install"
        exit 1
    fi

    # Check Go version compatibility
    GO_VERSION=$(go version 2>/dev/null | sed -n 's/.*go\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' || echo "0.0.0")
    REQUIRED_GO_VERSION="1.19.0"
    
    if ! version_compare "$GO_VERSION" "$REQUIRED_GO_VERSION"; then
        log_error "Go version $GO_VERSION is too old. Minimum required: $REQUIRED_GO_VERSION"
        log_info "Current Go version: $(go version)"
        log_info "Please upgrade Go from https://golang.org/doc/install"
        exit 1
    else
        log_info "Go version check passed: $GO_VERSION"
    fi

    log_success "Prerequisites check passed"
}

# Install pre-commit if not installed
install_pre_commit() {
    if ! command -v pre-commit &> /dev/null; then
        log_info "Installing pre-commit..."
        pip3 install pre-commit
        log_success "Pre-commit installed"
    else
        log_info "Pre-commit already installed: $(pre-commit --version)"
    fi
}

# Download configuration files from core repo
download_configs() {
    log_info "Downloading configuration files from core repository..."

    # Download pre-commit config
    if curl -fsSL "$CORE_REPO_URL/pre-commit-config.yaml" -o .pre-commit-config.yaml; then
        log_success "Downloaded .pre-commit-config.yaml"
    else
        log_error "Failed to download pre-commit configuration"
        exit 1
    fi

    # Download Gitleaks config
    if curl -fsSL "$CORE_REPO_URL/gitleaks.toml" -o .gitleaks.toml; then
        log_success "Downloaded .gitleaks.toml"
    else
        log_error "Failed to download Gitleaks configuration"
        exit 1
    fi

    log_info "Simplified setup - no additional tracking scripts needed"
}

# Install pre-commit hooks
install_hooks() {
    log_info "Installing pre-commit hooks..."

    # Install hooks
    if pre-commit install --hook-type pre-commit --hook-type prepare-commit-msg; then
        log_success "Pre-commit hooks installed"
    else
        log_error "Failed to install pre-commit hooks"
        exit 1
    fi

    # Run pre-commit on all files for first time
    log_info "Running initial pre-commit scan (this may take a while)..."
    if pre-commit run --all-files; then
        log_success "Initial scan completed successfully"
    else
        log_warning "Initial scan found issues - please fix them and commit"
    fi
}

# Create .secrets.baseline for detect-secrets
create_secrets_baseline() {
    log_info "Creating secrets baseline..."

    if command -v detect-secrets &> /dev/null; then
        detect-secrets scan . > .secrets.baseline
        log_success "Secrets baseline created"
    else
        log_info "detect-secrets not installed, installing..."
        pip3 install detect-secrets
        detect-secrets scan . > .secrets.baseline
        log_success "detect-secrets installed and baseline created"
    fi
}

# Update .gitignore
update_gitignore() {
    log_info "Updating .gitignore..."

    # Create .gitignore if it doesn't exist
    touch .gitignore

    # Add entries if they don't exist
    if ! grep -q "__pycache__" .gitignore; then
        echo "__pycache__/" >> .gitignore
        log_info "Added __pycache__/ to .gitignore"
    fi

    log_success ".gitignore updated"
}

# Create repository protection marker
create_protection_marker() {
    log_info "Creating repository protection marker..."

    cat > .repo-protection-config.json << EOF
{
  "protection_enabled": true,
  "setup_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "setup_version": "1.0",
  "repository": "$REPO_NAME",
  "features": {
    "pre_commit_gitleaks": true,
    "execution_tracking": true,
    "detect_secrets": true
  },
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    log_success "Protection marker created"
}

# Test the setup
test_setup() {
    log_info "Testing the setup..."

    # Test pre-commit
    if pre-commit run --all-files > /dev/null 2>&1; then
        log_success "Pre-commit test passed"
    else
        log_warning "Pre-commit test had issues (this may be normal for first run)"
    fi

    # Test Gitleaks
    if command -v gitleaks &> /dev/null; then
        if gitleaks detect --no-git > /dev/null 2>&1; then
            log_success "Gitleaks test passed"
        else
            log_warning "Gitleaks detected potential secrets (please review)"
        fi
    else
        log_warning "Gitleaks not available in PATH (will be installed by pre-commit on first run)"
    fi
}

# Main execution
main() {
    log_info "Setting up secret leak protection for repository: $REPO_NAME"
    echo "========================================"

    check_prerequisites
    install_pre_commit
    download_configs
    # create_secrets_baseline  # Disabled for simplified setup
    install_hooks
    update_gitignore
    # create_protection_marker  # Disabled for simplified setup
    test_setup

    echo "========================================"
    log_success "Simplified repository protection setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review and commit the new configuration files"
    echo "2. All future commits will be automatically scanned for secrets with Gitleaks"
    echo "3. If you need to bypass the scan (emergency only), use: git commit --no-verify"
    echo "4. To test the setup, try: pre-commit run --all-files"
    echo
    log_info "Note: This simplified setup uses Gitleaks only, without detect-secrets baseline or tracking files"
}

# Help function
show_help() {
    echo "Repository Secret Leak Protection Setup"
    echo "Usage: $0 [options]"
    echo
    echo "Prerequisites:"
    echo "- Git repository"
    echo "- Python 3 and pip3"
    echo "- Go >= 1.19.0 (required for Gitleaks)"
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  --test-only   Only run tests, don't install"
    echo "  --force       Force reinstall even if already configured"
    echo
    echo "This script will:"
    echo "1. Check prerequisites (Git, Python, Go version)"
    echo "2. Install pre-commit if not present"
    echo "3. Download configuration files from core repository"
    echo "4. Set up Gitleaks for secret scanning (simplified setup)"
    echo "5. Configure pre-commit hooks"
    echo "6. Update .gitignore with necessary entries"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --test-only)
        test_setup
        exit 0
        ;;
    --force)
        log_warning "Force mode enabled - will overwrite existing configuration"
        main
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
