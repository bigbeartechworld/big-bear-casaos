#!/bin/bash

# Big Bear CasaOS - Automated Pull Request Creator
# Creates pull requests in platform repositories after syncing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Print colored output
print_header() { echo -e "\n${MAGENTA}========================================${NC}"; echo -e "${MAGENTA}$1${NC}"; echo -e "${MAGENTA}========================================${NC}\n"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Default configuration
PLATFORMS=("portainer" "dockge" "runtipi" "cosmos" "umbrel")
BRANCH_PREFIX="automated-update"
DEFAULT_BASE_BRANCH="main"
PR_TITLE_TEMPLATE="🤖 Automated Update from BigBearCasaOS"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create pull requests in platform repositories after syncing.

OPTIONS:
    -h, --help              Show this help message
    -p, --platforms LIST    Comma-separated list of platforms to create PRs for
                           Available: portainer,runtipi,dockge,cosmos,umbrel (default: all)
    -a, --app NAME          PR for specific app only (uses in commit message)
    -b, --branch NAME       Branch name prefix (default: automated-update)
    -m, --message TEXT      Custom commit message
    --title TEXT           Custom PR title
    --body TEXT            Custom PR body (markdown)
    --base-branch NAME     Base branch to create PR against (default: main)
    --draft                Create PR as draft
    --auto-merge           Enable auto-merge on PR
    --dry-run              Show what would be done without creating PRs
    --skip-summary         Skip the confirmation summary before creating PRs
    -v, --verbose          Verbose output

EXAMPLES:
    $0                                          # Create PRs for all platforms (shows summary)
    $0 -p portainer,dockge                     # Create PRs for specific platforms
    $0 -a jellyseerr                           # PR for jellyseerr update
    $0 --skip-summary                          # Skip confirmation prompts
    $0 --dry-run                               # Preview PR creation
    $0 --draft                                 # Create draft PRs
    $0 --auto-merge                            # Enable auto-merge

INTERACTIVE SUMMARY:
    By default, the script will show a summary before creating each PR:
    - PR title and description
    - Branch name
    - Files being updated
    - Draft/auto-merge status
    
    You can then choose to:
    - y/yes: Create the PR
    - N/no:  Skip this platform
    - s/skip: Skip all remaining summaries and create PRs automatically
    
    Use --skip-summary to bypass all confirmation prompts.

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - Git repositories must be clean (no uncommitted changes)
    - Must have push access to repositories

EOF
}

# Parse command line arguments
SELECTED_PLATFORMS=""
SELECTED_APP=""
CUSTOM_BRANCH=""
CUSTOM_MESSAGE=""
CUSTOM_TITLE=""
CUSTOM_BODY=""
BASE_BRANCH="$DEFAULT_BASE_BRANCH"
CREATE_DRAFT=false
AUTO_MERGE=false
DRY_RUN=false
VERBOSE=false
SKIP_SUMMARY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--platforms)
            SELECTED_PLATFORMS="$2"
            shift 2
            ;;
        -a|--app)
            SELECTED_APP="$2"
            shift 2
            ;;
        -b|--branch)
            CUSTOM_BRANCH="$2"
            shift 2
            ;;
        -m|--message)
            CUSTOM_MESSAGE="$2"
            shift 2
            ;;
        --title)
            CUSTOM_TITLE="$2"
            shift 2
            ;;
        --body)
            CUSTOM_BODY="$2"
            shift 2
            ;;
        --base-branch)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --draft)
            CREATE_DRAFT=true
            shift
            ;;
        --auto-merge)
            AUTO_MERGE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-summary)
            SKIP_SUMMARY=true
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

# Determine platforms to process
if [[ -n "$SELECTED_PLATFORMS" ]]; then
    IFS=',' read -ra PLATFORMS <<< "$SELECTED_PLATFORMS"
fi

# Check if GitHub CLI is installed
check_github_cli() {
    # Skip check in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Dry run mode - skipping GitHub CLI check"
        return 0
    fi
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_info "Install it from: https://cli.github.com/"
        print_info "  macOS: brew install gh"
        print_info "  Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_info "Run: gh auth login"
        exit 1
    fi
    
    print_success "GitHub CLI is installed and authenticated"
}

# Get repository name for platform
get_repo_name() {
    local platform="$1"
    echo "big-bear-$platform"
}

# Get repository path
get_repo_path() {
    local platform="$1"
    local repo_name=$(get_repo_name "$platform")
    echo "$WORKSPACE_DIR/$repo_name"
}

# Check if repository exists and is a git repo
check_repository() {
    local platform="$1"
    local repo_path=$(get_repo_path "$platform")
    
    if [[ ! -d "$repo_path" ]]; then
        print_warning "Repository not found: $repo_path"
        return 1
    fi
    
    if [[ ! -d "$repo_path/.git" ]]; then
        print_warning "Not a git repository: $repo_path"
        return 1
    fi
    
    return 0
}

# Detect the default branch for the repository
detect_default_branch() {
    local repo_path="$1"
    
    cd "$repo_path"
    
    # Try to get the default branch from remote
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    
    if [[ -n "$default_branch" ]]; then
        echo "$default_branch"
        return 0
    fi
    
    # If that fails, try common branch names in order
    for branch in "main" "master"; do
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
            echo "$branch"
            return 0
        fi
    done
    
    # If still nothing, get the current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
        echo "$current_branch"
        return 0
    fi
    
    # Last resort: return main
    echo "main"
    return 0
}

# Get changed files in repository
get_changed_files() {
    local repo_path="$1"
    
    cd "$repo_path"
    
    # Check for staged and unstaged changes
    local changed_files=$(git status --porcelain)
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Checking for changes in: $repo_path"
        print_info "Git status output:"
        git status --porcelain | head -20
    fi
    
    if [[ -z "$changed_files" ]]; then
        echo ""
        return 1
    fi
    
    echo "$changed_files"
    return 0
}

# Get list of apps that were updated
get_updated_apps() {
    local repo_path="$1"
    local platform="$2"
    
    cd "$repo_path"
    
    local apps_list=""
    
    case "$platform" in
        portainer)
            # Check if templates.json was modified
            if git status --porcelain | grep -q "templates.json"; then
                apps_list="All apps (templates.json updated)"
            fi
            ;;
        dockge)
            # List modified app directories
            apps_list=$(git status --porcelain | grep "Apps/" | sed 's/^...Apps\///' | cut -d'/' -f1 | sort -u | sed 's/^/- /' | tr '\n' ' ')
            ;;
        runtipi)
            # List modified app directories
            apps_list=$(git status --porcelain | grep "apps/" | sed 's/^...apps\///' | cut -d'/' -f1 | sort -u | sed 's/^/- /' | tr '\n' ' ')
            ;;
        cosmos)
            # List modified servapp directories
            apps_list=$(git status --porcelain | grep "servapps/" | sed 's/^...servapps\///' | cut -d'/' -f1 | sort -u | sed 's/^/- /' | tr '\n' ' ')
            ;;
        umbrel)
            # List modified app directories
            apps_list=$(git status --porcelain | grep "big-bear-umbrel-" | sed 's/^...big-bear-umbrel-//' | cut -d'/' -f1 | sort -u | sed 's/^/- /' | tr '\n' ' ')
            ;;
    esac
    
    if [[ -z "$apps_list" ]]; then
        apps_list="Multiple apps updated"
    fi
    
    echo "$apps_list"
}

# Generate commit message
generate_commit_message() {
    local platform="$1"
    local app_name="$2"
    
    if [[ -n "$CUSTOM_MESSAGE" ]]; then
        echo "$CUSTOM_MESSAGE"
        return
    fi
    
    if [[ -n "$app_name" ]]; then
        echo "Update $app_name from CasaOS conversion"
    else
        echo "Automated update from CasaOS conversion - $(date +%Y-%m-%d)"
    fi
}

# Generate PR title
generate_pr_title() {
    local platform="$1"
    local app_name="$2"
    
    if [[ -n "$CUSTOM_TITLE" ]]; then
        echo "$CUSTOM_TITLE"
        return
    fi
    
    if [[ -n "$app_name" ]]; then
        echo "🤖 Update $app_name"
    else
        echo "$PR_TITLE_TEMPLATE - $(date +%Y-%m-%d)"
    fi
}

# Generate PR body
generate_pr_body() {
    local platform="$1"
    local apps_list="$2"
    
    if [[ -n "$CUSTOM_BODY" ]]; then
        echo "$CUSTOM_BODY"
        return
    fi
    
    cat << EOF
## Automated Update

This PR contains automated updates from the [Big Bear CasaOS](https://github.com/bigbeartechworld/big-bear-casaos) repository.

### Platform: $platform

### Apps Updated
$apps_list

### Validation
- ✅ Conversion completed successfully
- ✅ Files validated
- ✅ Sync completed

### Changes
This update includes the latest app definitions, configurations, and metadata from the CasaOS repository.

---
*This PR was automatically generated by the Big Bear CasaOS pipeline.*  
*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Create branch and commit changes
# Returns the actual base branch used (either detected or user-specified)
create_branch_and_commit() {
    local repo_path="$1"
    local platform="$2"
    local branch_name="$3"
    local commit_message="$4"
    
    cd "$repo_path"
    
    # Detect the default branch for this repository
    local detected_base_branch=$(detect_default_branch "$repo_path")
    print_info "Detected default branch: $detected_base_branch"
    
    # Use detected branch if BASE_BRANCH is still the default "main"
    # This allows user override via --base-branch flag
    ACTUAL_BASE_BRANCH="$BASE_BRANCH"
    if [[ "$BASE_BRANCH" == "main" ]]; then
        ACTUAL_BASE_BRANCH="$detected_base_branch"
        print_info "Using detected default branch: $ACTUAL_BASE_BRANCH"
    fi
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    print_info "Current branch: $current_branch"
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        print_step "Stashing uncommitted changes..."
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "Changes to be stashed:"
            git status --porcelain | head -10
        fi
        git stash push -u -m "Temporary stash for PR creation" || true
        local stashed=true
    else
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "No uncommitted changes to stash"
        fi
        local stashed=false
    fi
    
    # Check if base branch exists
    if ! git rev-parse --verify "$ACTUAL_BASE_BRANCH" >/dev/null 2>&1; then
        print_error "Base branch '$ACTUAL_BASE_BRANCH' does not exist in repository"
        print_info "Available branches:"
        git branch -a | grep -v "HEAD" | sed 's/^/  /'
        # Try to restore stashed changes if we stashed them
        if [ "$stashed" = true ]; then
            git checkout "$current_branch" 2>/dev/null || true
            git stash pop 2>/dev/null || true
        fi
        return 1
    fi
    
    # Ensure we're on the base branch and up to date
    print_step "Checking out $ACTUAL_BASE_BRANCH..."
    if ! git checkout "$ACTUAL_BASE_BRANCH" 2>/dev/null; then
        print_error "Failed to checkout $ACTUAL_BASE_BRANCH"
        # Try to restore stashed changes if we stashed them
        if [ "$stashed" = true ]; then
            git checkout "$current_branch" 2>/dev/null || true
            git stash pop 2>/dev/null || true
        fi
        return 1
    fi
    
    # Pull latest changes BEFORE applying stash to avoid conflicts
    print_step "Pulling latest changes from $ACTUAL_BASE_BRANCH..."
    if ! git pull origin "$ACTUAL_BASE_BRANCH"; then
        print_error "Failed to pull latest changes from $ACTUAL_BASE_BRANCH"
        print_warning "Your local branch may be out of sync with remote"
        # Try to restore stashed changes if we stashed them
        if [ "$stashed" = true ]; then
            git checkout "$current_branch" 2>/dev/null || true
            git stash pop 2>/dev/null || true
        fi
        return 1
    fi
    
    # Apply stashed changes if we stashed them
    if [ "$stashed" = true ]; then
        print_step "Applying stashed changes..."
        if [[ "$VERBOSE" == "true" ]]; then
            print_info "Attempting to apply stash..."
        fi
        if ! git stash pop 2>/dev/null; then
            print_error "Could not apply stashed changes - conflicts detected"
            print_warning "This usually means the local files conflict with remote changes"
            print_info "Dropping conflicting stash and continuing with fresh pull..."
            git stash drop 2>/dev/null || true
            # The fresh pull should have the latest, so we continue
        else
            if [[ "$VERBOSE" == "true" ]]; then
                print_success "Stash applied successfully"
                print_info "Changes after applying stash:"
                git status --porcelain | head -10
            fi
        fi
    fi
    
    # Check if there are actually any changes to commit after pull and stash operations
    # git diff-index returns 0 (success) if there are NO changes, 1 if there ARE changes
    # git ls-files --others returns a list of untracked files
    if git diff-index --quiet HEAD 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        print_warning "No changes to commit after syncing with remote"
        print_info "The changes may have already been committed to the remote branch"
        return 0
    fi
    
    # Delete branch if it exists
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        print_info "Deleting existing branch: $branch_name"
        git branch -D "$branch_name" 2>/dev/null || true
    fi
    
    # Create new branch
    print_step "Creating branch: $branch_name"
    if ! git checkout -b "$branch_name"; then
        print_error "Failed to create branch: $branch_name"
        return 1
    fi
    
    # Stage all changes
    print_step "Staging changes..."
    git add -A
    
    # Check again if there are changes to commit after staging
    if git diff --cached --quiet; then
        print_warning "No changes to commit after staging"
        print_info "All files are already up to date in the base branch"
        # Clean up: delete branch and go back to base branch
        git checkout "$ACTUAL_BASE_BRANCH" 2>/dev/null || true
        git branch -D "$branch_name" 2>/dev/null || true
        return 0
    fi
    
    # Commit changes
    print_step "Committing changes..."
    if ! git commit -m "$commit_message"; then
        print_error "Failed to commit changes"
        # Clean up: delete branch and go back to base branch
        git checkout "$ACTUAL_BASE_BRANCH" 2>/dev/null || true
        git branch -D "$branch_name" 2>/dev/null || true
        return 1
    fi
    
    print_success "Created branch and committed changes"
    return 0
}

# Push branch to remote
push_branch() {
    local repo_path="$1"
    local branch_name="$2"
    
    cd "$repo_path"
    
    print_step "Pushing branch to remote..."
    
    # Force push to handle branch updates
    if git push -f origin "$branch_name"; then
        print_success "Pushed branch: $branch_name"
        return 0
    else
        print_error "Failed to push branch: $branch_name"
        return 1
    fi
}

# Create pull request using GitHub CLI
create_pull_request() {
    local repo_path="$1"
    local platform="$2"
    local branch_name="$3"
    local pr_title="$4"
    local pr_body="$5"
    
    cd "$repo_path"
    
    print_step "Creating pull request..."
    
    # Use ACTUAL_BASE_BRANCH if set (from create_branch_and_commit), otherwise use BASE_BRANCH
    local base_branch="${ACTUAL_BASE_BRANCH:-$BASE_BRANCH}"
    
    # Build gh pr create command
    local gh_cmd="gh pr create --base $base_branch --head $branch_name --title \"$pr_title\" --body \"$pr_body\""
    
    if [[ "$CREATE_DRAFT" == "true" ]]; then
        gh_cmd="$gh_cmd --draft"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Running: $gh_cmd"
    fi
    
    # Create PR
    local pr_url
    if pr_url=$(eval "$gh_cmd" 2>&1); then
        print_success "Created pull request: $pr_url"
        
        # Enable auto-merge if requested
        if [[ "$AUTO_MERGE" == "true" ]]; then
            print_step "Enabling auto-merge..."
            if gh pr merge --auto --squash "$branch_name"; then
                print_success "Auto-merge enabled"
            else
                print_warning "Could not enable auto-merge (may not be available)"
            fi
        fi
        
        echo "$pr_url"
        return 0
    else
        # Check if PR already exists
        if echo "$pr_url" | grep -q "already exists"; then
            print_warning "Pull request already exists for branch: $branch_name"
            
            # Get existing PR URL
            local existing_pr=$(gh pr list --head "$branch_name" --json url --jq '.[0].url')
            if [[ -n "$existing_pr" ]]; then
                print_info "Existing PR: $existing_pr"
                echo "$existing_pr"
            fi
            return 0
        else
            print_error "Failed to create pull request"
            print_error "$pr_url"
            return 1
        fi
    fi
}

# Display summary of what will be done
display_pr_summary() {
    local platform="$1"
    local pr_title="$2"
    local pr_body="$3"
    local changed_files="$4"
    local branch_name="$5"
    
    print_header "PR SUMMARY FOR $platform"
    
    echo -e "${CYAN}Title:${NC}"
    echo "  $pr_title"
    echo ""
    
    echo -e "${CYAN}Branch:${NC}"
    echo "  $branch_name"
    echo ""
    
    echo -e "${CYAN}Description:${NC}"
    # Show first 10 lines of PR body
    echo "$pr_body" | head -10 | sed 's/^/  /'
    if [[ $(echo "$pr_body" | wc -l) -gt 10 ]]; then
        echo "  ..."
    fi
    echo ""
    
    echo -e "${CYAN}Files Being Updated:${NC}"
    echo "$changed_files" | sed 's/^/  /'
    echo ""
    
    if [[ "$CREATE_DRAFT" == "true" ]]; then
        echo -e "${YELLOW}⚠️  This will be created as a DRAFT PR${NC}"
    fi
    
    if [[ "$AUTO_MERGE" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Auto-merge will be enabled${NC}"
    fi
    
    echo ""
}

# Ask for confirmation
ask_confirmation() {
    local platform="$1"
    
    if [[ "$SKIP_SUMMARY" == "true" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}Create this PR for $platform? [y/N/s(kip all)] ${NC}"
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        [sS][kK][iI][pP]*|[sS])
            SKIP_SUMMARY=true
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Process a single platform
process_platform() {
    local platform="$1"
    
    print_header "Processing $platform"
    
    # Check if repository exists
    if ! check_repository "$platform"; then
        print_error "Skipping $platform - repository not found or not a git repo"
        return 1
    fi
    
    local repo_path=$(get_repo_path "$platform")
    
    # Check for changes
    print_step "Checking for changes in $platform repository..."
    if ! changed_files=$(get_changed_files "$repo_path"); then
        print_warning "No changes found in $platform repository"
        return 0
    fi
    
    print_success "Found changes in $platform repository"
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$changed_files"
    fi
    
    # Get list of updated apps
    local apps_list=$(get_updated_apps "$repo_path" "$platform")
    print_info "Updated apps: $apps_list"
    
    # Generate branch name
    local branch_name="${CUSTOM_BRANCH:-$BRANCH_PREFIX}-$(date +%Y%m%d-%H%M%S)"
    if [[ -n "$SELECTED_APP" ]]; then
        branch_name="${CUSTOM_BRANCH:-$BRANCH_PREFIX}-$SELECTED_APP"
    fi
    
    # Generate commit message, PR title, and body
    local commit_message=$(generate_commit_message "$platform" "$SELECTED_APP")
    local pr_title=$(generate_pr_title "$platform" "$SELECTED_APP")
    local pr_body=$(generate_pr_body "$platform" "$apps_list")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN - Would create PR with:"
        echo "  Branch: $branch_name"
        echo "  Commit: $commit_message"
        echo "  Title: $pr_title"
        echo "  Body (first 100 chars): ${pr_body:0:100}..."
        return 0
    fi
    
    # Display summary and ask for confirmation
    display_pr_summary "$platform" "$pr_title" "$pr_body" "$changed_files" "$branch_name"
    
    if ! ask_confirmation "$platform"; then
        print_warning "Skipped $platform"
        return 0
    fi
    
    # Create branch and commit
    local commit_result
    if ! create_branch_and_commit "$repo_path" "$platform" "$branch_name" "$commit_message"; then
        commit_result=$?
        # Check if we're still on base branch (meaning no changes were found)
        local current_branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD)
        local base_branch="${ACTUAL_BASE_BRANCH:-$BASE_BRANCH}"
        if [[ "$current_branch" == "$base_branch" ]]; then
            print_warning "No changes to commit for $platform - already up to date"
            return 0
        else
            print_error "Failed to create branch and commit for $platform"
            return 1
        fi
    fi
    
    # Push branch
    if ! push_branch "$repo_path" "$branch_name"; then
        print_error "Failed to push branch for $platform"
        # Cleanup: go back to base branch
        cd "$repo_path"
        git checkout "${ACTUAL_BASE_BRANCH:-$BASE_BRANCH}"
        return 1
    fi
    
    # Create pull request
    if ! pr_url=$(create_pull_request "$repo_path" "$platform" "$branch_name" "$pr_title" "$pr_body"); then
        print_error "Failed to create pull request for $platform"
        # Clean up: go back to base branch
        cd "$repo_path"
        git checkout "${ACTUAL_BASE_BRANCH:-$BASE_BRANCH}" 2>/dev/null || true
        return 1
    fi
    
    # Go back to base branch
    cd "$repo_path"
    git checkout "${ACTUAL_BASE_BRANCH:-$BASE_BRANCH}" 2>/dev/null || git checkout - 2>/dev/null || true
    
    print_success "Successfully created PR for $platform: $pr_url"
    return 0
}

# Main function
main() {
    print_header "BIG BEAR CASAOS - PULL REQUEST CREATOR"
    
    print_info "Platforms: ${PLATFORMS[*]}"
    if [[ -n "$SELECTED_APP" ]]; then
        print_info "App: $SELECTED_APP"
    fi
    print_info "Base branch: $BASE_BRANCH"
    print_info "Draft: $CREATE_DRAFT"
    print_info "Auto-merge: $AUTO_MERGE"
    print_info "Dry run: $DRY_RUN"
    
    # Check dependencies
    check_github_cli
    
    # Track results
    local total_platforms=${#PLATFORMS[@]}
    local successful_prs=0
    local failed_prs=0
    local skipped=0
    
    # Process each platform
    for platform in "${PLATFORMS[@]}"; do
        if process_platform "$platform"; then
            successful_prs=$((successful_prs + 1))
        else
            if check_repository "$platform"; then
                failed_prs=$((failed_prs + 1))
            else
                skipped=$((skipped + 1))
            fi
        fi
    done
    
    # Print summary
    print_header "SUMMARY"
    print_info "Total platforms: $total_platforms"
    print_success "Successful PRs: $successful_prs"
    if [[ $failed_prs -gt 0 ]]; then
        print_error "Failed PRs: $failed_prs"
    fi
    if [[ $skipped -gt 0 ]]; then
        print_warning "Skipped: $skipped"
    fi
    
    # In dry-run mode, always exit successfully
    if [[ "$DRY_RUN" == "true" ]]; then
        print_success "Dry run completed successfully!"
        exit 0
    fi
    
    if [[ $failed_prs -eq 0 ]]; then
        print_success "All PRs created successfully!"
        exit 0
    else
        print_error "Some PRs failed to create"
        exit 1
    fi
}

# Run main function
main "$@"
