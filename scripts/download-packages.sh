#!/bin/bash

# Simple package download script for GitHub Actions
# Usage: ./download-packages.sh <environment>

set -euo pipefail

ENV=${1:-development}

# Read package versions and images from versions.yml
HUB_IMAGE=$(yq eval ".$ENV.hub.image" versions.yml)
HUB_VERSION=$(yq eval ".$ENV.hub.version" versions.yml)
LAMBDA_IMAGE=$(yq eval ".$ENV.drivetrain.lambda.image" versions.yml)
LAMBDA_VERSION=$(yq eval ".$ENV.drivetrain.lambda.version" versions.yml)
LAYER_IMAGE=$(yq eval ".$ENV.drivetrain.tippecanoe_layer.image" versions.yml)
LAYER_VERSION=$(yq eval ".$ENV.drivetrain.tippecanoe_layer.version" versions.yml)

echo "Downloading packages for $ENV environment:"
echo "- Hub: ${HUB_IMAGE}:${HUB_VERSION}"
echo "- Lambda: ${LAMBDA_IMAGE}:${LAMBDA_VERSION}"
echo "- Layer: ${LAYER_IMAGE}:${LAYER_VERSION}"

# Create artifacts directory
rm -rf artifacts
mkdir -p artifacts/{hub,lambda,layer}

# Download and extract hub package
docker pull ${HUB_IMAGE}:${HUB_VERSION}
CONTAINER_ID=$(docker create ${HUB_IMAGE}:${HUB_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/static-site" artifacts/hub/ || docker cp "$CONTAINER_ID:/" artifacts/hub/static-site
docker rm "$CONTAINER_ID"

# Download and extract lambda package
docker pull ${LAMBDA_IMAGE}:${LAMBDA_VERSION}
CONTAINER_ID=$(docker create ${LAMBDA_IMAGE}:${LAMBDA_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/lambda-package.zip" artifacts/lambda/
docker rm "$CONTAINER_ID"

# Download and extract layer package
docker pull ${LAYER_IMAGE}:${LAYER_VERSION}
CONTAINER_ID=$(docker create ${LAYER_IMAGE}:${LAYER_VERSION} /bin/true)
docker cp "$CONTAINER_ID:/layer-package.zip" artifacts/layer/
docker rm "$CONTAINER_ID"

echo "Package download completed!"
