#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="k8s-demo"
IMAGE_NAME="k8s-demo-app"

echo -e "${BLUE}🧹 Cleaning up K8s Demo Resources${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Delete namespace (this will delete all resources in the namespace)
echo -e "${YELLOW}🗑️  Deleting namespace: ${NAMESPACE}${NC}"
kubectl delete namespace ${NAMESPACE} --ignore-not-found=true

# Wait for namespace deletion
echo -e "${BLUE}⏳ Waiting for namespace to be deleted...${NC}"
kubectl wait --for=delete namespace/${NAMESPACE} --timeout=60s 2>/dev/null || true

# Optional: Remove Docker images
echo -e "${YELLOW}🐳 Docker images for ${IMAGE_NAME}:${NC}"
docker images | grep ${IMAGE_NAME} || echo "No images found"

read -p "Do you want to remove Docker images? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🗑️  Removing Docker images...${NC}"
    docker rmi -f $(docker images ${IMAGE_NAME} -q) 2>/dev/null || echo "No images to remove"
fi

echo -e "${GREEN}✅ Cleanup completed!${NC}"
echo -e "${BLUE}📋 Verification:${NC}"
echo -e "   Namespace: $(kubectl get namespace ${NAMESPACE} 2>/dev/null && echo 'Still exists' || echo 'Deleted')"
echo -e "   Docker images: $(docker images | grep ${IMAGE_NAME} | wc -l) remaining" 