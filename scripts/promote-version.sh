#!/bin/bash

# Manual promotion script for Ridelines Frame
# Helps promote development versions to production

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$PROJECT_ROOT/versions.yml"

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
    if ! command -v yq &> /dev/null; then
        error "yq is required but not installed. Please install yq."
        exit 1
    fi
}

# Show current versions
show_current_versions() {
    log "Current package versions:"
    log ""
    log "Development:"
    log "  Hub: $(yq eval '.development.hub.version' "$VERSIONS_FILE")"
    log "  Lambda: $(yq eval '.development.drivetrain.lambda.version' "$VERSIONS_FILE")"
    log "  Layer: $(yq eval '.development.drivetrain.tippecanoe_layer.version' "$VERSIONS_FILE")"
    log ""
    log "Production:"
    log "  Hub: $(yq eval '.production.hub.version' "$VERSIONS_FILE")"
    log "  Lambda: $(yq eval '.production.drivetrain.lambda.version' "$VERSIONS_FILE")"
    log "  Layer: $(yq eval '.production.drivetrain.tippecanoe_layer.version' "$VERSIONS_FILE")"
    log ""
}

# Promote development versions to production
promote_to_production() {
    log "Promoting development versions to production..."
    
    # Get current development versions
    DEV_HUB=$(yq eval '.development.hub.version' "$VERSIONS_FILE")
    DEV_LAMBDA=$(yq eval '.development.drivetrain.lambda.version' "$VERSIONS_FILE")
    DEV_LAYER=$(yq eval '.development.drivetrain.tippecanoe_layer.version' "$VERSIONS_FILE")
    
    # Update production versions
    yq eval ".production.hub.version = \"$DEV_HUB\"" -i "$VERSIONS_FILE"
    yq eval ".production.drivetrain.lambda.version = \"$DEV_LAMBDA\"" -i "$VERSIONS_FILE"
    yq eval ".production.drivetrain.tippecanoe_layer.version = \"$DEV_LAYER\"" -i "$VERSIONS_FILE"
    
    success "Production versions updated!"
    log ""
    log "New production versions:"
    log "  Hub: $DEV_HUB"
    log "  Lambda: $DEV_LAMBDA"
    log "  Layer: $DEV_LAYER"
    log ""
    warn "Remember to commit and push these changes to trigger production deployment."
}

# Main function
main() {
    case "${1:-}" in
        "show"|"status")
            show_current_versions
            ;;
        "promote")
            show_current_versions
            echo ""
            read -p "Do you want to promote development versions to production? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                promote_to_production
            else
                log "Promotion cancelled."
            fi
            ;;
        "help"|"--help"|"-h"|"")
            cat << EOF
Usage: $0 [COMMAND]

Commands:
  show       Show current package versions for both environments
  promote    Promote development versions to production (interactive)
  help       Show this help message

Examples:
  $0 show                    # Show current versions
  $0 promote                 # Promote dev to prod (with confirmation)

After promotion, remember to:
1. Review the changes in versions.yml
2. Commit and push the changes
3. The production deployment will require manual approval

EOF
            ;;
        *)
            error "Unknown command: $1"
            error "Run '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run the script
check_dependencies
main "$@"