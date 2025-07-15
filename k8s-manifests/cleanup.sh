#!/bin/bash

# K8s Demo Cleanup Script
# Remove all demo resources

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_LOG="$SCRIPT_DIR/cleanup.log"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$CLEANUP_LOG"
}

# Cleanup K8s resources
cleanup_k8s() {
    print_header "Cleaning up Kubernetes Resources"
    
    # Delete namespace (this will delete all resources in it)
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Deleting namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        print_success "Namespace deleted"
        log "Namespace $NAMESPACE deleted"
    else
        print_info "Namespace $NAMESPACE not found"
        log "Namespace $NAMESPACE not found"
    fi
    
    # Delete PersistentVolume (not namespaced)
    if kubectl get pv k8s-demo-pv &> /dev/null; then
        print_info "Deleting PersistentVolume: k8s-demo-pv"
        kubectl delete pv k8s-demo-pv --ignore-not-found=true
        print_success "PersistentVolume deleted"
        log "PersistentVolume k8s-demo-pv deleted"
    else
        print_info "PersistentVolume k8s-demo-pv not found"
        log "PersistentVolume k8s-demo-pv not found"
    fi
}

# Cleanup local data
cleanup_local_data() {
    print_header "Cleaning up Local Data"
    
    # Remove local data directory
    if [ -d "/tmp/k8s-demo-data" ]; then
        print_info "Removing local data directory: /tmp/k8s-demo-data"
        sudo rm -rf /tmp/k8s-demo-data 2>/dev/null || true
        print_success "Local data directory removed"
        log "Local data directory removed"
    else
        print_info "Local data directory not found"
        log "Local data directory not found"
    fi
    
    # Clean up log files
    if [ -f "$SCRIPT_DIR/demo.log" ]; then
        print_info "Removing demo logs"
        rm -f "$SCRIPT_DIR/demo.log"
        print_success "Demo logs removed"
        log "Demo logs removed"
    fi
    
    if [ -f "$SCRIPT_DIR/deploy.log" ]; then
        print_info "Removing deploy logs"
        rm -f "$SCRIPT_DIR/deploy.log"
        print_success "Deploy logs removed"
        log "Deploy logs removed"
    fi
    
    if [ -f "$SCRIPT_DIR/build.log" ]; then
        print_info "Removing build logs"
        rm -f "$SCRIPT_DIR/build.log"
        print_success "Build logs removed"
        log "Build logs removed"
    fi
}

# Cleanup Docker images
cleanup_docker() {
    print_header "Cleaning up Docker Images"
    
    print_warning "This will remove all k8s-demo-app Docker images!"
    echo -e "${YELLOW}Are you sure? (y/N)${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Removing all k8s-demo-app images..."
        
        # Remove all k8s-demo-app images
        if docker images k8s-demo-app -q | grep -q .; then
            docker rmi $(docker images k8s-demo-app -q) 2>/dev/null || true
            print_success "Docker images removed"
            log "Docker images removed"
        else
            print_info "No k8s-demo-app images found"
            log "No k8s-demo-app images found"
        fi
        
        # Clean up dangling images
        if docker images -f "dangling=true" -q | grep -q .; then
            print_info "Removing dangling images..."
            docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
            print_success "Dangling images removed"
            log "Dangling images removed"
        fi
    else
        print_info "Docker cleanup cancelled"
        log "Docker cleanup cancelled"
    fi
}

# Verify cleanup
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    # Check namespace
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace $NAMESPACE still exists"
    else
        print_success "Namespace $NAMESPACE removed"
    fi
    
    # Check PersistentVolume
    if kubectl get pv k8s-demo-pv &> /dev/null; then
        print_warning "PersistentVolume k8s-demo-pv still exists"
    else
        print_success "PersistentVolume k8s-demo-pv removed"
    fi
    
    # Check local data
    if [ -d "/tmp/k8s-demo-data" ]; then
        print_warning "Local data directory still exists"
    else
        print_success "Local data directory removed"
    fi
    
    # Check Docker images
    if docker images k8s-demo-app -q | grep -q .; then
        print_info "Docker images still exist:"
        docker images k8s-demo-app --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    else
        print_success "All Docker images removed"
    fi
    
    # Check service accessibility
    if curl -s http://localhost:30080/health &> /dev/null; then
        print_warning "Service still accessible at localhost:30080"
    else
        print_success "Service no longer accessible"
    fi
}

# Show help
show_help() {
    echo -e "${BLUE}K8s Demo - Cleanup Script${NC}"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  all           Complete cleanup (default)"
    echo "  k8s           Cleanup K8s resources only"
    echo "  local         Cleanup local data only"
    echo "  docker        Cleanup Docker images only"
    echo "  verify        Verify cleanup status"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0            # Complete cleanup"
    echo "  $0 all        # Complete cleanup"
    echo "  $0 k8s        # K8s resources only"
    echo "  $0 docker     # Docker images only"
    echo "  $0 verify     # Verify cleanup"
    echo ""
}

# Main function
main() {
    # Initialize log file
    echo "=== K8s Cleanup Script Started at $(date) ===" > "$CLEANUP_LOG"
    
    case "${1:-all}" in
        "all")
            cleanup_k8s
            cleanup_local_data
            cleanup_docker
            verify_cleanup
            ;;
        "k8s")
            cleanup_k8s
            ;;
        "local")
            cleanup_local_data
            ;;
        "docker")
            cleanup_docker
            ;;
        "verify")
            verify_cleanup
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
    
    log "Cleanup script completed"
    print_success "Cleanup script completed!"
}

# Run main function
main "$@"