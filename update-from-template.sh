#!/bin/bash

# WordPress Template Update Script
# Updates client repository from starter template using semantic versioning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

show_help() {
    echo "WordPress Template Update Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check                    Check for available updates"
    echo "  --to-version VERSION       Update to specific version (e.g., v1.2.0)"
    echo "  --latest                   Update to latest available version"
    echo "  --list-versions           Show all available versions"
    echo "  --force                   Force update even if no changes detected"
    echo "  --dry-run                 Show what would be updated without applying changes"
    echo "  --template-repo URL       Override template repository URL"
    echo "  --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --check"
    echo "  $0 --to-version v1.2.0"
    echo "  $0 --latest --dry-run"
}

# Default values
TEMPLATE_REPO_URL=""
CURRENT_VERSION=""
TARGET_VERSION=""
DRY_RUN=false
FORCE_UPDATE=false
TEMP_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            ACTION="check"
            shift
            ;;
        --to-version)
            ACTION="update"
            TARGET_VERSION="$2"
            shift 2
            ;;
        --latest)
            ACTION="update_latest"
            shift
            ;;
        --list-versions)
            ACTION="list_versions"
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --template-repo)
            TEMPLATE_REPO_URL="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    log_error "This script must be run from the root of a git repository"
    exit 1
fi

# Load environment variables and get current version
load_current_version() {
    if [ -f ".env" ]; then
        CURRENT_VERSION=$(grep "^STARTER_VERSION=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    if [ -z "$CURRENT_VERSION" ]; then
        log_warn "STARTER_VERSION not found in .env file"
        CURRENT_VERSION="unknown"
    fi
    
    log_info "Current template version: $CURRENT_VERSION"
}

# Get template repository URL
get_template_repo() {
    if [ -z "$TEMPLATE_REPO_URL" ]; then
        # Try to detect from git remotes or .env file
        if [ -f ".env" ]; then
            TEMPLATE_REPO_URL=$(grep "^TEMPLATE_REPO_URL=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        fi
        
        if [ -z "$TEMPLATE_REPO_URL" ]; then
            log_error "Template repository URL not found. Please specify with --template-repo or add TEMPLATE_REPO_URL to .env file"
            exit 1
        fi
    fi
    
    log_debug "Template repository: $TEMPLATE_REPO_URL"
}

# Set up temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    log_debug "Using temporary directory: $TEMP_DIR"
    
    # Cleanup on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
}

# Clone template repository
clone_template() {
    log_info "Cloning template repository..."
    git clone "$TEMPLATE_REPO_URL" "$TEMP_DIR/template" --quiet
    cd "$TEMP_DIR/template"
}

# Get list of available versions
get_available_versions() {
    git tag -l --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Get latest version
get_latest_version() {
    get_available_versions | head -n 1
}

# Check for updates
check_for_updates() {
    clone_template
    
    local latest_version=$(get_latest_version)
    
    if [ -z "$latest_version" ]; then
        log_warn "No tagged versions found in template repository"
        return 1
    fi
    
    log_info "Latest template version: $latest_version"
    
    if [ "$CURRENT_VERSION" = "$latest_version" ] && [ "$FORCE_UPDATE" = false ]; then
        log_info "You are already on the latest version"
        return 0
    fi
    
    if [ "$CURRENT_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" != "$latest_version" ]; then
        log_info "Update available: $CURRENT_VERSION → $latest_version"
        
        # Show what changed
        show_changes_between_versions "$CURRENT_VERSION" "$latest_version"
        return 0
    fi
    
    log_info "Update available to: $latest_version"
}

# List all versions
list_versions() {
    clone_template
    
    local versions=$(get_available_versions)
    
    if [ -z "$versions" ]; then
        log_warn "No tagged versions found in template repository"
        return 1
    fi
    
    echo "Available template versions:"
    echo "$versions" | while read -r version; do
        if [ "$version" = "$CURRENT_VERSION" ]; then
            echo -e "  ${GREEN}$version${NC} (current)"
        else
            echo "  $version"
        fi
    done
}

# Show changes between versions
show_changes_between_versions() {
    local from_version="$1"
    local to_version="$2"
    
    log_info "Changes from $from_version to $to_version:"
    echo ""
    
    # Show git log between versions
    git log --oneline "$from_version..$to_version" | head -10
    
    echo ""
    log_info "Files that will be updated:"
    
    # Show changed files
    git diff --name-only "$from_version" "$to_version" | grep -v "^\.env" | head -10
}

# Update files from template
update_files() {
    local target_version="$1"
    local current_dir=$(pwd)
    
    cd "$TEMP_DIR/template"
    git checkout "$target_version" --quiet
    
    # Files to update (exclude client-specific files)
    local files_to_update=(
        "setup.sh"
        "build.js"
        "docker-compose.yml"
        "docker-compose.local.yml"
        "package.json"
        "settings.template.js"
        "bin/"
        "update-from-template.sh"
    )
    
    cd "$current_dir"
    
    for file in "${files_to_update[@]}"; do
        if [ -f "$TEMP_DIR/template/$file" ] || [ -d "$TEMP_DIR/template/$file" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY RUN] Would update: $file"
            else
                log_info "Updating: $file"
                cp -r "$TEMP_DIR/template/$file" .
            fi
        fi
    done
    
    # Update version in .env file
    if [ "$DRY_RUN" = false ]; then
        if grep -q "^STARTER_VERSION=" .env; then
            sed -i "s/^STARTER_VERSION=.*/STARTER_VERSION=$target_version/" .env
        else
            echo "STARTER_VERSION=$target_version" >> .env
        fi
        log_info "Updated STARTER_VERSION to $target_version in .env file"
    else
        log_info "[DRY RUN] Would update STARTER_VERSION to $target_version in .env file"
    fi
}

# Perform update
perform_update() {
    local target_version="$1"
    
    clone_template
    
    # Validate target version exists
    local available_versions=$(get_available_versions)
    if ! echo "$available_versions" | grep -q "^$target_version$"; then
        log_error "Version $target_version not found in template repository"
        log_info "Available versions:"
        echo "$available_versions"
        exit 1
    fi
    
    # Show what will change
    if [ "$CURRENT_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" != "$target_version" ]; then
        show_changes_between_versions "$CURRENT_VERSION" "$target_version"
        echo ""
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Confirm update
        read -p "Proceed with update to $target_version? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            exit 0
        fi
    fi
    
    # Perform the update
    update_files "$target_version"
    
    if [ "$DRY_RUN" = false ]; then
        log_info "Update completed successfully!"
        log_info "You may want to:"
        log_info "  1. Review the changes: git diff"
        log_info "  2. Test the setup: ./setup.sh (in staging)"
        log_info "  3. Commit the changes: git add -A && git commit -m 'Update template to $target_version'"
    else
        log_info "Dry run completed. Use --force to apply changes."
    fi
}

# Main execution
main() {
    setup_temp_dir
    load_current_version
    get_template_repo
    
    case "${ACTION:-}" in
        "check")
            check_for_updates
            ;;
        "update")
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Target version not specified"
                exit 1
            fi
            perform_update "$TARGET_VERSION"
            ;;
        "update_latest")
            clone_template
            local latest_version=$(get_latest_version)
            if [ -z "$latest_version" ]; then
                log_error "No versions found in template repository"
                exit 1
            fi
            perform_update "$latest_version"
            ;;
        "list_versions")
            list_versions
            ;;
        *)
            log_error "No action specified"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"