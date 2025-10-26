#!/bin/bash

# Big Bear Platform Sync Script
# Syncs converted apps from big-bear-casaos/converted to platform repositories
# Supports: Runtipi, Umbrel, Cosmos, Portainer, Dockge, Universal

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
CASAOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTED_DIR="$CASAOS_DIR/converted"
WORKSPACE_DIR="$(dirname "$CASAOS_DIR")"

# Platform repository paths (relative to workspace)
RUNTIPI_REPO="$WORKSPACE_DIR/big-bear-runtipi"
UMBREL_REPO="$WORKSPACE_DIR/big-bear-umbrel"
COSMOS_REPO="$WORKSPACE_DIR/big-bear-cosmos"
PORTAINER_REPO="$WORKSPACE_DIR/big-bear-portainer"
DOCKGE_REPO="$WORKSPACE_DIR/big-bear-dockge"
UNIVERSAL_REPO="$WORKSPACE_DIR/big-bear-universal"

# Default platforms to sync
PLATFORMS=("runtipi" "umbrel" "cosmos")

# Counters
TOTAL_SYNCED=0
TOTAL_SKIPPED=0
TOTAL_ERRORS=0

# Print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Sync converted apps from big-bear-casaos/converted to platform repositories.

OPTIONS:
    -h, --help              Show this help message
    -c, --casaos DIR        CasaOS repository directory (default: current directory)
    -w, --workspace DIR     Workspace directory containing all repos (default: parent of casaos dir)
    -p, --platforms LIST    Comma-separated list of platforms to sync to
                           Available: runtipi,umbrel,cosmos,portainer,dockge,universal
                           (default: runtipi,umbrel,cosmos)
    -a, --app NAME          Sync specific app only
    --dry-run              Show what would be synced without actually syncing
    --force                Overwrite existing apps without confirmation
    --replace-all          Delete all existing apps before syncing (complete replacement)
    --clean                Remove apps in destination that don't exist in source
    -v, --verbose          Verbose output

EXAMPLES:
    $0                                    # Sync all apps to default platforms
    $0 -p runtipi,umbrel                 # Sync to Runtipi and Umbrel only
    $0 -a jellyseerr                     # Sync only jellyseerr app
    $0 --dry-run                         # Preview sync without changes
    $0 --replace-all                     # Delete all existing apps and sync fresh
    $0 --clean                           # Remove orphaned apps in destinations

REPOSITORY PATHS:
    The script expects the following directory structure:
    workspace/
    ├── big-bear-casaos/
    │   └── converted/
    │       ├── runtipi/
    │       ├── umbrel/
    │       ├── cosmos/
    │       ├── portainer/
    │       ├── dockge/
    │       └── universal/
    ├── big-bear-runtipi/
    │   └── apps/
    ├── big-bear-umbrel/
    ├── big-bear-cosmos/
    │   └── servapps/
    ├── big-bear-portainer/ (optional)
    ├── big-bear-dockge/ (optional)
    └── big-bear-universal/ (optional)

EOF
}

# Parse command line arguments
parse_args() {
    DRY_RUN=false
    FORCE=false
    REPLACE_ALL=false
    CLEAN=false
    VERBOSE=false
    SPECIFIC_APP=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--casaos)
                CASAOS_DIR="$2"
                CONVERTED_DIR="$CASAOS_DIR/converted"
                shift 2
                ;;
            -w|--workspace)
                WORKSPACE_DIR="$2"
                shift 2
                ;;
            -p|--platforms)
                IFS=',' read -ra PLATFORMS <<< "$2"
                shift 2
                ;;
            -a|--app)
                SPECIFIC_APP="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --replace-all)
                REPLACE_ALL=true
                FORCE=true
                shift
                ;;
            --clean)
                CLEAN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate directories exist
validate_directories() {
    if [[ ! -d "$CONVERTED_DIR" ]]; then
        print_error "Converted directory not found: $CONVERTED_DIR"
        print_info "Run convert-apps.sh first to generate converted apps"
        exit 1
    fi
    
    print_info "Converted directory: $CONVERTED_DIR"
    print_info "Workspace directory: $WORKSPACE_DIR"
    print_info "Platforms to sync: ${PLATFORMS[*]}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    if [[ "$REPLACE_ALL" == "true" ]]; then
        print_warning "REPLACE ALL MODE - All existing apps will be deleted before syncing"
    fi
    
    echo ""
}

# Get destination directory for a platform
get_platform_dest_dir() {
    local platform="$1"
    
    case "$platform" in
        runtipi)
            echo "$RUNTIPI_REPO/apps"
            ;;
        umbrel)
            echo "$UMBREL_REPO"
            ;;
        cosmos)
            echo "$COSMOS_REPO/servapps"
            ;;
        portainer)
            echo "$PORTAINER_REPO/Apps"
            ;;
        dockge)
            echo "$DOCKGE_REPO/Apps"
            ;;
        universal)
            echo "$UNIVERSAL_REPO"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if platform repository exists
check_platform_repo() {
    local platform="$1"
    local dest_dir
    dest_dir=$(get_platform_dest_dir "$platform")
    
    if [[ -z "$dest_dir" ]]; then
        print_error "Unknown platform: $platform"
        return 1
    fi
    
    if [[ ! -d "$dest_dir" ]]; then
        print_warning "Platform repository not found: $dest_dir"
        print_info "Skipping $platform platform"
        return 1
    fi
    
    return 0
}

# Get app name for destination (handles platform-specific naming)
get_dest_app_name() {
    local platform="$1"
    local app_name="$2"
    
    case "$platform" in
        umbrel)
            # Umbrel conversion already adds big-bear-umbrel- prefix, so just use app_name as-is
            echo "$app_name"
            ;;
        *)
            echo "$app_name"
            ;;
    esac
}

# Get app name from destination (removes platform-specific prefix)
get_source_app_name() {
    local platform="$1"
    local dest_name="$2"
    
    case "$platform" in
        umbrel)
            # Remove big-bear-umbrel- prefix
            echo "${dest_name#big-bear-umbrel-}"
            ;;
        *)
            echo "$dest_name"
            ;;
    esac
}

# Replace all apps in a platform (delete all existing apps)
replace_all_apps() {
    local platform="$1"
    local dest_dir
    dest_dir=$(get_platform_dest_dir "$platform")
    
    if [[ ! -d "$dest_dir" ]]; then
        print_warning "Destination directory does not exist: $dest_dir"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would delete all existing apps in $platform"
        return
    fi
    
    print_warning "Deleting all existing apps in $platform..."
    
    # Delete all app directories, but preserve __tests__ and schema files
    find "$dest_dir" -mindepth 1 -maxdepth 1 -type d ! -name '__tests__' -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Cleared all existing apps from $platform"
}

# Sync a single app to a platform
sync_app_to_platform() {
    local platform="$1"
    local app_name="$2"
    local source_dir="$CONVERTED_DIR/$platform/$app_name"
    local dest_dir
    dest_dir=$(get_platform_dest_dir "$platform")
    local dest_app_name
    dest_app_name=$(get_dest_app_name "$platform" "$app_name")
    local dest_app_dir="$dest_dir/$dest_app_name"
    
    if [[ ! -d "$source_dir" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_warning "App not found in $platform: $app_name"
        fi
        return 1
    fi
    
    # Check if destination exists and handle accordingly
    if [[ -d "$dest_app_dir" ]] && [[ "$FORCE" != "true" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "App already exists in $platform: $dest_app_name (use --force to overwrite)"
        fi
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would sync: $app_name → $platform ($dest_app_name)"
        TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dest_app_dir"
    
    # Copy all files from source to destination
    if rsync -a --delete "$source_dir/" "$dest_app_dir/"; then
        print_success "Synced $app_name to $platform ($dest_app_name)"
        TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
    else
        print_error "Failed to sync $app_name to $platform"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        return 1
    fi
}

# Sync all apps for a platform
sync_platform() {
    local platform="$1"
    local platform_converted_dir="$CONVERTED_DIR/$platform"
    
    print_info "Syncing apps for platform: $platform"
    
    if [[ ! -d "$platform_converted_dir" ]]; then
        print_warning "No converted apps found for $platform in $platform_converted_dir"
        return
    fi
    
    # Check if platform repository exists
    if ! check_platform_repo "$platform"; then
        return
    fi
    
    # Replace all existing apps if --replace-all flag is set
    if [[ "$REPLACE_ALL" == "true" ]]; then
        replace_all_apps "$platform"
    fi
    
    # Get list of apps in converted directory
    local apps=()
    while IFS= read -r -d '' app_dir; do
        local app_name
        app_name=$(basename "$app_dir")
        apps+=("$app_name")
    done < <(find "$platform_converted_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        print_warning "No apps found in $platform_converted_dir"
        return
    fi
    
    print_info "Found ${#apps[@]} apps in $platform"
    
    # Sync each app
    for app_name in "${apps[@]}"; do
        if [[ -n "$SPECIFIC_APP" ]] && [[ "$app_name" != "$SPECIFIC_APP" ]]; then
            continue
        fi
        
        sync_app_to_platform "$platform" "$app_name"
    done
    
    # Post-sync tasks for specific platforms
    post_sync_platform "$platform"
    
    echo ""
}

# Post-sync tasks for specific platforms
post_sync_platform() {
    local platform="$1"
    
    case "$platform" in
        portainer)
            # Copy master templates.json and .template_id_counter to root
            local master_template="$CONVERTED_DIR/portainer/templates.json"
            local counter_file="$CONVERTED_DIR/portainer/.template_id_counter"
            
            if [[ -f "$master_template" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    print_info "[DRY RUN] Would copy templates.json to Portainer root"
                else
                    cp "$master_template" "$PORTAINER_REPO/templates.json"
                    print_success "Copied templates.json to Portainer root"
                fi
            fi
            
            if [[ -f "$counter_file" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    print_info "[DRY RUN] Would copy .template_id_counter to Portainer root"
                else
                    cp "$counter_file" "$PORTAINER_REPO/.template_id_counter"
                    print_success "Copied .template_id_counter to Portainer root"
                fi
            fi
            ;;
    esac
}

# Clean orphaned apps (apps in destination that don't exist in source)
clean_orphaned_apps() {
    local platform="$1"
    local dest_dir
    dest_dir=$(get_platform_dest_dir "$platform")
    local platform_converted_dir="$CONVERTED_DIR/$platform"
    
    if [[ ! -d "$dest_dir" ]] || [[ ! -d "$platform_converted_dir" ]]; then
        return
    fi
    
    print_info "Checking for orphaned apps in $platform..."
    
    local orphaned_count=0
    
    # Get all apps in destination
    while IFS= read -r -d '' dest_app_dir; do
        local dest_app_name
        dest_app_name=$(basename "$dest_app_dir")
        
        # Skip non-app directories for umbrel
        if [[ "$platform" == "umbrel" ]] && [[ ! "$dest_app_name" =~ ^big-bear-umbrel- ]]; then
            continue
        fi
        
        local source_app_name
        source_app_name=$(get_source_app_name "$platform" "$dest_app_name")
        local source_app_dir="$platform_converted_dir/$source_app_name"
        
        # Check if source exists
        if [[ ! -d "$source_app_dir" ]]; then
            print_warning "Orphaned app found: $dest_app_name (not in converted/$platform)"
            
            if [[ "$DRY_RUN" == "true" ]]; then
                print_info "[DRY RUN] Would remove: $dest_app_dir"
            else
                if [[ "$FORCE" == "true" ]]; then
                    rm -rf "$dest_app_dir"
                    print_success "Removed orphaned app: $dest_app_name"
                else
                    print_info "Use --force to remove orphaned apps"
                fi
            fi
            
            orphaned_count=$((orphaned_count + 1))
        fi
    done < <(find "$dest_dir" -mindepth 1 -maxdepth 1 -type d -print0)
    
    if [[ $orphaned_count -eq 0 ]]; then
        print_success "No orphaned apps found in $platform"
    else
        print_warning "Found $orphaned_count orphaned apps in $platform"
    fi
    
    echo ""
}

# Print summary statistics
print_summary() {
    echo ""
    echo "========================================"
    echo "           SYNC SUMMARY"
    echo "========================================"
    echo -e "${GREEN}Synced:${NC}  $TOTAL_SYNCED apps"
    echo -e "${YELLOW}Skipped:${NC} $TOTAL_SKIPPED apps"
    echo -e "${RED}Errors:${NC}  $TOTAL_ERRORS apps"
    echo "========================================"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "This was a dry run. Use without --dry-run to apply changes."
    fi
}

# Main sync function
main() {
    parse_args "$@"
    
    echo ""
    echo "========================================"
    echo "    Big Bear Platform Sync Script"
    echo "========================================"
    echo ""
    
    validate_directories
    
    # Check if rsync is available
    if ! command -v rsync &> /dev/null; then
        print_error "rsync is required but not installed"
        print_info "Install with: brew install rsync (macOS) or apt-get install rsync (Linux)"
        exit 1
    fi
    
    # Sync each platform
    for platform in "${PLATFORMS[@]}"; do
        sync_platform "$platform"
    done
    
    # Clean orphaned apps if requested
    if [[ "$CLEAN" == "true" ]]; then
        echo ""
        print_info "Cleaning orphaned apps..."
        for platform in "${PLATFORMS[@]}"; do
            clean_orphaned_apps "$platform"
        done
    fi
    
    # Print summary
    print_summary
    
    # Exit with error code if there were errors
    if [[ $TOTAL_ERRORS -gt 0 ]]; then
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
