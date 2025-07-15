#!/bin/bash

# Complete K8s Demo Deployment Script
# Deploy all features in sequence

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="k8s-demo-new"
DOCKER_IMAGE="k8s-demo-app:v1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_LOG="$SCRIPT_DIR/deploy.log"

# Print colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$DEPLOY_LOG"
}

# Wait for deployment ready
wait_for_deployment() {
    local deployment_name=$1
    print_info "Waiting for deployment $deployment_name to be ready..."
    
    if kubectl wait --for=condition=available --timeout=300s deployment/"$deployment_name" -n "$NAMESPACE" &> /dev/null; then
        print_success "Deployment $deployment_name is ready"
    else
        print_error "Deployment $deployment_name failed to become ready"
        return 1
    fi
}

# Wait for pod ready
wait_for_pod() {
    local pod_name=$1
    print_info "Waiting for pod $pod_name to be ready..."
    
    if kubectl wait --for=condition=ready --timeout=300s pod/"$pod_name" -n "$NAMESPACE" &> /dev/null; then
        print_success "Pod $pod_name is ready"
    else
        print_error "Pod $pod_name failed to become ready"
        return 1
    fi
}

# Deploy namespace and basic config
deploy_basic_config() {
    print_header "Step 1: Deploying Basic Configuration"
    
    kubectl apply -f 01-namespace.yaml
    kubectl apply -f 02-configmap.yaml
    kubectl apply -f 03-secret.yaml
    kubectl apply -f 09-resource-quota.yaml
    
    print_success "Basic configuration deployed"
    log "Basic configuration deployed"
}

# Deploy pod
deploy_pod() {
    print_header "Step 2: Deploying Basic Pod"
    
    kubectl apply -f 04-pod.yaml
    wait_for_pod "k8s-demo-pod"
    
    print_success "Pod deployed successfully"
    log "Pod deployed"
}

# Deploy services
deploy_services() {
    print_header "Step 3: Deploying Services"
    
    kubectl apply -f 05-service.yaml
    
    print_success "Services deployed successfully"
    log "Services deployed"
}

# Deploy deployment
deploy_deployment() {
    print_header "Step 4: Deploying Deployment"
    
    kubectl apply -f 06-deployment.yaml
    wait_for_deployment "k8s-demo-deployment"
    
    print_success "Deployment deployed successfully"
    log "Deployment deployed"
}

# Deploy HPA
deploy_hpa() {
    print_header "Step 5: Deploying HPA"
    
    # Check if metrics-server is available
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        print_warning "Metrics-server not found. Installing..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        print_info "Waiting for metrics-server to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
        
        print_info "Waiting for metrics to be available..."
        sleep 30
    fi
    
    kubectl apply -f 07-hpa.yaml
    
    print_success "HPA deployed successfully"
    log "HPA deployed"
}

# Deploy jobs
deploy_jobs() {
    print_header "Step 6: Deploying Jobs"
    
    if [ -f "08-jobs.yaml" ]; then
        kubectl apply -f 08-jobs.yaml
        print_success "Jobs deployed successfully"
        log "Jobs deployed"
    else
        print_warning "Jobs manifest not found, skipping..."
    fi
}

# Deploy persistent volume
deploy_persistent_volume() {
    print_header "Step 7: Deploying Persistent Volume"
    
    if [ -f "10-persistent-volume.yaml" ]; then
        kubectl apply -f 10-persistent-volume.yaml
        wait_for_deployment "k8s-demo-deployment-with-volume"
        print_success "Persistent Volume deployed successfully"
        log "Persistent Volume deployed"
    else
        print_warning "Persistent Volume manifest not found, skipping..."
    fi
}

# Show final status
show_final_status() {
    print_header "Deployment Complete - Final Status"
    
    echo -e "\n${PURPLE}📋 All Resources:${NC}"
    kubectl get all -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 ConfigMaps and Secrets:${NC}"
    kubectl get configmaps,secrets -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 HPA:${NC}"
    kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "No HPA found"
    
    echo -e "\n${PURPLE}📋 External Access:${NC}"
    NODEPORT=$(kubectl get svc k8s-demo-nodeport -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    echo "NodePort: localhost:$NODEPORT"
    echo "Test: curl http://localhost:$NODEPORT/health"
    
    echo -e "\n${PURPLE}📋 Useful Commands:${NC}"
    echo "  kubectl get all -n $NAMESPACE"
    echo "  kubectl logs -f deployment/k8s-demo-deployment -n $NAMESPACE"
    echo "  kubectl port-forward svc/k8s-demo-service 8080:80 -n $NAMESPACE"
    echo "  kubectl get hpa -n $NAMESPACE"
    echo "  kubectl delete namespace $NAMESPACE  # Cleanup"
}

# Show help
show_help() {
    echo -e "${BLUE}K8s Demo - Complete Deployment Script${NC}"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  all           Deploy all components (default)"
    echo "  basic         Deploy basic config only"
    echo "  pod           Deploy pod only"
    echo "  services      Deploy services only"
    echo "  deployment    Deploy deployment only"
    echo "  hpa           Deploy HPA only"
    echo "  jobs          Deploy jobs only"
    echo "  pv            Deploy persistent volume only"
    echo "  status        Show current status"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0            # Deploy everything"
    echo "  $0 all        # Deploy everything"
    echo "  $0 basic      # Deploy basic config only"
    echo "  $0 status     # Show current status"
    echo ""
}

# Main function
main() {
    # Initialize log file
    echo "=== K8s Deploy Script Started at $(date) ===" > "$DEPLOY_LOG"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Build Docker images first
    print_info "Building Docker images..."
    ./build-image.sh build
    
    case "${1:-all}" in
        "all")
            deploy_basic_config
            deploy_pod
            deploy_services
            deploy_deployment
            deploy_hpa
            deploy_jobs
            deploy_persistent_volume
            show_final_status
            ;;
        "basic")
            deploy_basic_config
            ;;
        "pod")
            deploy_pod
            ;;
        "services")
            deploy_services
            ;;
        "deployment")
            deploy_deployment
            ;;
        "hpa")
            deploy_hpa
            ;;
        "jobs")
            deploy_jobs
            ;;
        "pv")
            deploy_persistent_volume
            ;;
        "status")
            show_final_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    log "Script completed successfully"
    print_success "Script completed successfully!"
}

# Run main function
main "$@"