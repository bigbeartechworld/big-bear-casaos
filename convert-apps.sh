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
                            local safe_prefix=$(echo "$app_prefix" | sed 's|-|_|g')
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
    
    # 3. Add tipi_main_network to all services
    local services
    services=$(yq eval '.services | keys | .[]' "$runtipi_compose" 2>/dev/null)
    
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
    
    # Extract services and convert to Runtipi JSON format
    local compose_file="$app_dir/docker-compose.yml"
    local services_json="[]"
    
    # Get main service name
    local main_service
    main_service=$(yq eval '.x-casaos.main // (keys | .[0])' "$compose_file" 2>/dev/null || echo "app")
    
    # Extract service information and convert to dynamic compose
    local main_service_data
    main_service_data=$(yq eval '.services | to_entries | .[0]' "$compose_file")
    
    cat > "$output_dir/docker-compose.json" << EOF
{
  "services": [
    {
      "name": "$(echo "$main_service_data" | yq eval '.key' -)",
      "image": "$(echo "$main_service_data" | yq eval '.value.image' -)",
      "internalPort": $(echo "$main_service_data" | yq eval '.value.ports[0]' - | cut -d':' -f2),
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
    
    cat > "$output_dir/config.json" << EOF
{
  "name": "$METADATA_TITLE",
  "available": true,
  "port": ${METADATA_PORT_MAP:-8080},
  "exposable": true,
  "dynamic_config": true,
  "id": "$METADATA_ID",
  "description": "$METADATA_DESCRIPTION",
  "tipi_version": 1,
  "version": "$METADATA_VERSION",
  "categories": $categories_json,
  "short_desc": "$METADATA_TAGLINE",
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
    
    # Create metadata directory
    mkdir -p "$output_dir/metadata"
    echo "$METADATA_DESCRIPTION" > "$output_dir/metadata/description.md"
    
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

# Convert to Cosmos format (cosmos-compose with routes)
convert_to_cosmos() {
    local app_name="$1"
    local app_dir="$2"
    local output_dir="$OUTPUT_DIR/cosmos/$app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Cosmos format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for route configuration
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose and add Cosmos-specific routes section
    # Enable volume declarations for Cosmos with app-specific prefix
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/cosmos-compose.yml" "./data" "true" "$app_name"
    
    # Add routes section for reverse proxy
    if [[ -n "$METADATA_PORT_MAP" ]]; then
        cat >> "$output_dir/cosmos-compose.yml" << EOF

# Cosmos-specific routes for reverse proxy
routes:
  - name: ${app_name}
    description: ${METADATA_TITLE}
    useHost: true
    target: http://localhost:${METADATA_PORT_MAP}
    mode: SERVAPP
    Timeout: 14400000
    ThrottlePerMinute: 0
    BlockCommonBots: false
    BlockAPIAbuse: false
EOF
    fi
    
    # Create cosmos app metadata file
    cat > "$output_dir/servapp.json" << EOF
{
  "name": "$METADATA_TITLE",
  "description": "$METADATA_DESCRIPTION",
  "author": "$METADATA_DEVELOPER",
  "icon": "$METADATA_ICON",
  "category": "$METADATA_CATEGORY",
  "port": $METADATA_PORT_MAP,
  "compose_file": "cosmos-compose.yml"
}
EOF
    
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
    local umbrel_app_name="big-bear-umbrel-$app_name"
    local output_dir="$OUTPUT_DIR/umbrel/$umbrel_app_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would convert $app_name to Umbrel format"
        return
    fi
    
    mkdir -p "$output_dir"
    
    # Extract metadata for Umbrel format
    eval "$(extract_metadata "$app_dir" "$app_name")"
    
    # Clean compose file for Umbrel
    clean_compose "$app_dir/docker-compose.yml" "$output_dir/docker-compose.yml" "\${APP_DATA_DIR}"
    
    # Get main service name from docker-compose.yml
    local main_service
    main_service=$(yq eval '.services | keys | .[0]' "$app_dir/docker-compose.yml" 2>/dev/null || echo "app")
    
    # Extract first port from docker-compose.yml
    local port
    port=$(yq eval '.services[].ports[0]' "$app_dir/docker-compose.yml" 2>/dev/null | cut -d':' -f1 | head -1 || echo "$METADATA_PORT_MAP")
    
    # If port is empty, use METADATA_PORT_MAP
    if [[ -z "$port" || "$port" == "null" ]]; then
        port="$METADATA_PORT_MAP"
    fi
    
    # Extract dependencies (if any)
    local dependencies
    dependencies=$(yq eval -o=json '.x-casaos.dependencies // []' "$app_dir/docker-compose.yml" 2>/dev/null || echo "[]")
    
    # Convert dependencies to YAML list format
    local deps_yaml=""
    if [[ "$dependencies" != "[]" ]]; then
        deps_yaml=$(echo "$dependencies" | jq -r '.[] | "  - " + .')
    fi
    
    # Create umbrel-app.yml manifest
    cat > "$output_dir/umbrel-app.yml" << EOF
manifestVersion: 1
id: $umbrel_app_name
category: $METADATA_CATEGORY
name: $METADATA_TITLE
version: "$METADATA_VERSION"
tagline: $METADATA_TAGLINE
description: >-
  $METADATA_DESCRIPTION
releaseNotes: >-
  This version includes various improvements and bug fixes.
developer: $METADATA_DEVELOPER
website: $(yq eval '.x-casaos.project_url // ""' "$app_dir/docker-compose.yml" 2>/dev/null || echo "")
dependencies:$(if [[ -n "$deps_yaml" ]]; then echo "
$deps_yaml"; else echo " []"; fi)
repo: https://github.com/bigbeartechworld/big-bear-casaos
support: https://github.com/bigbeartechworld/big-bear-casaos/issues
port: $port
gallery:
  - 1.jpg
  - 2.jpg
  - 3.jpg
path: ""
defaultUsername: ""
defaultPassword: ""
submitter: BigBearTechWorld
submission: https://github.com/bigbeartechworld/big-bear-casaos
EOF
    
    # Update docker-compose.yml to use Umbrel-compatible naming
    # Replace service names to match Umbrel naming convention: app-id_service-name_1
    local temp_compose="${output_dir}/docker-compose.tmp.yml"
    local final_compose="${output_dir}/docker-compose.yml"
    
    # Read the cleaned compose file and update app_proxy APP_HOST and APP_PORT if it exists
    if yq eval '.services.app_proxy' "$final_compose" > /dev/null 2>&1; then
        yq eval ".services.app_proxy.environment.APP_HOST = \"${umbrel_app_name}_${main_service}_1\" | .services.app_proxy.environment.APP_PORT = \"$port\"" "$final_compose" > "$temp_compose"
        mv "$temp_compose" "$final_compose"
    fi
    
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