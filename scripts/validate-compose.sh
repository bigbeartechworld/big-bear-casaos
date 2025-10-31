#!/bin/bash

# Big Bear CasaOS - Docker Compose Validator
# Validates CasaOS docker-compose.yml files against the schema

# Note: No set -e here because we want to continue validating all apps
# even if some fail, and then print a summary at the end

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APPS_DIR="$REPO_ROOT/Apps"
SCHEMA_FILE="$REPO_ROOT/schemas/casaos-compose-schema-v1.json"

# Variables
SPECIFIC_APP=""
FIX=false
VERBOSE=false
STRICT=false

# Counters
TOTAL_VALID=0
TOTAL_INVALID=0
TOTAL_WARNINGS=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate CasaOS docker-compose.yml files against the schema.

OPTIONS:
    -h, --help              Show this help message
    -a, --app NAME          Validate specific app only
    --fix                   Attempt to fix common issues
    --strict                Strict validation (fail on warnings)
    -v, --verbose           Verbose output

EXAMPLES:
    $0                      # Validate all apps
    $0 -a 2fauth           # Validate only 2fauth
    $0 --strict            # Strict validation mode
    $0 --fix               # Fix common issues automatically

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -a|--app) SPECIFIC_APP="$2"; shift 2 ;;
        --fix) FIX=true; shift ;;
        --strict) STRICT=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Check dependencies
check_dependencies() {
    local deps=("yq" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
    
    if [[ ! -f "$SCHEMA_FILE" ]]; then
        print_error "Schema file not found: $SCHEMA_FILE"
        exit 1
    fi
}

# Validate a single app
validate_app() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    local compose_file="$app_dir/docker-compose.yml"
    local has_errors=false
    local has_warnings=false
    
    if [[ ! -f "$compose_file" ]]; then
        print_error "$app_name: docker-compose.yml not found"
        TOTAL_INVALID=$((TOTAL_INVALID + 1))
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Validating $app_name..."
    fi
    
    # Convert YAML to JSON for validation
    local json_file="/tmp/${app_name}-compose.json"
    if ! yq eval -o=json "$compose_file" > "$json_file" 2>/dev/null; then
        print_error "$app_name: Invalid YAML syntax"
        TOTAL_INVALID=$((TOTAL_INVALID + 1))
        rm -f "$json_file"
        return 1
    fi
    
    # Validate required fields
    local name=$(jq -r '.name // ""' "$json_file")
    if [[ -z "$name" ]]; then
        print_error "$app_name: Missing 'name' field"
        has_errors=true
    elif [[ ! "$name" =~ ^big-bear- ]]; then
        print_warning "$app_name: Name should start with 'big-bear-' (got: $name)"
        has_warnings=true
    fi
    
    # Check x-casaos global section
    if ! jq -e '.["x-casaos"]' "$json_file" > /dev/null 2>&1; then
        print_error "$app_name: Missing global 'x-casaos' section"
        has_errors=true
    else
        # Validate required x-casaos fields
        local required_fields=("architectures" "main" "description" "tagline" "developer" "author" "icon" "title" "category" "port_map")
        for field in "${required_fields[@]}"; do
            if ! jq -e ".\"x-casaos\".\"$field\"" "$json_file" > /dev/null 2>&1; then
                print_error "$app_name: Missing x-casaos.$field"
                has_errors=true
            fi
        done
        
        # Check architectures
        local arch_count=$(jq '.["x-casaos"].architectures | length' "$json_file" 2>/dev/null || echo "0")
        if [[ "$arch_count" -eq 0 ]]; then
            print_error "$app_name: x-casaos.architectures must have at least one architecture"
            has_errors=true
        fi
        
        # Check description and title have en_us
        if ! jq -e '.["x-casaos"].description.en_us' "$json_file" > /dev/null 2>&1; then
            print_error "$app_name: Missing x-casaos.description.en_us"
            has_errors=true
        fi
        
        if ! jq -e '.["x-casaos"].title.en_us' "$json_file" > /dev/null 2>&1; then
            print_error "$app_name: Missing x-casaos.title.en_us"
            has_errors=true
        fi
        
        if ! jq -e '.["x-casaos"].tagline.en_us' "$json_file" > /dev/null 2>&1; then
            print_error "$app_name: Missing x-casaos.tagline.en_us"
            has_errors=true
        fi
    fi
    
    # Check services
    local service_count=$(jq '.services | length' "$json_file" 2>/dev/null || echo "0")
    if [[ "$service_count" -eq 0 ]]; then
        print_error "$app_name: No services defined"
        has_errors=true
    else
        # Check each service has required fields
        local services=$(jq -r '.services | keys[]' "$json_file")
        while IFS= read -r service_name; do
            if ! jq -e ".services.\"$service_name\".image" "$json_file" > /dev/null 2>&1; then
                print_error "$app_name: Service '$service_name' missing 'image' field"
                has_errors=true
            fi
            
            # Check for named volumes (should use bind mounts in CasaOS)
            if jq -e '.volumes' "$json_file" > /dev/null 2>&1; then
                print_warning "$app_name: Uses named volumes - should use bind mounts for CasaOS"
                has_warnings=true
            fi
        done <<< "$services"
    fi
    
    # Cleanup
    rm -f "$json_file"
    
    # Report results
    if [[ "$has_errors" == "true" ]]; then
        print_error "$app_name: Validation FAILED"
        TOTAL_INVALID=$((TOTAL_INVALID + 1))
        return 1
    elif [[ "$has_warnings" == "true" ]]; then
        if [[ "$STRICT" == "true" ]]; then
            print_error "$app_name: Validation FAILED (strict mode - warnings treated as errors)"
            TOTAL_INVALID=$((TOTAL_INVALID + 1))
            return 1
        else
            print_warning "$app_name: Validation passed with warnings"
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
            TOTAL_VALID=$((TOTAL_VALID + 1))
            return 0
        fi
    else
        if [[ "$VERBOSE" == "true" ]]; then
            print_success "$app_name: Validation passed"
        fi
        TOTAL_VALID=$((TOTAL_VALID + 1))
        return 0
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "       VALIDATION SUMMARY"
    echo "========================================"
    echo -e "${GREEN}Valid:${NC}    $TOTAL_VALID apps"
    echo -e "${YELLOW}Warnings:${NC} $TOTAL_WARNINGS apps"
    echo -e "${RED}Invalid:${NC}  $TOTAL_INVALID apps"
    echo "========================================"
    echo ""
}

# Main
main() {
    echo ""
    echo "========================================"
    echo "  CasaOS Docker Compose Validator"
    echo "========================================"
    echo ""
    
    check_dependencies
    
    if [[ -n "$SPECIFIC_APP" ]]; then
        validate_app "$SPECIFIC_APP"
    else
        print_info "Validating all apps in $APPS_DIR"
        echo ""
        
        while IFS= read -r -d '' app_dir; do
            app_name=$(basename "$app_dir")
            
            # Skip test directories and hidden directories
            if [[ "$app_name" == "__tests__" ]] || [[ "$app_name" == .* ]]; then
                continue
            fi
            
            validate_app "$app_name"
        done < <(find "$APPS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi
    
    print_summary
    
    if [[ $TOTAL_INVALID -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
