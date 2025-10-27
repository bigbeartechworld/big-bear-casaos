#!/bin/bash

# Big Bear CasaOS App Converter
# Converts CasaOS apps to multiple platform formats
# Supports: Portainer, Runtipi, Dockge, Cosmos, Universal

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
APPS_DIR="./Apps"
OUTPUT_DIR="./converted"
PLATFORMS=("portainer" "runtipi" "dockge" "cosmos" "universal" "umbrel")

# Print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Convert Big Bear CasaOS apps to multiple platform formats.

OPTIONS:
    -h, --help              Show this help message
    -i, --input DIR         Input directory containing apps (default: ./Apps)
    -o, --output DIR        Output directory for converted apps (default: ./converted)
    -p, --platforms LIST    Comma-separated list of platforms to convert to
                           Available: portainer,runtipi,dockge,cosmos,universal,umbrel (default: all)
    -a, --app NAME          Convert specific app only
    --dry-run              Show what would be converted without actually converting
    --validate             Validate existing conversions
    -v, --verbose          Verbose output

EXAMPLES:
    $0                                    # Convert all apps to all platforms
    $0 -p portainer,dockge               # Convert to Portainer and Dockge only
    $0 -a jellystat                      # Convert only jellystat app
    $0 --dry-run                         # Preview conversion without changes

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--input)
                APPS_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--platforms)
                IFS=',' read -ra PLATFORMS <<< "$2"
                shift 2
                ;;
            -a|--app)
                SINGLE_APP="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --validate)
                VALIDATE_ONLY=true
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

# Validate required tools
check_dependencies() {
    local deps=("jq" "yq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_info "Please install missing tools:"
        for tool in "${missing[@]}"; do
            case "$tool" in
                jq) echo "  - brew install jq  # or apt-get install jq" ;;
                yq) echo "  - brew install yq  # or pip install yq" ;;
            esac
        done
        exit 1
    fi
    
    # Check for optional image conversion tools (for Runtipi icon conversion)
    local has_image_converter=false
    if command -v convert &> /dev/null; then
        has_image_converter=true
    elif command -v ffmpeg &> /dev/null; then
        has_image_converter=true
    elif command -v sips &> /dev/null; then
        has_image_converter=true
    fi
    
    if [[ "$has_image_converter" == "false" ]]; then
        print_warning "No image conversion tool found (ImageMagick, ffmpeg, or sips)"
        print_warning "Icon conversion for Runtipi may not work properly"
        print_info "Install ImageMagick: apt-get install imagemagick  # or brew install imagemagick"
    fi
}

# Initialize output directories
init_directories() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would create directories in $OUTPUT_DIR"
        return
    fi
    
    mkdir -p "$OUTPUT_DIR"
    for platform in "${PLATFORMS[@]}"; do
        mkdir -p "$OUTPUT_DIR/$platform"
        
        # Initialize port tracker for Runtipi to ensure unique ports
        if [[ "$platform" == "runtipi" ]]; then
            # Clear the port tracker file for fresh conversion
            rm -f "$OUTPUT_DIR/runtipi/.port_tracker"
        fi
    done
    print_success "Created output directories in $OUTPUT_DIR"
}

# Extract metadata from config.json and docker-compose.yml
extract_metadata() {
    local app_dir="$1"
    local app_name="$2"
    local config_file="$app_dir/config.json"
    local compose_file="$app_dir/docker-compose.yml"
    
    if [[ ! -f "$config_file" ]] || [[ ! -f "$compose_file" ]]; then
        print_warning "Missing files for $app_name (config.json or docker-compose.yml)"
        return 1
    fi
    
    # Extract basic metadata from config.json
    local id version image youtube docs_link
    id=$(jq -r '.id // empty' "$config_file" 2>/dev/null || echo "$app_name")
    version=$(jq -r '.version // empty' "$config_file" 2>/dev/null || echo "latest")
    image=$(jq -r '.image // empty' "$config_file" 2>/dev/null || echo "")
    youtube=$(jq -r '.youtube // empty' "$config_file" 2>/dev/null || echo "")
    docs_link=$(jq -r '.docs_link // empty' "$config_file" 2>/dev/null || echo "")
    
    # Extract CasaOS metadata from docker-compose.yml
    local title description tagline developer author icon thumbnail category port_map
    title=$(yq eval '.x-casaos.title.en_us // ""' "$compose_file" 2>/dev/null || echo "$app_name")
    description=$(yq eval '.x-casaos.description.en_us // ""' "$compose_file" 2>/dev/null || echo "")
    tagline=$(yq eval '.x-casaos.tagline.en_us // ""' "$compose_file" 2>/dev/null || echo "")
    developer=$(yq eval '.x-casaos.developer // ""' "$compose_file" 2>/dev/null || echo "")
    author=$(yq eval '.x-casaos.author // ""' "$compose_file" 2>/dev/null || echo "BigBearTechWorld")
    icon=$(yq eval '.x-casaos.icon // ""' "$compose_file" 2>/dev/null || echo "")
    thumbnail=$(yq eval '.x-casaos.thumbnail // ""' "$compose_file" 2>/dev/null || echo "")
    category=$(yq eval '.x-casaos.category // ""' "$compose_file" 2>/dev/null || echo "")
    port_map=$(yq eval '.x-casaos.port_map // ""' "$compose_file" 2>/dev/null || echo "")
    
    # Store metadata in associative array (simulated with variables)
    # Use printf to safely escape all special characters
    printf "METADATA_ID=%q\n" "$id"
    printf "METADATA_VERSION=%q\n" "$version"
    printf "METADATA_IMAGE=%q\n" "$image"
    printf "METADATA_TITLE=%q\n" "$title"
    printf "METADATA_DESCRIPTION=%q\n" "$description"
    printf "METADATA_TAGLINE=%q\n" "$tagline"
    printf "METADATA_DEVELOPER=%q\n" "$developer"
    printf "METADATA_AUTHOR=%q\n" "$author"
    printf "METADATA_ICON=%q\n" "$icon"
    printf "METADATA_THUMBNAIL=%q\n" "$thumbnail"
    printf "METADATA_CATEGORY=%q\n" "$category"
    printf "METADATA_PORT_MAP=%q\n" "$port_map"
    printf "METADATA_YOUTUBE=%q\n" "$youtube"
    printf "METADATA_DOCS_LINK=%q\n" "$docs_link"
}

# Create a placeholder logo.jpg image
create_placeholder_logo() {
    local output_file="$1"
    
    # Create a minimal 512x512 gray placeholder image using ImageMagick
    if command -v convert &> /dev/null; then
        convert -size 512x512 xc:#cccccc -gravity center -pointsize 48 -fill white -annotate +0+0 "No Icon" "$output_file" 2>/dev/null
        
        # Verify the placeholder was created
        if [[ ! -f "$output_file" || ! -s "$output_file" ]]; then
            # If ImageMagick failed, create an even simpler placeholder
            convert -size 512x512 xc:#cccccc "$output_file" 2>/dev/null || {
                # Last resort: create an empty file (better than nothing)
                touch "$output_file"
            }
        fi
    else
        # If no ImageMagick, just create an empty file
        touch "$output_file"
    fi
}

# Clean docker-compose.yml by removing CasaOS-specific extensions
clean_compose() {
    local input_file="$1"
    local output_file="$2"
    local base_path="$3"
    local add_volumes="${4:-false}"  # Optional parameter to convert to named volumes
    local app_prefix="${5:-}"  # Optional app name prefix for volume names
    local add_runtipi_label="${6:-false}"  # Optional parameter to add runtipi.managed label
    
    # First remove x-casaos sections
    local temp_file="${output_file}.tmp"
    # Suppress yq lexer warnings about malformed inline comments in source YAML files
    exec 3>&2 2>/dev/null
    yq eval '
        del(.x-casaos) |
        del(.services[].x-casaos)
    ' "$input_file" > "$temp_file" 2>&3
    exec 2>&3 3>&-
    
    # If add_volumes is true, convert bind mounts to named volumes
    if [[ "$add_volumes" == "true" ]]; then
        # Create a temporary file to track volume mappings
        local volume_map_file="${temp_file}.volmap"
        : > "$volume_map_file"  # Create empty file
        
        # Process each service and convert volume mounts
        local services
        services=$(yq eval '.services | keys | .[]' "$temp_file" 2>/dev/null)
        
        # Iterate through each service
        while IFS= read -r service; do
            [[ -z "$service" ]] && continue
            
            # Get the volume mounts for this service
            local volume_count
            volume_count=$(yq eval ".services[\"$service\"].volumes | length" "$temp_file" 2>/dev/null)
            
            if [[ "$volume_count" != "null" && "$volume_count" -gt 0 ]]; then
                for ((i=0; i<volume_count; i++)); do
                    local volume_def
                    volume_def=$(yq eval ".services[\"$service\"].volumes[$i]" "$temp_file" 2>/dev/null)
                    
                    # Clean up malformed inline comments (e.g., "path:/mount#comment" should be "path:/mount")
                    # This handles cases where comments don't have proper spacing before the #
                    if [[ "$volume_def" == *"#"* ]]; then
                        volume_def=$(echo "$volume_def" | cut -d'#' -f1)
                    fi
                    
                    # Check if this is a CasaOS bind mount that should be converted
                    if [[ "$volume_def" == *"/DATA/AppData/\$AppID"* ]] || \
                       [[ "$volume_def" == "/DATA/AppData/\$AppID"* ]]; then
                        # Extract the container path (after the :)
                        local container_path
                        container_path=$(echo "$volume_def" | cut -d':' -f2)
                        
                        # Remove any mount options (like :ro, :rw)
                        container_path=$(echo "$container_path" | cut -d':' -f1)
                        
                        # Extract the host path part for naming
                        local host_path
                        host_path=$(echo "$volume_def" | cut -d':' -f1)
                        # Get the subdirectory after $AppID (e.g., /config, /data/media)
                        local subdir
                        subdir=$(echo "$host_path" | sed 's|/DATA/AppData/\$AppID||')
                        
                        # Create a volume name based on both host subdir and container path
                        # Prefer using the subdirectory name if it exists
                        local volume_name
                        if [[ -n "$subdir" && "$subdir" != "/" ]]; then
                            volume_name=$(echo "$subdir" | sed 's|^/||' | sed 's|/|_|g' | sed 's|-|_|g')
                        else
                            volume_name=$(echo "$container_path" | sed 's|^/||' | sed 's|/|_|g' | sed 's|-|_|g')
                        fi
                        
                        # Add app prefix to prevent collisions between different apps
                        # Convert dashes to underscores in the app prefix too
                        if [[ -n "$app_prefix" ]]; then
                            local safe_prefix
                            safe_prefix=$(echo "$app_prefix" | sed 's|-|_|g')
                            volume_name="${safe_prefix}_${volume_name}"
                        fi
                        
                        # Check if we've already created this volume mapping
                        if ! grep -q "^${container_path}=" "$volume_map_file" 2>/dev/null; then
                            echo "${container_path}=${volume_name}" >> "$volume_map_file"
                            
                            # Add this volume to the top-level volumes section
                            yq eval ".volumes.\"$volume_name\" = {}" -i "$temp_file"
                        else
                            # Get the existing volume name for this path
                            volume_name=$(grep "^${container_path}=" "$volume_map_file" | cut -d'=' -f2)
                        fi
                        
                        # Update the volume mount to use the named volume
                        yq eval ".services[\"$service\"].volumes[$i] = \"$volume_name:$container_path\"" -i "$temp_file"
                    fi
                done
            fi
        done <<< "$services"
        
        # Clean up the mapping file
        rm -f "$volume_map_file"
    else
        # Original behavior: just replace paths with bind mounts
        sed "s|/DATA/AppData/\$AppID|$base_path|g" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    fi
    
    # Add runtipi.managed label if requested
    if [[ "$add_runtipi_label" == "true" ]]; then
        # Get all services and add the runtipi.managed label
        local services
        services=$(yq eval '.services | keys | .[]' "$temp_file" 2>/dev/null)
        
        while IFS= read -r service; do
            [[ -z "$service" ]] && continue
            
            # Check if labels exists and what type it is
            local label_type
            label_type=$(yq eval ".services[\"$service\"].labels | type" "$temp_file" 2>/dev/null)
            
            if [[ "$label_type" == "!!seq" ]]; then
                # Labels is an array, convert to map first
                # Get existing labels
                local existing_labels
                existing_labels=$(yq eval ".services[\"$service\"].labels[]" "$temp_file" 2>/dev/null | while read -r label; do
                    # Parse key=value format
                    if [[ "$label" == *"="* ]]; then
                        key="${label%%=*}"
                        value="${label#*=}"
                        # Remove quotes if present
                        key="${key//\"/}"
                        value="${value//\"/}"
                        echo "  \"$key\": \"$value\""
                    fi
                done | paste -sd ',' -)
                
                # Replace array with map including the runtipi.managed label
                if [[ -n "$existing_labels" ]]; then
                    yq eval ".services[\"$service\"].labels = {$existing_labels, \"runtipi.managed\": \"true\"}" -i "$temp_file"
                else
                    yq eval ".services[\"$service\"].labels = {\"runtipi.managed\": \"true\"}" -i "$temp_file"
                fi
            else
                # Labels is already a map or doesn't exist, just add the label
                yq eval ".services[\"$service\"].labels.\"runtipi.managed\" = \"true\"" -i "$temp_file"
            fi
        done <<< "$services"
    fi
    
    mv "$temp_file" "$output_file"
}

# Initialize Portainer master template file
init_portainer_master_template() {
    local master_file="$OUTPUT_DIR/portainer/templates.json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    # Create the beginning of the master template file
    cat > "$master_file" << 'EOF'
{
  "version": "3",
  "templates": [
EOF
    
    # Initialize template ID counter
    echo "1" > "$OUTPUT_DIR/portainer/.template_id_counter"
}

# Finalize Portainer master template file
finalize_portainer_master_template() {
    local master_file="$OUTPUT_DIR/portainer/templates.json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    # Remove the trailing comma from the last template and close the JSON
    if [[ -f "$master_file" ]]; then
        # Only try to remove trailing comma if file exists and has content
        if [[ -s "$master_file" ]]; then
            # Use a more portable sed command that works on both Linux and macOS
            if [[ "$(tail -1 "$master_file")" == *"," ]]; then
                sed -i.bak '$ s/,$//' "$master_file" && rm -f "$master_file.bak"
            fi
        fi
        echo "  ]" >> "$master_file"
        echo "}" >> "$master_file"
        
        print_success "Created master Portainer template: $master_file"
    fi
}

# Convert to Portainer JSON template format
convert_to_portainer() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/portainer/$app_name"
    local master_file="$OUTPUT_DIR/portainer/templates.json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Portainer format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for Portainer template
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean and copy the docker-compose.yml file for Portainer to use
    # This is the actual stackfile that Portainer will deploy
    # Enable volume declarations for Portainer with app-specific prefix
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/docker-compose.yml" "./data" "true" "$app_name"
    
    # Escape quotes for JSON output (different from shell escaping)
    METADATA_TITLE_JSON="${METADATA_TITLE//\"/\\\"}"
    METADATA_DESCRIPTION_JSON="${METADATA_DESCRIPTION//\"/\\\"}"
    METADATA_TAGLINE_JSON="${METADATA_TAGLINE//\"/\\\"}"
    METADATA_DEVELOPER_JSON="${METADATA_DEVELOPER//\"/\\\"}"
    METADATA_AUTHOR_JSON="${METADATA_AUTHOR//\"/\\\"}"
    
    # Extract environment variables from docker-compose.yml
    local env_vars
    env_vars=$(yq eval '.services[].environment[]?' "$app_dir/docker-compose.yml" 2>/dev/null | while read -r env_line; do
        if [[ "$env_line" == *"="* ]]; then
            env_name="${env_line%%=*}"
            env_value="${env_line#*=}"
            # Remove surrounding quotes if present
            env_value="${env_value#\"}"
            env_value="${env_value%\"}"
            # Escape quotes and backslashes in the value
            env_value_escaped="${env_value//\\/\\\\}"  # Escape backslashes first
            env_value_escaped="${env_value_escaped//\"/\\\"}"  # Then escape quotes
            echo "    {\"name\": \"$env_name\", \"label\": \"$env_name\", \"description\": \"Environment variable for $env_name\", \"default\": \"$env_value_escaped\"},"
        fi
    done | sed '$ s/,$//')
    
    # Extract ports from docker-compose.yml
    local ports
    ports=$(yq eval '.services[].ports[]?' "$app_dir/docker-compose.yml" 2>/dev/null | grep -E '^[0-9]+:[0-9]+' | sed 's/^/    "/' | sed 's/$/"/' | tr '\n' ',' | sed 's/,$//')
    
    # Extract volumes from docker-compose.yml
    local volumes
    volumes=$(yq eval '.services[].volumes[]?' "$app_dir/docker-compose.yml" 2>/dev/null | while read -r volume_line; do
        if [[ "$volume_line" == *":"* && "$volume_line" != *"bind"* && "$volume_line" != *"volume"* ]]; then
            container_path="${volume_line#*:}"
            # Remove any additional options after second colon
            container_path="${container_path%%:*}"
            # Only include valid paths that start with /
            if [[ "$container_path" == /* ]]; then
                echo "    {\"container\": \"$container_path\"},"
            fi
        fi
    done | sed '$ s/,$//')
    
    # Get main Docker image
    local main_image
    main_image=$(yq eval '.services | to_entries | .[0].value.image' "$app_dir/docker-compose.yml" 2>/dev/null || echo "$METADATA_IMAGE:$METADATA_VERSION")
    
    # Get unique template ID for master template
    local template_id
    if [[ -f "$OUTPUT_DIR/portainer/.template_id_counter" ]]; then
        template_id=$(cat "$OUTPUT_DIR/portainer/.template_id_counter")
        echo $((template_id + 1)) > "$OUTPUT_DIR/portainer/.template_id_counter"
    else
        template_id=1
        echo "2" > "$OUTPUT_DIR/portainer/.template_id_counter"
    fi

        # Create individual Portainer app template JSON
        # For type 3 (compose) templates, only include basic info, repository, and env vars
        # Ports, volumes, and image info come from the docker-compose.yml file
        # Repository should point to big-bear-portainer where the docker-compose files will be synced
    cat > "$output_dir/template.json" << EOF
{
  "version": "3",
  "templates": [
    {
      "id": $template_id,
            "type": 3,
      "title": "$METADATA_TITLE_JSON",
      "name": "$METADATA_ID",
      "description": "$METADATA_DESCRIPTION_JSON",
      "note": "$METADATA_TAGLINE_JSON",
      "categories": ["$METADATA_CATEGORY", "selfhosted"],
      "platform": "linux",
      "logo": "$METADATA_ICON",
      "repository": {
        "url": "https://github.com/bigbeartechworld/big-bear-portainer",
        "stackfile": "Apps/$app_name/docker-compose.yml"
      }$(if [[ -n "$env_vars" ]]; then echo ",
      \"env\": [
$env_vars
      ]"; fi)
    }
  ]
}
EOF

    # Add this app to the master template file
    cat >> "$master_file" << EOF
    {
      "id": $template_id,
            "type": 3,
      "title": "$METADATA_TITLE_JSON",
      "name": "$METADATA_ID",
      "description": "$METADATA_DESCRIPTION_JSON",
      "note": "$METADATA_TAGLINE_JSON",
      "categories": ["$METADATA_CATEGORY", "selfhosted"],
      "platform": "linux",
      "logo": "$METADATA_ICON",
      "repository": {
        "url": "https://github.com/bigbeartechworld/big-bear-portainer",
        "stackfile": "Apps/$app_name/docker-compose.yml"
      }$(if [[ -n "$env_vars" ]]; then echo ",
      \"env\": [
$env_vars
      ]"; fi)
    },
EOF
    
    print_success "Converted $app_name for Portainer"
}

# Get existing port from destination repository if it exists
get_existing_runtipi_port() {
    local app_name="$1"
    
    # Check in workspace for existing Runtipi app
    local workspace_dir
    workspace_dir="$(dirname "$(dirname "$OUTPUT_DIR")")" || {
        print_error "Failed to determine workspace directory"
        return 1
    }
    local existing_config="$workspace_dir/big-bear-runtipi/apps/$app_name/config.json"
    
    if [[ -f "$existing_config" ]]; then
        local existing_port
        existing_port=$(jq -r '.port // empty' "$existing_config" 2>/dev/null)
        if [[ -n "$existing_port" && "$existing_port" != "null" ]]; then
            echo "$existing_port"
            return 0
        fi
    fi
    
    # No existing port found
    return 1
}

# Initialize port tracker with all existing ports from destination repositories
init_port_tracker() {
    local port_track_file="$OUTPUT_DIR/.port_tracker"
    local port_map_file="$OUTPUT_DIR/.port_map"
    
    # Clear any existing port tracker files
    : > "$port_track_file"
    : > "$port_map_file"
    
    # For each platform, scan existing apps and load their ports
    for platform in "${PLATFORMS[@]}"; do
        # Get the workspace directory (parent of the script directory)
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
            print_error "Failed to determine script directory"
            return 1
        }
        local workspace_dir
        workspace_dir="$(dirname "$script_dir")" || {
            print_error "Failed to determine workspace directory"
            return 1
        }
        local platform_apps_dir
        
        case "$platform" in
            runtipi)
                platform_apps_dir="$workspace_dir/big-bear-runtipi/apps"
                ;;
            umbrel)
                platform_apps_dir="$workspace_dir/big-bear-umbrel"
                ;;
            portainer)
                # Portainer uses templates, not individual config files with ports
                continue
                ;;
            *)
                continue
                ;;
        esac
        
        if [[ -d "$platform_apps_dir" ]]; then
            print_info "Loading existing ports from $platform..."
            local port_count=0
            
            # Temporarily disable errexit for port loading (errors are non-fatal)
            set +e
            
            if [[ "$platform" == "umbrel" ]]; then
                # Find all umbrel-app.yml files and extract ports
                while IFS= read -r app_config; do
                    if [[ -f "$app_config" ]]; then
                        local port app_id
                        port=$(yq eval '.port' "$app_config" 2>/dev/null)
                        app_id=$(yq eval '.id' "$app_config" 2>/dev/null)
                        
                        if [[ -n "$port" && "$port" != "null" && "$port" =~ ^[0-9]+$ ]]; then
                            echo "$port" >> "$port_track_file"
                            # Store app-to-port mapping (format: platform:app_name:port)
                            if [[ -n "$app_id" && "$app_id" != "null" ]]; then
                                # Extract base app name (remove big-bear-umbrel- prefix)
                                local base_name="${app_id#big-bear-umbrel-}"
                                echo "umbrel:$base_name:$port" >> "$port_map_file"
                            fi
                            ((port_count++)) || true
                        fi
                    fi
                done < <(find "$platform_apps_dir" -name "umbrel-app.yml" -type f 2>/dev/null)
            else
                # Find all config.json files and extract ports (for runtipi)
                while IFS= read -r config_file; do
                    if [[ -f "$config_file" ]]; then
                        local port app_id
                        port=$(jq -r '.port // empty' "$config_file" 2>/dev/null)
                        app_id=$(jq -r '.id // empty' "$config_file" 2>/dev/null)
                        
                        if [[ -n "$port" && "$port" != "null" && "$port" =~ ^[0-9]+$ ]]; then
                            echo "$port" >> "$port_track_file"
                            # Store app-to-port mapping
                            if [[ -n "$app_id" && "$app_id" != "null" ]]; then
                                echo "runtipi:$app_id:$port" >> "$port_map_file"
                            fi
                            ((port_count++)) || true
                        fi
                    fi
                done < <(find "$platform_apps_dir" -name "config.json" -type f 2>/dev/null)
            fi
            
            # Re-enable errexit
            set -e
            
            if [[ $port_count -gt 0 ]]; then
                print_success "Loaded $port_count existing ports from $platform"
            fi
        fi
    done
}

# Convert to Runtipi dynamic compose format
convert_to_runtipi() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/runtipi/$app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Runtipi format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for Runtipi
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose file for Runtipi (add standard docker-compose.yml with runtipi.managed label)
    # Parameters: input, output, base_path, add_volumes, app_prefix, add_runtipi_label
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/docker-compose.yml" "./data" "false" "" "true"
    
    # Post-process the docker-compose.yml for Runtipi-specific requirements
    local runtipi_compose="$output_dir/docker-compose.yml"
    
    # 1. Rename the main service to match the app ID
    # Get the first service name from the converted compose file
    local first_service
    first_service=$(yq eval '.services | keys | .[0]' "$runtipi_compose" 2>/dev/null)
    
    if [[ "$first_service" != "$app_name" && -n "$first_service" ]]; then
        # Rename the service to match app_name
        yq eval ".services.\"$app_name\" = .services.\"$first_service\" | del(.services.\"$first_service\")" -i "$runtipi_compose"
    fi
    
    # 2. Set container_name for the main service (should equal app_name)
    yq eval ".services[\"$app_name\"].container_name = \"$app_name\"" -i "$runtipi_compose"
    
    # Check if using network_mode: host
    local network_mode
    network_mode=$(yq eval ".services[\"$app_name\"].network_mode // \"\"" "$runtipi_compose" 2>/dev/null)
    local uses_host_network=false
    if [[ "$network_mode" == "host" ]]; then
        uses_host_network=true
        print_info "App $app_name uses network_mode: host, removing port mappings from compose file"
        # Remove ports section when using host networking (not needed with host mode)
        yq eval "del(.services[\"$app_name\"].ports)" -i "$runtipi_compose"
    fi
    
    # 3. Add tipi_main_network to all services (unless using host networking or in exceptions list)
    local services
    services=$(yq eval '.services | keys | .[]' "$runtipi_compose" 2>/dev/null)
    
    # Network exceptions list - apps that should not get tipi_main_network
    local network_exceptions=("matter-server" "mdns-repeater" "pihole" "tailscale" "homeassistant" "plex" "zerotier" "gladys" "scrypted" "homebridge" "cloudflared" "beszel-agent" "watchyourlan")
    local skip_network=false
    
    # Check if app is in exception list
    for exception in "${network_exceptions[@]}"; do
        if [[ "$app_name" == "$exception" ]]; then
            skip_network=true
            print_info "App $app_name is in network exceptions list, skipping tipi_main_network"
            break
        fi
    done
    
    # Also skip network config if using host networking
    if [[ "$uses_host_network" == "true" ]]; then
        skip_network=true
        print_info "App $app_name uses host networking, skipping tipi_main_network"
    fi
    
    if [[ "$skip_network" == "false" ]]; then
        while IFS= read -r service; do
            [[ -z "$service" ]] && continue
            
            # Check if the service already has networks defined
            local has_networks
            has_networks=$(yq eval ".services[\"$service\"].networks" "$runtipi_compose" 2>/dev/null)
            
            if [[ "$has_networks" == "null" ]]; then
                # No networks defined, add tipi_main_network as an array
                yq eval ".services[\"$service\"].networks = [\"tipi_main_network\"]" -i "$runtipi_compose"
            else
                # Networks exist, append tipi_main_network if not already present
                local network_type
                network_type=$(yq eval ".services[\"$service\"].networks | type" "$runtipi_compose" 2>/dev/null)
                
                if [[ "$network_type" == "!!seq" ]]; then
                    # Networks is an array, append if not present
                    local has_tipi_network
                    has_tipi_network=$(yq eval ".services[\"$service\"].networks[] | select(. == \"tipi_main_network\")" "$runtipi_compose" 2>/dev/null)
                    
                    if [[ -z "$has_tipi_network" ]]; then
                        yq eval ".services[\"$service\"].networks += [\"tipi_main_network\"]" -i "$runtipi_compose"
                    fi
                else
                    # Networks is a map/object, convert to array with tipi_main_network
                    yq eval ".services[\"$service\"].networks = [\"tipi_main_network\"]" -i "$runtipi_compose"
                fi
            fi
        done <<< "$services"
        
        # 4. Add tipi_main_network to the top-level networks section
        yq eval '.networks.tipi_main_network.external = true' -i "$runtipi_compose"
    fi
    
    # Extract services and convert to Runtipi JSON format
    local compose_file="$app_dir/docker-compose.yml"
    local services_json="[]"
    
    # Get main service name
    local main_service
    main_service=$(yq eval '.x-casaos.main // (keys | .[0])' "$compose_file" 2>/dev/null || echo "app")
    
    # Extract service information and convert to dynamic compose
    local main_service_data
    main_service_data=$(yq eval '.services | to_entries | .[0]' "$compose_file")
    
    # Extract internal port - if no ports defined in docker-compose, it will be set later from config.json port
    local internal_port
    local port_spec
    port_spec=$(echo "$main_service_data" | yq eval '.value.ports[0]' - 2>/dev/null)
    
    if [[ -n "$port_spec" && "$port_spec" != "null" ]]; then
        # Extract the container port (right side of the colon)
        # Handle formats like "8080:8080", "target: 8080", or just "8080"
        if [[ "$port_spec" =~ ^[0-9]+:[0-9]+$ ]]; then
            # Format: "host:container"
            internal_port=$(echo "$port_spec" | cut -d':' -f2)
        elif [[ "$port_spec" =~ ^[0-9]+$ ]]; then
            # Format: just the port number
            internal_port="$port_spec"
        else
            # Complex format or target format - try to extract number
            internal_port=$(echo "$port_spec" | grep -oE '[0-9]+' | head -1)
        fi
    fi
    
    # If internal_port is empty, null, or invalid, we'll use the runtipi_port that gets assigned later
    # For now, use a placeholder that will be replaced
    if [[ -z "$internal_port" || "$internal_port" == "null" ]]; then
        internal_port="__PORT_PLACEHOLDER__"
    fi
    
    cat > "$output_dir/docker-compose.json" << EOF
{
  "schemaVersion": 2,
  "services": [
    {
      "name": "$(echo "$main_service_data" | yq eval '.key' -)",
      "image": "$(echo "$main_service_data" | yq eval '.value.image' -)",
      "internalPort": $internal_port,
      "isMain": true
    }
  ]
}
EOF
    
    # Create config.json for Runtipi
    # Generate timestamps in milliseconds (Unix timestamp * 1000)
    local updated_at=$(($(date +%s) * 1000))
    local created_at=$updated_at  # Use same timestamp for created_at
    
    # Extract source URL and website from docker-compose.yml
    local source_url
    source_url=$(yq eval '.x-casaos.project_url // ""' "$compose_file" 2>/dev/null || echo "")
    
    local website_url
    website_url=$(yq eval '.x-casaos.index // ""' "$compose_file" 2>/dev/null || echo "$source_url")
    
    # Parse categories - convert single category to array format if needed
    local categories_json
    if [[ -n "$METADATA_CATEGORY" ]]; then
        categories_json="[\"$(echo "$METADATA_CATEGORY" | tr '[:upper:]' '[:lower:]')\"]"
    else
        categories_json="[\"utilities\"]"
    fi
    
    # Ensure port is valid for Runtipi (must be > 999)
    # First, check if this app already has a port assignment from the port map
    local runtipi_port=""
    local port_map_file="$OUTPUT_DIR/.port_map"
    if [[ -f "$port_map_file" ]]; then
        runtipi_port=$(grep "^runtipi:${app_name}:" "$port_map_file" 2>/dev/null | cut -d':' -f3)
        if [[ -n "$runtipi_port" ]]; then
            print_info "Preserving existing port $runtipi_port for $app_name"
        fi
    fi
    
    # If no port from map, try the old method (direct repository check)
    if [[ -z "$runtipi_port" ]] && runtipi_port=$(get_existing_runtipi_port "$app_name"); then
        print_info "Preserving existing port $runtipi_port for $app_name"
    fi
    
    # If still no port, assign a new one
    if [[ -z "$runtipi_port" ]]; then
        # Map common low ports to their high port equivalents
        runtipi_port="${METADATA_PORT_MAP:-8080}"
        if [[ "$runtipi_port" -le 999 ]]; then
            case "$runtipi_port" in
                80) runtipi_port=8080 ;;
                81) runtipi_port=8081 ;;
                443) runtipi_port=8443 ;;
                943) runtipi_port=9443 ;;
                *) 
                    # For other low ports, add 8000 to make them 4+ digits
                    runtipi_port=$((runtipi_port + 8000))
                    ;;
            esac
            print_warning "Port $METADATA_PORT_MAP is below 1000 for $app_name, mapped to $runtipi_port for Runtipi"
        fi
        
        # Check for port conflicts and auto-increment if needed
        local port_track_file="$OUTPUT_DIR/.port_tracker"
        if [[ -f "$port_track_file" ]]; then
            # Check if this port is already used
            while grep -q "^${runtipi_port}$" "$port_track_file" 2>/dev/null; do
                print_warning "Port $runtipi_port already used, incrementing to avoid conflict"
                runtipi_port=$((runtipi_port + 1))
            done
        fi
        
        # Track this port and save the mapping for future conversions
        echo "$runtipi_port" >> "$port_track_file"
        echo "runtipi:$app_name:$runtipi_port" >> "$port_map_file"
    fi
    
    # Escape special characters in JSON strings
    local escaped_description="${METADATA_DESCRIPTION//\\/\\\\}"  # Escape backslashes first
    escaped_description="${escaped_description//\"/\\\"}"         # Escape quotes
    escaped_description="${escaped_description//$'\n'/\\n}"       # Escape newlines
    escaped_description="${escaped_description//$'\r'/}"          # Remove carriage returns
    escaped_description="${escaped_description//$'\t'/ }"         # Replace tabs with spaces
    
    local escaped_tagline="${METADATA_TAGLINE//\\/\\\\}"
    escaped_tagline="${escaped_tagline//\"/\\\"}"
    escaped_tagline="${escaped_tagline//$'\n'/\\n}"
    escaped_tagline="${escaped_tagline//$'\r'/}"
    
    cat > "$output_dir/config.json" << EOF
{
  "name": "$METADATA_TITLE",
  "available": true,
  "port": ${runtipi_port},
  "exposable": true,
  "dynamic_config": true,
  "id": "$METADATA_ID",
  "description": "$escaped_description",
  "tipi_version": 1,
  "version": "$METADATA_VERSION",
  "categories": $categories_json,
  "short_desc": "$escaped_tagline",
  "author": "$METADATA_DEVELOPER",
  "source": "$source_url",
  "website": "$website_url",
  "supported_architectures": ["arm64", "amd64"],
  "created_at": $created_at,
  "updated_at": $updated_at,
  "\$schema": "../app-info-schema.json",
  "min_tipi_version": "4.5.0"
}
EOF
    
    # Replace port placeholder in docker-compose.json if it exists
    if grep -q "__PORT_PLACEHOLDER__" "$output_dir/docker-compose.json" 2>/dev/null; then
        sed -i.bak "s/__PORT_PLACEHOLDER__/$runtipi_port/" "$output_dir/docker-compose.json"
        rm -f "$output_dir/docker-compose.json.bak"
    fi
    
    # Create metadata directory
    mkdir -p "$output_dir/metadata"
    echo "$METADATA_DESCRIPTION" > "$output_dir/metadata/description.md"
    
    # Download and convert icon to logo.jpg
    if [[ -n "$METADATA_ICON" && "$METADATA_ICON" != "null" ]]; then
        # Download the icon
        if curl -fsSL "$METADATA_ICON" -o "$output_dir/metadata/logo_temp" 2>/dev/null; then
            # Detect file type
            local file_type
            file_type=$(file -b --mime-type "$output_dir/metadata/logo_temp" 2>/dev/null || echo "unknown")
            
            # Check if conversion is needed (not already JPEG)
            if [[ "$file_type" == "image/jpeg" ]]; then
                # Already JPEG, just rename
                mv "$output_dir/metadata/logo_temp" "$output_dir/metadata/logo.jpg"
            elif command -v convert &> /dev/null; then
                # Use ImageMagick convert (available on most Linux systems including Ubuntu GitHub runners)
                convert "$output_dir/metadata/logo_temp" "$output_dir/metadata/logo.jpg" 2>/dev/null && rm -f "$output_dir/metadata/logo_temp"
            elif command -v ffmpeg &> /dev/null; then
                # Use ffmpeg as fallback (often available on Ubuntu)
                ffmpeg -i "$output_dir/metadata/logo_temp" "$output_dir/metadata/logo.jpg" -y &>/dev/null && rm -f "$output_dir/metadata/logo_temp"
            elif command -v sips &> /dev/null; then
                # Use macOS sips as fallback
                sips -s format jpeg "$output_dir/metadata/logo_temp" --out "$output_dir/metadata/logo.jpg" &>/dev/null && rm -f "$output_dir/metadata/logo_temp"
            else
                # No conversion tool available - try renaming anyway
                print_warning "No image conversion tool found (convert, ffmpeg, or sips) for $app_name"
                mv "$output_dir/metadata/logo_temp" "$output_dir/metadata/logo.jpg"
            fi
            
            # Verify the file was created
            if [[ ! -f "$output_dir/metadata/logo.jpg" ]]; then
                print_warning "Failed to create logo.jpg for $app_name, creating placeholder"
                # Create a minimal placeholder JPEG if download/conversion failed
                create_placeholder_logo "$output_dir/metadata/logo.jpg"
            fi
        else
            print_warning "Failed to download icon for $app_name from $METADATA_ICON"
            # Create a placeholder image
            create_placeholder_logo "$output_dir/metadata/logo.jpg"
        fi
    else
        print_warning "No icon URL found for $app_name, creating placeholder"
        # Create a placeholder image
        create_placeholder_logo "$output_dir/metadata/logo.jpg"
    fi
    
    print_success "Converted $app_name for Runtipi"
}

# Convert to Dockge format (standard Docker Compose + metadata.json)
convert_to_dockge() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/dockge/$app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Dockge format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for Dockge
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose file for Dockge (most compatible format)
    # Enable volume declarations for Dockge with app-specific prefix
    # Dockge uses compose.yaml as the standard filename
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/compose.yaml" "./data" "true" "$app_name"
    
    # Create metadata.json file for Dockge stack
    cat > "$output_dir/metadata.json" << EOF
{
  "name": "$METADATA_TITLE",
  "id": "$METADATA_ID",
  "description": "$METADATA_DESCRIPTION",
  "tagline": "$METADATA_TAGLINE",
  "icon": "$METADATA_ICON",
  "thumbnail": "$METADATA_THUMBNAIL",
  "author": "$METADATA_AUTHOR",
  "developer": "$METADATA_DEVELOPER",
  "category": "$METADATA_CATEGORY",
  "version": "$METADATA_VERSION",
  "image": "$METADATA_IMAGE",
  "port": "$METADATA_PORT_MAP",
  "youtube": "$METADATA_YOUTUBE",
  "docs": "$METADATA_DOCS_LINK",
  "tags": [
    "selfhosted",
    "docker",
    "bigbear",
    "$(echo "$METADATA_CATEGORY" | tr '[:upper:]' '[:lower:]')"
  ],
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "big-bear-casaos"
}
EOF
    
    print_success "Converted $app_name for Dockge"
}

# Convert to Cosmos format (cosmos-compose.json + description.json)
convert_to_cosmos() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/cosmos/$app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Cosmos format"
        return
    fi
    
    mkdir -p "$output_dir"
    mkdir -p "$output_dir/screenshots"
    
    # Extract metadata
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Get the docker-compose content
    local compose_file="$app_dir/docker-compose.yml"
    
    # Extract main service name
    local main_service
    main_service=$(yq eval '.services | keys | .[0]' "$compose_file" 2>/dev/null || echo "app")
    
    # Extract port from docker-compose.yml
    local internal_port=""
    local port_spec
    port_spec=$(yq eval ".services[\"$main_service\"].ports[0]" "$compose_file" 2>/dev/null)
    
    if [[ -n "$port_spec" && "$port_spec" != "null" ]]; then
        if [[ "$port_spec" =~ ^[0-9]+:([0-9]+) ]]; then
            internal_port="${BASH_REMATCH[1]}"
        elif [[ "$port_spec" =~ :([0-9]+)$ ]]; then
            internal_port="${BASH_REMATCH[1]}"
        fi
    fi
    
    # Fallback to METADATA_PORT_MAP if no port found
    if [[ -z "$internal_port" || "$internal_port" == "null" ]]; then
        internal_port="$METADATA_PORT_MAP"
    fi
    
    # Extract image
    local image
    image=$(yq eval ".services[\"$main_service\"].image" "$compose_file" 2>/dev/null || echo "")
    
    # Extract environment variables (handles both array and object formats)
    local env_vars_json="["
    local env_count=0
    
    # First check if environment is an object or array
    local env_type
    env_type=$(yq eval ".services[\"$main_service\"].environment | type" "$compose_file" 2>/dev/null || echo "null")
    
    if [[ "$env_type" == "!!map" ]]; then
        # Environment is an object (key: value pairs)
        while IFS= read -r env_line; do
            if [[ -n "$env_line" && "$env_line" != "null" ]]; then
                if [[ $env_count -gt 0 ]]; then
                    env_vars_json+=","
                fi
                # Escape special characters for JSON (backslashes first, then quotes)
                local escaped_env="${env_line//\\/\\\\}"
                escaped_env="${escaped_env//\"/\\\"}"
                env_vars_json+=$'\n'"        \"$escaped_env\""
                ((env_count++)) || true
            fi
        done < <(yq eval ".services[\"$main_service\"].environment | to_entries | .[] | .key + \"=\" + .value" "$compose_file" 2>/dev/null)
    else
        # Environment is an array (key=value format)
        while IFS= read -r env_line; do
            if [[ -n "$env_line" && "$env_line" != "null" ]]; then
                if [[ $env_count -gt 0 ]]; then
                    env_vars_json+=","
                fi
                # Escape special characters for JSON (backslashes first, then quotes)
                local escaped_env="${env_line//\\/\\\\}"
                escaped_env="${escaped_env//\"/\\\"}"
                env_vars_json+=$'\n'"        \"$escaped_env\""
                ((env_count++)) || true
            fi
        done < <(yq eval ".services[\"$main_service\"].environment[]?" "$compose_file" 2>/dev/null)
    fi
    
    env_vars_json+=$'\n'"      ]"
    
    # Extract volumes and convert to Cosmos format
    local volumes_json=""
    local volume_count=0
    while IFS= read -r volume_line; do
        if [[ -n "$volume_line" && "$volume_line" != "null" ]]; then
            if [[ $volume_count -gt 0 ]]; then
                volumes_json+=","
            fi
            
            # Parse volume specification
            local source="" target="" vol_type="volume"
            if [[ "$volume_line" =~ ^(.+):(.+)$ ]]; then
                source="${BASH_REMATCH[1]}"
                target="${BASH_REMATCH[2]}"
                
                # Determine volume type
                if [[ "$source" =~ ^[./] ]]; then
                    vol_type="bind"
                    source="{DefaultDataPath}/${app_name}${source#.}"
                else
                    vol_type="volume"
                    source="{ServiceName}-${source}"
                fi
            fi
            
            # Escape special characters for JSON
            local escaped_source="${source//\\/\\\\}"
            escaped_source="${escaped_source//\"/\\\"}"
            local escaped_target="${target//\\/\\\\}"
            escaped_target="${escaped_target//\"/\\\"}"
            
            volumes_json+=$'\n'"        {"
            volumes_json+=$'\n'"          \"source\": \"$escaped_source\","
            volumes_json+=$'\n'"          \"target\": \"$escaped_target\","
            volumes_json+=$'\n'"          \"type\": \"$vol_type\""
            volumes_json+=$'\n'"        }"
            ((volume_count++)) || true
        fi
    done < <(yq eval ".services[\"$main_service\"].volumes[]?" "$compose_file" 2>/dev/null)
    
    # Extract restart policy
    local restart_policy
    restart_policy=$(yq eval ".services[\"$main_service\"].restart // \"unless-stopped\"" "$compose_file" 2>/dev/null)
    
    # Get icon URL - use Cosmos servapps CDN format
    local icon_url="https://azukaar.github.io/cosmos-servapps-official/servapps/${app_name}/icon.png"
    
    # Create cosmos-compose.json
    cat > "$output_dir/cosmos-compose.json" << EOF
{
  "cosmos-installer": {},
  "minVersion": "0.7.6",
  "services": {
    "{ServiceName}": {
      "image": "$image",
      "container_name": "{ServiceName}",
      "restart": "$restart_policy",
      "UID": 1000,
      "GID": 1000,
      "environment": $env_vars_json,
      "labels": {
        "cosmos-force-network-secured": "true",
        "cosmos-auto-update": "true",
        "cosmos-icon": "$icon_url"
      },
      "volumes": [$volumes_json
      ],
      "routes": [
        {
          "name": "{ServiceName}",
          "description": "Expose {ServiceName} to the web",
          "useHost": true,
          "target": "http://{ServiceName}:${internal_port}",
          "mode": "SERVAPP",
          "Timeout": 14400000,
          "ThrottlePerMinute": 12000,
          "BlockCommonBots": true,
          "SmartShield": {
            "Enabled": true
          }
        }
      ]
    }
  }
}
EOF
    
    # Escape special characters for JSON
    local escaped_description="${METADATA_DESCRIPTION//\\/\\\\}"
    escaped_description="${escaped_description//\"/\\\"}"
    escaped_description="${escaped_description//$'\n'/ }"
    escaped_description="${escaped_description//$'\r'/}"
    
    local escaped_tagline="${METADATA_TAGLINE//\\/\\\\}"
    escaped_tagline="${escaped_tagline//\"/\\\"}"
    escaped_tagline="${escaped_tagline//$'\n'/ }"
    escaped_tagline="${escaped_tagline//$'\r'/}"
    
    # Convert category to tags array
    local tags_json="[\"self-hosted\""
    if [[ -n "$METADATA_CATEGORY" && "$METADATA_CATEGORY" != "null" ]]; then
        tags_json+=", \"$METADATA_CATEGORY\""
    fi
    tags_json+="]"
    
    # Get source URLs
    local repository_url
    repository_url=$(yq eval '.x-casaos.project_url // ""' "$compose_file" 2>/dev/null || echo "")
    
    # Create description.json
    cat > "$output_dir/description.json" << EOF
{
  "name": "$METADATA_TITLE",
  "description": "$escaped_tagline",
  "longDescription": "<p>$escaped_description</p>",
  "tags": $tags_json,
  "repository": "$repository_url",
  "image": "https://hub.docker.com/r/${image%%:*}",
  "supported_architectures": ["amd64", "arm64"]
}
EOF
    
    # Copy or download icon
    if [[ -f "$app_dir/icon.png" ]]; then
        cp "$app_dir/icon.png" "$output_dir/icon.png"
    elif [[ -n "$METADATA_ICON" && "$METADATA_ICON" != "null" ]]; then
        # Try to download the icon
        if command -v curl &> /dev/null; then
            curl -sL "$METADATA_ICON" -o "$output_dir/icon.png" 2>/dev/null || create_placeholder_logo "$output_dir/icon.png"
        elif command -v wget &> /dev/null; then
            wget -q "$METADATA_ICON" -O "$output_dir/icon.png" 2>/dev/null || create_placeholder_logo "$output_dir/icon.png"
        else
            create_placeholder_logo "$output_dir/icon.png"
        fi
    else
        create_placeholder_logo "$output_dir/icon.png"
    fi
    
    # Copy screenshots if they exist
    if [[ -d "$app_dir/screenshots" ]]; then
        cp -r "$app_dir/screenshots/"* "$output_dir/screenshots/" 2>/dev/null || true
    fi
    
    print_success "Converted $app_name for Cosmos"
}

# Convert to Universal format (comprehensive platform-agnostic format)
convert_to_universal() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/universal/$app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Universal format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for universal format
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose file
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/docker-compose.yml" "./data"
    
    # Extract detailed service information from docker-compose.yml
    local services_json="[]"
    local compose_file="$app_dir/docker-compose.yml"
    
    # Get all services and their details (using JSON output)
    services_json=$(yq eval -o=json '.services | to_entries | map({
        "name": .key,
        "image": .value.image,
        "container_name": (.value.container_name // .key),
        "ports": (.value.ports // []),
        "volumes": (.value.volumes // []),
        "environment": (.value.environment // []),
        "restart": (.value.restart // ""),
        "depends_on": (.value.depends_on // []),
        "networks": (.value.networks // []),
        "command": (.value.command // ""),
        "entrypoint": (.value.entrypoint // ""),
        "working_dir": (.value.working_dir // ""),
        "user": (.value.user // ""),
        "privileged": (.value.privileged // false),
        "labels": (.value.labels // {})
    })' "$compose_file" 2>/dev/null || echo "[]")
    
    # Extract networks
    local networks_json
    networks_json=$(yq eval -o=json '.networks // {}' "$compose_file" 2>/dev/null || echo "{}")
    
    # Extract volumes
    local volumes_json
    volumes_json=$(yq eval -o=json '.volumes // {}' "$compose_file" 2>/dev/null || echo "{}")
    
    # Get CasaOS specific information
    local architectures
    architectures=$(yq eval -o=json '.x-casaos.architectures // ["amd64", "arm64"]' "$compose_file" 2>/dev/null || echo '["amd64", "arm64"]')
    
    local main_service
    main_service=$(yq eval '.x-casaos.main // ""' "$compose_file" 2>/dev/null || echo "")
    
    local tips
    tips=$(yq eval -o=json '.x-casaos.tips // {}' "$compose_file" 2>/dev/null || echo "{}")
    
    local screenshots
    screenshots=$(yq eval -o=json '.x-casaos.screenshot_link // []' "$compose_file" 2>/dev/null || echo "[]")
    
    # Create comprehensive universal format
    cat > "$output_dir/app.json" << EOF
{
  "spec_version": "1.0",
  "metadata": {
    "id": "$METADATA_ID",
    "name": "$METADATA_TITLE",
    "description": "$METADATA_DESCRIPTION",
    "tagline": "$METADATA_TAGLINE",
    "version": "$METADATA_VERSION",
    "author": "$METADATA_AUTHOR",
    "developer": "$METADATA_DEVELOPER",
    "category": "$METADATA_CATEGORY",
    "source": "big-bear-casaos",
    "license": "",
    "homepage": "",
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "visual": {
    "icon": "$METADATA_ICON",
    "thumbnail": "$METADATA_THUMBNAIL",
    "screenshots": $screenshots,
    "logo": "$METADATA_ICON"
  },
  "resources": {
    "youtube": "$METADATA_YOUTUBE",
    "documentation": "$METADATA_DOCS_LINK",
    "repository": "https://github.com/bigbeartechworld/big-bear-casaos",
    "issues": "https://github.com/bigbeartechworld/big-bear-casaos/issues",
    "support": "https://community.bigbeartechworld.com/"
  },
  "technical": {
    "architectures": $architectures,
    "platform": "linux",
    "main_service": "$main_service",
    "default_port": "$METADATA_PORT_MAP",
    "main_image": "$METADATA_IMAGE:$METADATA_VERSION",
    "compose_file": "docker-compose.yml"
  },
  "deployment": {
    "services": $services_json,
    "networks": $networks_json,
    "volumes": $volumes_json
  },
  "ui": {
    "tips": $tips,
    "port_map": "$METADATA_PORT_MAP",
    "scheme": "http"
  },
  "compatibility": {
    "portainer": {
      "template_type": 2,
      "categories": ["$METADATA_CATEGORY", "selfhosted"],
      "administrator_only": false
    },
    "runtipi": {
      "available": true,
      "tipi_version": 1,
      "supported_architectures": $architectures
    },
    "dockge": {
      "supported": true,
      "file_based": true
    },
    "cosmos": {
      "servapp": true,
      "routes_required": true
    }
  },
  "tags": [
    "selfhosted",
    "docker",
    "bigbear",
    "$(echo "$METADATA_CATEGORY" | tr '[:upper:]' '[:lower:]')",
    "container"
  ]
}
EOF
    
    print_success "Converted $app_name for Universal format"
}

# Convert to Umbrel format (umbrel-app.yml + docker-compose.yml)
convert_to_umbrel() {
    local app_name="$1"
    local app_dir="$2"
    # Umbrel app ID and folder name both use the big-bear-umbrel- prefix
    local umbrel_app_name="big-bear-umbrel-$app_name"
    local output_dir="$OUTPUT_DIR/umbrel/$umbrel_app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Umbrel format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for Umbrel format
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose file for Umbrel - use APP_DATA_DIR for app data
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/docker-compose.yml" "\${APP_DATA_DIR}"
    
    # Get main service name from docker-compose.yml
    local main_service
    main_service=$(yq eval '.services | keys | .[0]' "$app_dir/docker-compose.yml" 2>/dev/null || echo "app")
    
    # Check if main service uses network_mode: host
    local uses_host_network=false
    local network_mode_check
    network_mode_check=$(yq eval ".services[\"$main_service\"].network_mode // \"\"" "$app_dir/docker-compose.yml" 2>/dev/null)
    if [[ "$network_mode_check" == "host" ]]; then
        uses_host_network=true
        print_info "App $app_name uses network_mode: host"
    fi
    
    # Umbrel base port for safer port allocation (avoids common 8000s conflicts)
    local UMBREL_BASE_PORT=10000
    
    # Extract ports from docker-compose.yml
    # For Umbrel we need TWO ports:
    # 1. host_port (umbrel-app.yml "port" field) - unique public port, must be stable
    # 2. container_port (APP_PORT in docker-compose.yml) - internal port app listens on
    local host_port
    local container_port
    local port_spec
    port_spec=$(yq eval '.services[].ports[0]' "$app_dir/docker-compose.yml" 2>/dev/null | head -1)
    
    if [[ -n "$port_spec" && "$port_spec" != "null" ]]; then
        if [[ "$port_spec" =~ ^[0-9]+:[0-9]+$ ]]; then
            # Format: "host:container" - extract both sides
            host_port=$(echo "$port_spec" | cut -d':' -f1)
            container_port=$(echo "$port_spec" | cut -d':' -f2)
        elif [[ "$port_spec" =~ ^[0-9]+$ ]]; then
            # Format: just the port number - use for both
            host_port="$port_spec"
            container_port="$port_spec"
        else
            # Complex format - try to extract both (e.g., "8080:8000/tcp")
            local clean_spec=$(echo "$port_spec" | sed 's|/.*||')
            if [[ "$clean_spec" =~ : ]]; then
                host_port=$(echo "$clean_spec" | cut -d':' -f1)
                container_port=$(echo "$clean_spec" | cut -d':' -f2)
            else
                # Fallback to extracting first number
                host_port=$(echo "$port_spec" | grep -oE '[0-9]+' | head -1)
                container_port="$host_port"
            fi
        fi
    fi
    
    # If host_port is still empty, null, or less than 1000, use METADATA_PORT_MAP
    if [[ -z "$host_port" || "$host_port" == "null" || ! "$host_port" =~ ^[0-9]+$ || "$host_port" -lt 1000 ]]; then
        host_port="${METADATA_PORT_MAP:-8080}"
        
        # Map common low ports to higher ports for the public/host port
        case "$host_port" in
            80) host_port=8080 ;;
            81) host_port=8081 ;;
            443) host_port=8443 ;;
            943) host_port=9943 ;;
            22) host_port=2222 ;;
            21) host_port=2121 ;;
            25) host_port=2525 ;;
        esac
    fi
    
    # If container_port is empty, use host_port as fallback
    if [[ -z "$container_port" || "$container_port" == "null" ]]; then
        container_port="$host_port"
    fi
    
    # Remap host_port to safer 10000+ range to avoid common port conflicts
    # Keep container_port as-is (internal app port)
    if [[ "$host_port" -lt "$UMBREL_BASE_PORT" ]]; then
        # Calculate sequential port from base
        local port_sequence_file="$OUTPUT_DIR/.port_sequence"
        if [[ ! -f "$port_sequence_file" ]]; then
            echo "$UMBREL_BASE_PORT" > "$port_sequence_file"
        fi
        
        # Read next available port
        local next_port=$(cat "$port_sequence_file")
        host_port="$next_port"
        
        # Increment for next app
        echo $((next_port + 1)) > "$port_sequence_file"
    fi
    
    # Check if this app already has a port assignment in the destination repository
    local port_map_file="$OUTPUT_DIR/.port_map"
    local existing_host_port=""
    if [[ -f "$port_map_file" ]]; then
        existing_host_port=$(grep "^umbrel:${app_name}:" "$port_map_file" 2>/dev/null | cut -d':' -f3)
        if [[ -n "$existing_host_port" ]]; then
            print_info "Preserving existing port $existing_host_port for $app_name"
            host_port="$existing_host_port"
        fi
    fi
    
    # Only check for conflicts if we don't have an existing port assignment
    if [[ -z "$existing_host_port" ]]; then
        # Check for port conflicts using the port tracker
        local port_track_file="$OUTPUT_DIR/.port_tracker"
        if [[ -f "$port_track_file" ]]; then
            while grep -q "^$host_port$" "$port_track_file"; do
                print_warning "Port $host_port already used, incrementing to avoid conflict"
                host_port=$((host_port + 1))
            done
        fi
        
        # Track this port and save the mapping for future conversions
        echo "$host_port" >> "$port_track_file"
        echo "umbrel:$app_name:$host_port" >> "$port_map_file"
    fi
    
    # Extract dependencies (if any)
    local dependencies
    dependencies=$(yq eval -o=json '.x-casaos.dependencies // []' "$app_dir/docker-compose.yml" 2>/dev/null || echo "[]")
    
    # Convert dependencies to YAML list format
    local deps_yaml=""
    if [[ "$dependencies" != "[]" ]]; then
        deps_yaml=$(echo "$dependencies" | jq -r '.[] | "  - " + .')
    fi
    
    # Get website URL with fallback
    local website_url
    website_url=$(yq eval '.x-casaos.project_url // ""' "$app_dir/docker-compose.yml" 2>/dev/null || echo "")
    if [[ -z "$website_url" || "$website_url" == "null" ]]; then
        website_url="https://github.com/bigbeartechworld/big-bear-casaos"
    fi
    
    # Get icon URL with fallback
    local icon_url
    icon_url="$METADATA_ICON"
    if [[ -z "$icon_url" || "$icon_url" == "null" ]]; then
        icon_url="https://cdn.jsdelivr.net/gh/bigbeartechworld/big-bear-casaos@master/Apps/${app_name}/icon.png"
    fi
    
    # Get developer with fallback
    local developer
    developer="$METADATA_DEVELOPER"
    if [[ -z "$developer" || "$developer" == "null" ]]; then
        developer="BigBearTechWorld"
    fi
    
    # Create umbrel-app.yml manifest with full app name including prefix
    # For network_mode: host apps, use container_port (the actual port the app binds to)
    # For normal apps, use host_port (the remapped public port)
    local umbrel_port
    if [[ "$uses_host_network" == "true" ]]; then
        umbrel_port="$container_port"
        print_info "Using container port $container_port for umbrel-app.yml (network_mode: host)"
    else
        umbrel_port="$host_port"
    fi
    
    # Quote tagline if it contains colon (common YAML issue)
    local tagline_value="$METADATA_TAGLINE"
    if [[ "$tagline_value" == *:* ]] || [[ "$tagline_value" == *\#* ]] || [[ "$tagline_value" == *\[* ]] || [[ "$tagline_value" == *\{* ]]; then
        # Escape any existing quotes in the tagline
        local escaped_tagline="${METADATA_TAGLINE//\"/\\\"}"
        tagline_value="\"$escaped_tagline\""
    fi
    
    cat > "$output_dir/umbrel-app.yml" << EOF
manifestVersion: 1
id: $umbrel_app_name
category: $METADATA_CATEGORY
name: $METADATA_TITLE
version: "$METADATA_VERSION"
tagline: $tagline_value
description: >-
  $METADATA_DESCRIPTION
releaseNotes: >-
  This version includes various improvements and bug fixes.
developer: $developer
website: $website_url
dependencies:$(if [[ -n "$deps_yaml" ]]; then echo "
$deps_yaml"; else echo " []"; fi)
repo: https://github.com/bigbeartechworld/big-bear-casaos
support: https://github.com/bigbeartechworld/big-bear-casaos/issues
port: $umbrel_port
gallery:
  - 1.jpg
  - 2.jpg
  - 3.jpg
path: ""
defaultUsername: ""
defaultPassword: ""
icon: $icon_url
submitter: BigBearTechWorld
submission: https://github.com/bigbeartechworld/big-bear-casaos
EOF
    
    # Update docker-compose.yml to use Umbrel-compatible format
    local temp_compose="${output_dir}/docker-compose.tmp.yml"
    local final_compose="${output_dir}/docker-compose.yml"
    
    # Step 1: Add version: "3.7" at the top and remove incompatible fields
    # For network_mode: only delete if NOT set to "host" (host networking is valid for Umbrel)
    yq eval 'del(.name) | 
             del(.services[].ports) | 
             del(.services[].container_name) | 
             (.services[] | select(.network_mode != "host") | .network_mode) |= null |
             del(.services[] | select(.network_mode == null) | .network_mode) |
             . = {"version": "3.7"} + .' "$final_compose" > "$temp_compose"
    mv "$temp_compose" "$final_compose"
    
    # Step 2: Remove all comments from the YAML file
    # Umbrel apps should be clean without CasaOS-specific comments
    # Remove both comment-only lines and inline comments
    sed -E 's/[[:space:]]*#.*$//g; /^[[:space:]]*$/d' "$final_compose" > "$temp_compose"
    mv "$temp_compose" "$final_compose"
    
    # Check if main service uses network_mode: host
    local uses_host_network=false
    local network_mode_value
    network_mode_value=$(yq eval ".services[\"$main_service\"].network_mode // \"\"" "$final_compose" 2>/dev/null)
    if [[ "$network_mode_value" == "host" ]]; then
        uses_host_network=true
        print_info "App $app_name uses network_mode: host, skipping app_proxy service"
    fi
    
    # Step 3: Add or update app_proxy service (only if not using host networking)
    # APP_HOST: container name that proxy connects to
    # APP_PORT: container's internal port (what the app listens on inside the container)
    if [[ "$uses_host_network" == "false" ]]; then
        if yq eval '.services.app_proxy' "$final_compose" > /dev/null 2>&1; then
            # Update existing app_proxy
            yq eval ".services.app_proxy.environment.APP_HOST = \"${umbrel_app_name}_${main_service}_1\" | 
                     .services.app_proxy.environment.APP_PORT = \"$container_port\"" "$final_compose" > "$temp_compose"
            mv "$temp_compose" "$final_compose"
        else
            # Add new app_proxy service at the beginning of services
            yq eval ".services = {\"app_proxy\": {\"environment\": {\"APP_HOST\": \"${umbrel_app_name}_${main_service}_1\", \"APP_PORT\": \"$container_port\"}}} + .services" "$final_compose" > "$temp_compose"
            mv "$temp_compose" "$final_compose"
        fi
    fi
    
    # Create data directory with .gitkeep (standard Umbrel app structure)
    mkdir -p "$output_dir/data"
    touch "$output_dir/data/.gitkeep"
    
    print_success "Converted $app_name for Umbrel"
}

# Validate app directory and files
validate_app() {
    local app_name="$1"
    local app_dir="$2"
    
    if [[ ! -d "$app_dir" ]]; then
        print_error "App directory not found: $app_dir"
        return 1
    fi
    
    if [[ ! -f "$app_dir/config.json" ]]; then
        print_warning "Missing config.json for $app_name"
        return 1
    fi
    
    if [[ ! -f "$app_dir/docker-compose.yml" ]]; then
        print_warning "Missing docker-compose.yml for $app_name"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq . "$app_dir/config.json" >/dev/null 2>&1; then
        print_error "Invalid JSON in config.json for $app_name"
        return 1
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$app_dir/docker-compose.yml" >/dev/null 2>&1; then
        print_error "Invalid YAML in docker-compose.yml for $app_name"
        return 1
    fi
    
    return 0
}

# Convert a single app
convert_app() {
    local app_name="$1"
    local app_dir="$APPS_DIR/$app_name"
    
    # Validate app before conversion
    if ! validate_app "$app_name" "$app_dir"; then
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Converting $app_name..."
    fi
    
    local platform_errors=0
    for platform in "${PLATFORMS[@]}"; do
        if [[ "$DRY_RUN" != "true" ]]; then
            case "$platform" in
                portainer) 
                    if ! convert_to_portainer "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Portainer format"
                        ((platform_errors++))
                    fi
                    ;;
                runtipi) 
                    if ! convert_to_runtipi "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Runtipi format"
                        ((platform_errors++))
                    fi
                    ;;
                dockge) 
                    if ! convert_to_dockge "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Dockge format"
                        ((platform_errors++))
                    fi
                    ;;
                cosmos) 
                    if ! convert_to_cosmos "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Cosmos format"
                        ((platform_errors++))
                    fi
                    ;;
                universal) 
                    if ! convert_to_universal "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Universal format"
                        ((platform_errors++))
                    fi
                    ;;
                umbrel) 
                    if ! convert_to_umbrel "$app_name" "$app_dir"; then
                        print_error "Failed to convert $app_name to Umbrel format"
                        ((platform_errors++))
                    fi
                    ;;
                *)
                    print_warning "Unknown platform: $platform"
                    ((platform_errors++))
                    ;;
            esac
        else
            # Dry run mode
            case "$platform" in
                portainer) print_info "DRY RUN: Would convert $app_name to Portainer format" ;;
                runtipi) print_info "DRY RUN: Would convert $app_name to Runtipi format" ;;
                dockge) print_info "DRY RUN: Would convert $app_name to Dockge format" ;;
                cosmos) print_info "DRY RUN: Would convert $app_name to Cosmos format" ;;
                universal) print_info "DRY RUN: Would convert $app_name to Universal format" ;;
                umbrel) print_info "DRY RUN: Would convert $app_name to Umbrel format" ;;
                *) print_warning "Unknown platform: $platform" ;;
            esac
        fi
    done
    
    return $platform_errors
}

# Main conversion function
main() {
    parse_args "$@"
    
    print_info "Big Bear CasaOS App Converter"
    print_info "Input: $APPS_DIR"
    print_info "Output: $OUTPUT_DIR"
    print_info "Platforms: ${PLATFORMS[*]}"
    
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        print_info "Validation mode - checking app configurations"
        local total_apps=0
        local valid_apps=0
        
        if [[ -n "$SINGLE_APP" ]]; then
            print_info "Validating single app: $SINGLE_APP"
            if validate_app "$SINGLE_APP" "$APPS_DIR/$SINGLE_APP"; then
                print_success "$SINGLE_APP is valid"
                exit 0
            else
                print_error "$SINGLE_APP has validation errors"
                exit 1
            fi
        else
            for app_dir in "$APPS_DIR"/*; do
                if [[ -d "$app_dir" && "$(basename "$app_dir")" != "__tests__" ]]; then
                    app_name=$(basename "$app_dir")
                    ((total_apps++))
                    
                    if validate_app "$app_name" "$app_dir"; then
                        ((valid_apps++))
                        if [[ "$VERBOSE" == "true" ]]; then
                            print_success "$app_name is valid"
                        fi
                    fi
                fi
            done
            
            print_info "Validation complete: $valid_apps/$total_apps apps are valid"
            
            if [[ $valid_apps -eq $total_apps ]]; then
                exit 0
            else
                exit 1
            fi
        fi
    fi
    
    check_dependencies
    init_directories
    
    # Initialize port tracker with existing ports from destination repositories
    # This ensures we don't reassign ports that are already in use
    init_port_tracker
    
    # Initialize Portainer master template if converting to Portainer
    local has_portainer=false
    for platform in "${PLATFORMS[@]}"; do
        if [[ "$platform" == "portainer" ]]; then
            has_portainer=true
            init_portainer_master_template
            break
        fi
    done
    
    if [[ -n "$SINGLE_APP" ]]; then
        print_info "Converting single app: $SINGLE_APP"
        convert_app "$SINGLE_APP"
    else
        print_info "Converting all apps..."
        local app_count=0
        local success_count=0
        
        for app_dir in "$APPS_DIR"/*; do
            if [[ -d "$app_dir" && "$(basename "$app_dir")" != "__tests__" ]]; then
                app_name=$(basename "$app_dir")
                ((app_count++)) || true
                
                if convert_app "$app_name"; then
                    ((success_count++)) || true
                fi
            fi
        done
        
        print_success "Conversion complete: $success_count/$app_count apps converted"
    fi
    
    # Finalize Portainer master template if we were converting to Portainer
    if [[ "$has_portainer" == "true" ]]; then
        finalize_portainer_master_template
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi