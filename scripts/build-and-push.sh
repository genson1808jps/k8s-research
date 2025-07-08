#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="k8s-demo-app"
IMAGE_TAG=${1:-"v1.0.0"}
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${BLUE}🏗️  Building Docker image: ${FULL_IMAGE_NAME}${NC}"

# Change to app directory
cd "$(dirname "$0")/../app"

# Build Docker image
docker build -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker image built successfully: ${FULL_IMAGE_NAME}${NC}"
else
    echo -e "${RED}❌ Failed to build Docker image${NC}"
    exit 1
fi

# Optional: Tag as latest
docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:latest"

echo -e "${GREEN}🏷️  Tagged as: ${IMAGE_NAME}:latest${NC}"

# Show image info
echo -e "${BLUE}📊 Image information:${NC}"
docker images | grep "${IMAGE_NAME}"

echo -e "${YELLOW}💡 To push to a registry, run:${NC}"
echo -e "   docker tag ${FULL_IMAGE_NAME} <registry>/<namespace>/${FULL_IMAGE_NAME}"
echo -e "   docker push <registry>/<namespace>/${FULL_IMAGE_NAME}"

echo -e "${GREEN}✨ Build completed successfully!${NC}" 