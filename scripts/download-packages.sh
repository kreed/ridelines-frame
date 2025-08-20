#!/bin/bash

# Simple package download script for GitHub Actions
# Usage: ./download-packages.sh <environment>

set -euo pipefail

ENV=${1:-dev}

# Read package versions from versions.yml
if [[ "$ENV" == "dev" ]]; then
    HUB_VERSION=$(yq eval '.development.hub.version' versions.yml)
    LAMBDA_VERSION=$(yq eval '.development.drivetrain.lambda.version' versions.yml)
    LAYER_VERSION=$(yq eval '.development.drivetrain.tippecanoe_layer.version' versions.yml)
else
    HUB_VERSION=$(yq eval '.production.hub.version' versions.yml)
    LAMBDA_VERSION=$(yq eval '.production.drivetrain.lambda.version' versions.yml)
    LAYER_VERSION=$(yq eval '.production.drivetrain.tippecanoe_layer.version' versions.yml)
fi

echo "Downloading packages for $ENV environment:"
echo "- Hub: $HUB_VERSION"
echo "- Lambda: $LAMBDA_VERSION"
echo "- Layer: $LAYER_VERSION"

# Create artifacts directory
rm -rf artifacts
mkdir -p artifacts/{hub,lambda,layer}

# Download and extract hub package
docker pull ghcr.io/kreed/ridelines-hub:${HUB_VERSION}
CONTAINER_ID=$(docker create ghcr.io/kreed/ridelines-hub:${HUB_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/static-site" artifacts/hub/ || docker cp "$CONTAINER_ID:/" artifacts/hub/static-site
docker rm "$CONTAINER_ID"

# Download and extract lambda package
docker pull ghcr.io/kreed/ridelines-drivetrain:${LAMBDA_VERSION}
CONTAINER_ID=$(docker create ghcr.io/kreed/ridelines-drivetrain:${LAMBDA_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/lambda-package.zip" artifacts/lambda/
docker rm "$CONTAINER_ID"

# Download and extract layer package
docker pull ghcr.io/kreed/ridelines-tippecanoe-layer:${LAYER_VERSION}
CONTAINER_ID=$(docker create ghcr.io/kreed/ridelines-tippecanoe-layer:${LAYER_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/layer-package.zip" artifacts/layer/
docker rm "$CONTAINER_ID"

echo "Package download completed!"
