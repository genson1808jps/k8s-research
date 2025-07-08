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
MANIFEST_DIR="$(dirname "$0")/../k8s-manifests"

echo -e "${BLUE}🚀 Deploying K8s Demo Application${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"

# Deploy using all-in-one manifest
echo -e "${BLUE}📦 Deploying application...${NC}"
kubectl apply -f "${MANIFEST_DIR}/all-in-one.yaml"

# Wait for deployment to be ready
echo -e "${BLUE}⏳ Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/k8s-demo-app -n ${NAMESPACE}

# Check pod status
echo -e "${BLUE}📋 Pod status:${NC}"
kubectl get pods -n ${NAMESPACE}

# Check services
echo -e "${BLUE}🌐 Services:${NC}"
kubectl get services -n ${NAMESPACE}

# Get NodePort URL
NODE_PORT=$(kubectl get service k8s-demo-app-nodeport -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}✅ Application deployed successfully!${NC}"
echo -e "${YELLOW}🌐 Access the application:${NC}"

if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    MINIKUBE_IP=$(minikube ip)
    echo -e "   NodePort: http://${MINIKUBE_IP}:${NODE_PORT}"
elif command -v docker &> /dev/null && docker info &> /dev/null && [[ $(docker info --format '{{.ServerVersion}}' 2>/dev/null) ]]; then
    echo -e "   NodePort: http://localhost:${NODE_PORT}"
else
    echo -e "   NodePort: http://<node-ip>:${NODE_PORT}"
fi

echo -e "   Port-forward: kubectl port-forward service/k8s-demo-app-service 8080:80 -n ${NAMESPACE}"

echo -e "${BLUE}🔍 Useful commands:${NC}"
echo -e "   View logs: kubectl logs -f deployment/k8s-demo-app -n ${NAMESPACE}"
echo -e "   Get pods: kubectl get pods -n ${NAMESPACE}"
echo -e "   Describe deployment: kubectl describe deployment k8s-demo-app -n ${NAMESPACE}" 