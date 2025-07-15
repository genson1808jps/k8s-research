#!/bin/bash

# Docker Image Build Script for K8s Demo
# Build multiple versions of the demo application

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
APP_NAME="k8s-demo-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
BUILD_LOG="$SCRIPT_DIR/build.log"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$BUILD_LOG"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
}

# Check if running on k3s
check_k3s() {
    if command -v k3s &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Import Docker image to k3s
import_to_k3s() {
    local image=$1
    print_info "Importing $image to k3s containerd..."
    log "Importing $image to k3s containerd"
    
    if docker save "$image" | k3s ctr images import -; then
        print_success "Image $image imported to k3s successfully"
        log "Image $image imported to k3s successfully"
    else
        print_error "Failed to import $image to k3s"
        log "Failed to import $image to k3s"
        return 1
    fi
}

# Build Docker image
build_image() {
    local version=$1
    local tag="${APP_NAME}:${version}"
    
    print_info "Building Docker image: $tag"
    log "Building Docker image: $tag"
    
    cd "$APP_DIR"
    
    if docker build -t "$tag" . >> "$BUILD_LOG" 2>&1; then
        print_success "Successfully built: $tag"
        log "Successfully built: $tag"
        
        # Import to k3s if detected
        if check_k3s; then
            import_to_k3s "$tag"
        fi
    else
        print_error "Failed to build: $tag"
        log "Failed to build: $tag"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Build all versions
build_all() {
    print_header "Building All Docker Images"
    
    # Build different versions
    build_image "latest"
    build_image "v1.0.0"
    build_image "v2.0.0"
    
    # Tag additional versions for demo
    print_info "Creating additional tags..."
    docker tag "${APP_NAME}:latest" "${APP_NAME}:stable"
    docker tag "${APP_NAME}:v1.0.0" "${APP_NAME}:production"
    docker tag "${APP_NAME}:v2.0.0" "${APP_NAME}:development"
    
    # Import additional tags to k3s if detected
    if check_k3s; then
        print_info "Importing additional tags to k3s..."
        import_to_k3s "${APP_NAME}:stable"
        import_to_k3s "${APP_NAME}:production"
        import_to_k3s "${APP_NAME}:development"
    fi
    
    print_success "All images built successfully!"
}

# List built images
list_images() {
    print_header "Available Docker Images"
    docker images "$APP_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
}

# Clean up images
cleanup_images() {
    print_header "Cleaning Up Docker Images"
    
    print_warning "This will remove all k8s-demo-app images!"
    echo -e "${YELLOW}Are you sure? (y/N)${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Removing all k8s-demo-app images..."
        docker rmi $(docker images "$APP_NAME" -q) 2>/dev/null || true
        print_success "Images cleaned up!"
        log "Images cleaned up"
    else
        print_info "Cleanup cancelled."
    fi
}

# Push images to registry (optional)
push_images() {
    local registry=$1
    
    if [ -z "$registry" ]; then
        print_error "Registry URL required for push"
        return 1
    fi
    
    print_header "Pushing Images to Registry: $registry"
    
    # Tag and push each version
    for tag in "latest" "v1.0.0" "v2.0.0"; do
        local local_image="${APP_NAME}:${tag}"
        local remote_image="${registry}/${APP_NAME}:${tag}"
        
        print_info "Tagging: $local_image -> $remote_image"
        docker tag "$local_image" "$remote_image"
        
        print_info "Pushing: $remote_image"
        if docker push "$remote_image" >> "$BUILD_LOG" 2>&1; then
            print_success "Pushed: $remote_image"
        else
            print_error "Failed to push: $remote_image"
        fi
    done
}

# Show help
show_help() {
    echo -e "${BLUE}K8s Demo - Docker Image Build Script${NC}"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  build         Build all Docker images (latest, v1.0.0, v2.0.0)"
    echo "  build <tag>   Build specific version"
    echo "  list          List all built images"
    echo "  clean         Clean up all images"
    echo "  push <registry>  Push images to registry"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build              # Build all versions"
    echo "  $0 build v1.0.0       # Build specific version"
    echo "  $0 list               # List images"
    echo "  $0 clean              # Clean up images"
    echo "  $0 push localhost:5000 # Push to local registry"
    echo ""
}

# Main function
main() {
    # Initialize log file
    echo "=== Docker Build Script Started at $(date) ===" > "$BUILD_LOG"
    
    # Check prerequisites
    check_docker
    
    case "${1:-build}" in
        "build")
            if [ -n "$2" ]; then
                build_image "$2"
            else
                build_all
            fi
            list_images
            ;;
        "list")
            list_images
            ;;
        "clean")
            cleanup_images
            ;;
        "push")
            if [ -n "$2" ]; then
                push_images "$2"
            else
                print_error "Registry URL required for push"
                show_help
                exit 1
            fi
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
}

# Run main function
main "$@"