#!/bin/bash

# Package fetch script for Ridelines Frame
# Downloads and extracts GitHub packages for deployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
VERSIONS_FILE="$PROJECT_ROOT/versions.yml"

# Default environment
ENV=${1:-dev}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Validate environment
validate_environment() {
    if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
        error "Invalid environment: $ENV. Must be 'dev' or 'prod'."
        exit 1
    fi
    
    if [[ ! -f "$VERSIONS_FILE" ]]; then
        error "Versions file not found: $VERSIONS_FILE"
        exit 1
    fi
}

# Extract package versions from versions.yml
get_package_versions() {
    log "Reading package versions for environment: $ENV"
    
    HUB_VERSION=$(yq eval ".${ENV}.hub.version" "$VERSIONS_FILE")
    LAMBDA_VERSION=$(yq eval ".${ENV}.drivetrain.lambda.version" "$VERSIONS_FILE")
    LAYER_VERSION=$(yq eval ".${ENV}.drivetrain.tippecanoe_layer.version" "$VERSIONS_FILE")
    
    log "Package versions:"
    log "  Hub: $HUB_VERSION"
    log "  Lambda: $LAMBDA_VERSION"
    log "  Layer: $LAYER_VERSION"
    
    # Validate versions
    if [[ "$HUB_VERSION" == "null" || "$LAMBDA_VERSION" == "null" || "$LAYER_VERSION" == "null" ]]; then
        error "One or more package versions are null. Check versions.yml file."
        exit 1
    fi
}

# Create clean artifacts directory
prepare_artifacts_dir() {
    log "Preparing artifacts directory: $ARTIFACTS_DIR"
    
    if [[ -d "$ARTIFACTS_DIR" ]]; then
        rm -rf "$ARTIFACTS_DIR"
    fi
    
    mkdir -p "$ARTIFACTS_DIR"/{hub,lambda,layer}
}

# Pull and extract package artifacts
extract_packages() {
    log "Pulling and extracting package artifacts..."
    
    # Hub package (static site)
    log "Extracting hub package..."
    if docker pull "ghcr.io/ridelines/hub:${HUB_VERSION}" 2>/dev/null; then
        # Create temporary container and copy files
        CONTAINER_ID=$(docker create "ghcr.io/ridelines/hub:${HUB_VERSION}")
        docker cp "$CONTAINER_ID:/static-site" "$ARTIFACTS_DIR/hub/" || {
            # Fallback if path is different
            warn "Failed to copy from /static-site, trying alternative paths..."
            docker cp "$CONTAINER_ID:/" "$ARTIFACTS_DIR/hub/static-site" 2>/dev/null || {
                error "Failed to extract hub package"
                docker rm "$CONTAINER_ID"
                exit 1
            }
        }
        docker rm "$CONTAINER_ID"
        success "Hub package extracted"
    else
        error "Failed to pull hub package: ghcr.io/ridelines/hub:${HUB_VERSION}"
        exit 1
    fi
    
    # Lambda package
    log "Extracting lambda package..."
    if docker pull "ghcr.io/ridelines/drivetrain-lambda:${LAMBDA_VERSION}" 2>/dev/null; then
        CONTAINER_ID=$(docker create "ghcr.io/ridelines/drivetrain-lambda:${LAMBDA_VERSION}")
        docker cp "$CONTAINER_ID:/lambda-package.zip" "$ARTIFACTS_DIR/lambda/" || {
            error "Failed to extract lambda package"
            docker rm "$CONTAINER_ID"
            exit 1
        }
        docker rm "$CONTAINER_ID"
        success "Lambda package extracted"
    else
        error "Failed to pull lambda package: ghcr.io/ridelines/drivetrain-lambda:${LAMBDA_VERSION}"
        exit 1
    fi
    
    # Layer package
    log "Extracting layer package..."
    if docker pull "ghcr.io/ridelines/drivetrain-tippecanoe-layer:${LAYER_VERSION}" 2>/dev/null; then
        CONTAINER_ID=$(docker create "ghcr.io/ridelines/drivetrain-tippecanoe-layer:${LAYER_VERSION}")
        docker cp "$CONTAINER_ID:/layer-package.zip" "$ARTIFACTS_DIR/layer/" || {
            error "Failed to extract layer package"
            docker rm "$CONTAINER_ID"
            exit 1
        }
        docker rm "$CONTAINER_ID"
        success "Layer package extracted"
    else
        error "Failed to pull layer package: ghcr.io/ridelines/drivetrain-tippecanoe-layer:${LAYER_VERSION}"
        exit 1
    fi
}

# Verify extracted artifacts
verify_artifacts() {
    log "Verifying extracted artifacts..."
    
    local errors=0
    
    # Check hub artifacts
    if [[ ! -d "$ARTIFACTS_DIR/hub/static-site" ]]; then
        error "Hub static site directory not found"
        ((errors++))
    fi
    
    # Check lambda artifacts
    if [[ ! -f "$ARTIFACTS_DIR/lambda/lambda-package.zip" ]]; then
        error "Lambda package not found"
        ((errors++))
    fi
    
    # Check layer artifacts
    if [[ ! -f "$ARTIFACTS_DIR/layer/layer-package.zip" ]]; then
        error "Layer package not found"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        error "Artifact verification failed with $errors errors"
        exit 1
    fi
    
    success "All artifacts verified successfully"
}

# Show summary
show_summary() {
    log "Package extraction summary:"
    log "  Environment: $ENV"
    log "  Artifacts directory: $ARTIFACTS_DIR"
    log "  Hub files: $(find "$ARTIFACTS_DIR/hub" -type f | wc -l) files"
    log "  Lambda package: $(du -h "$ARTIFACTS_DIR/lambda/lambda-package.zip" | cut -f1)"
    log "  Layer package: $(du -h "$ARTIFACTS_DIR/layer/layer-package.zip" | cut -f1)"
    success "Package extraction completed successfully!"
}

# Main execution
main() {
    log "Starting package extraction for environment: $ENV"
    
    check_dependencies
    validate_environment
    get_package_versions
    prepare_artifacts_dir
    extract_packages
    verify_artifacts
    show_summary
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << EOF
Usage: $0 [ENVIRONMENT]

Extract GitHub packages for deployment to the specified environment.

Arguments:
  ENVIRONMENT    Target environment (dev|prod). Default: dev

Examples:
  $0 dev         Extract packages for development environment
  $0 prod        Extract packages for production environment

Dependencies:
  - yq           YAML processor
  - docker       Container runtime
  - versions.yml Package version configuration file

EOF
    exit 0
fi

# Execute main function
main "$@"