#!/bin/bash

# Interactive K8s Demo Script
# Chọn demo từng phần Kubernetes features

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
LOG_FILE="$SCRIPT_DIR/demo.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

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

# Wait for user input
wait_for_user() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
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
    
    if docker save "$image" | k3s ctr images import -; then
        print_success "Image $image imported to k3s successfully"
        log "Image $image imported to k3s"
    else
        print_error "Failed to import $image to k3s"
        return 1
    fi
}

# Build Docker image
build_image() {
    print_header "Building Docker Image"
    log "Building Docker image: $DOCKER_IMAGE"
    
    cd "$SCRIPT_DIR/../app"
    
    # Build the image
    if docker build -t "$DOCKER_IMAGE" .; then
        print_success "Docker image built successfully: $DOCKER_IMAGE"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
    
    # Also build v2.0.0 for rolling update demo
    print_info "Building v2.0.0 image for rolling update demo..."
    if docker build -t "k8s-demo-app:v2.0.0" .; then
        print_success "Docker image v2.0.0 built successfully"
    else
        print_warning "Failed to build v2.0.0 image"
    fi
    
    # Import to k3s if detected
    if check_k3s; then
        print_info "k3s detected, importing images to containerd..."
        import_to_k3s "$DOCKER_IMAGE"
        import_to_k3s "k8s-demo-app:v2.0.0"
        import_to_k3s "k8s-demo-app:latest"
    fi
    
    cd "$SCRIPT_DIR"
}

# Import images to k3s
import_to_k3s() {
    print_header "Import Images to k3s"
    
    # Check if k3s is available
    if ! command -v k3s &> /dev/null; then
        print_error "k3s not found. This function is only for k3s environments."
        return 1
    fi
    
    # Check if Docker images exist
    if ! docker images k8s-demo-app --format "{{.Repository}}:{{.Tag}}" | grep -q "k8s-demo-app"; then
        print_error "No k8s-demo-app images found. Please build them first (option 0)."
        return 1
    fi
    
    print_info "Importing k8s-demo-app images to k3s containerd..."
    
    # Import all versions
    for tag in "latest" "v1.0.0" "v2.0.0"; do
        if docker images k8s-demo-app:$tag --format "{{.Repository}}:{{.Tag}}" | grep -q "k8s-demo-app:$tag"; then
            print_info "Importing k8s-demo-app:$tag..."
            if docker save k8s-demo-app:$tag | k3s ctr images import -; then
                print_success "Imported k8s-demo-app:$tag"
            else
                print_error "Failed to import k8s-demo-app:$tag"
            fi
        fi
    done
    
    print_success "Image import completed!"
    log "Images imported to k3s"
}

# Wait for deployment to be ready
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

# Wait for pod to be ready
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

# Demo 1: Namespace and Basic Configuration
demo_namespace() {
    print_header "Demo 1: Namespace và Basic Configuration"
    
    print_info "Creating namespace '$NAMESPACE'..."
    kubectl apply -f 01-namespace.yaml
    
    print_info "Creating ConfigMap with application configuration..."
    kubectl apply -f 02-configmap.yaml
    
    print_info "Creating Secret with sensitive data..."
    kubectl apply -f 03-secret.yaml
    
    print_info "Applying resource quotas and limits..."
    kubectl apply -f 09-resource-quota.yaml
    
    echo -e "\n${PURPLE}📋 Let's examine what we created:${NC}"
    echo "Namespace:"
    kubectl get namespace "$NAMESPACE" -o wide
    
    echo -e "\nConfigMap:"
    kubectl get configmap -n "$NAMESPACE" -o wide
    
    echo -e "\nSecret:"
    kubectl get secret -n "$NAMESPACE" -o wide
    
    echo -e "\nResource Quota:"
    kubectl get resourcequota -n "$NAMESPACE" -o wide
    
    echo -e "\nLimitRange:"
    kubectl get limitrange -n "$NAMESPACE" -o wide
    
    print_success "Demo 1 completed - Basic configuration is ready!"
    log "Demo 1 completed: Namespace and basic configuration"
}

# Demo 2: Basic Pod Deployment
demo_pod() {
    print_header "Demo 2: Basic Pod Deployment"
    
    # Check if image exists and import to k3s if needed
    if check_k3s; then
        if ! k3s ctr images list | grep -q "k8s-demo-app:v1.0.0"; then
            print_warning "Image not found in k3s, importing..."
            if docker images k8s-demo-app:v1.0.0 --format "{{.Repository}}:{{.Tag}}" | grep -q "k8s-demo-app:v1.0.0"; then
                import_to_k3s "k8s-demo-app:v1.0.0"
            else
                print_error "Docker image k8s-demo-app:v1.0.0 not found. Please build it first (option 0)."
                return 1
            fi
        fi
    fi
    
    print_info "Deploying a basic Pod..."
    kubectl apply -f 04-pod.yaml
    
    wait_for_pod "k8s-demo-pod"
    
    echo -e "\n${PURPLE}📋 Pod Information:${NC}"
    kubectl get pod k8s-demo-pod -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}📋 Pod Description:${NC}"
    kubectl describe pod k8s-demo-pod -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}🔍 Testing Pod Health:${NC}"
    kubectl exec k8s-demo-pod -n "$NAMESPACE" -- curl -s http://localhost:8080/health
    
    print_success "Demo 2 completed - Basic Pod is running!"
    log "Demo 2 completed: Basic Pod deployment"
}

# Demo 3: Service and Networking
demo_service() {
    print_header "Demo 3: Service và Networking"
    
    print_info "Creating Services for Pod networking..."
    kubectl apply -f 05-service.yaml
    
    echo -e "\n${PURPLE}📋 Services Information:${NC}"
    kubectl get svc -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}🔍 Testing Service Connectivity:${NC}"
    
    # Test ClusterIP service
    print_info "Testing ClusterIP service..."
    kubectl run test-pod --image=busybox --rm -it --restart=Never -n "$NAMESPACE" -- wget -qO- http://k8s-demo-service/health
    
    # Show NodePort access
    NODEPORT=$(kubectl get svc k8s-demo-nodeport -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    print_info "NodePort service available at: localhost:$NODEPORT"
    print_info "Test with: curl http://localhost:$NODEPORT/health"
    
    print_success "Demo 3 completed - Services are configured!"
    log "Demo 3 completed: Service and networking"
}

# Demo 4: Deployment
demo_deployment() {
    print_header "Demo 4: Deployment"
    
    # Check if image exists and import to k3s if needed
    if check_k3s; then
        if ! k3s ctr images list | grep -q "k8s-demo-app:v1.0.0"; then
            print_warning "Image not found in k3s, importing..."
            if docker images k8s-demo-app:v1.0.0 --format "{{.Repository}}:{{.Tag}}" | grep -q "k8s-demo-app:v1.0.0"; then
                import_to_k3s "k8s-demo-app:v1.0.0"
            else
                print_error "Docker image k8s-demo-app:v1.0.0 not found. Please build it first (option 0)."
                return 1
            fi
        fi
    fi
    
    print_info "Creating Deployment with multiple replicas..."
    kubectl apply -f 06-deployment.yaml
    
    wait_for_deployment "k8s-demo-deployment"
    
    echo -e "\n${PURPLE}📋 Deployment Information:${NC}"
    kubectl get deployment k8s-demo-deployment -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}📋 Pods Information:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app -o wide
    
    echo -e "\n${PURPLE}📋 Deployment Features:${NC}"
    echo "- Multiple replicas for high availability"
    echo "- Rolling update strategy"
    echo "- Self-healing capabilities"
    echo "- Resource limits and requests"
    echo "- Health checks (liveness & readiness probes)"
    
    print_success "Demo 4 completed - Deployment created!"
    log "Demo 4 completed: Deployment"
}

# Demo 5: Self-healing Demo
demo_self_healing() {
    print_header "Demo 5: Self-healing Demo"
    
    # Check if deployment exists
    if ! kubectl get deployment k8s-demo-deployment -n "$NAMESPACE" &> /dev/null; then
        print_error "Deployment not found. Please deploy it first (option 4)."
        return 1
    fi
    
    # Check if service exists
    if ! kubectl get svc k8s-demo-nodeport -n "$NAMESPACE" &> /dev/null; then
        print_error "Service not found. Please deploy services first (option 3)."
        return 1
    fi
    
    echo -e "\n${PURPLE}📋 Current Deployment Status:${NC}"
    kubectl get deployment k8s-demo-deployment -n "$NAMESPACE" -o wide
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}🔍 Self-healing Test 1: Pod Deletion${NC}"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app -o jsonpath='{.items[0].metadata.name}')
    
    print_info "Deleting pod: $POD_NAME"
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
    
    print_info "Waiting for self-healing..."
    sleep 10
    
    print_info "Pods after self-healing:"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}🔍 Self-healing Test 2: Application Crash${NC}"
    print_info "Crashing application via API..."
    curl -X POST "http://localhost:30080/api/crash" || echo "Request sent"
    
    print_info "Waiting for Kubernetes to detect crash and restart..."
    sleep 15
    
    print_info "Pods after crash:"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}🔍 Self-healing Test 3: Health Check Failure${NC}"
    print_info "Making application unhealthy..."
    curl -X POST "http://localhost:30080/api/unhealthy"
    
    print_info "Waiting for liveness probe to detect unhealthy state..."
    sleep 30
    
    print_info "Pods after health check failure:"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    print_info "Resetting application to healthy state..."
    curl -X POST "http://localhost:30080/api/reset"
    
    print_success "Demo 5 completed - Self-healing demonstrated!"
    log "Demo 5 completed: Self-healing demo"
}

# Demo 6: Rolling Updates
demo_rolling_update() {
    print_header "Demo 6: Rolling Updates"
    
    # Check if v2.0.0 image exists
    if ! docker images k8s-demo-app:v2.0.0 --format "{{.Repository}}:{{.Tag}}" | grep -q "k8s-demo-app:v2.0.0"; then
        print_info "Building v2.0.0 image for rolling update demo..."
        cd "$SCRIPT_DIR/../app"
        docker build -t k8s-demo-app:v2.0.0 .
        cd "$SCRIPT_DIR"
        
        # Import to k3s if needed
        if check_k3s; then
            import_to_k3s "k8s-demo-app:v2.0.0"
        fi
    fi
    
    print_info "Current deployment status:"
    kubectl get deployment k8s-demo-deployment -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}🔄 Performing Rolling Update:${NC}"
    print_info "Updating image to v2.0.0..."
    kubectl set image deployment/k8s-demo-deployment app=k8s-demo-app:v2.0.0 -n "$NAMESPACE"
    
    print_info "Watching rolling update progress..."
    kubectl rollout status deployment/k8s-demo-deployment -n "$NAMESPACE" --timeout=300s
    
    echo -e "\n${PURPLE}📋 Post-update status:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}📜 Rollout History:${NC}"
    kubectl rollout history deployment/k8s-demo-deployment -n "$NAMESPACE"
    
    print_success "Demo 6 completed - Rolling update demonstrated!"
    log "Demo 6 completed: Rolling updates"
}

# Demo 7: Rollback Deployment
demo_rollback() {
    print_header "Demo 7: Rollback Deployment"
    
    print_info "Current deployment status:"
    kubectl get deployment k8s-demo-deployment -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}📜 Rollout History:${NC}"
    kubectl rollout history deployment/k8s-demo-deployment -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}🔙 Performing Rollback:${NC}"
    print_info "Rolling back to previous version..."
    kubectl rollout undo deployment/k8s-demo-deployment -n "$NAMESPACE"
    
    print_info "Watching rollback progress..."
    kubectl rollout status deployment/k8s-demo-deployment -n "$NAMESPACE" --timeout=300s
    
    echo -e "\n${PURPLE}📋 Post-rollback status:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}📜 Updated Rollout History:${NC}"
    kubectl rollout history deployment/k8s-demo-deployment -n "$NAMESPACE"
    
    print_success "Demo 7 completed - Rollback demonstrated!"
    log "Demo 7 completed: Rollback deployment"
}

# Demo 8: Deploy HPA
demo_hpa() {
    print_header "Demo 8: Deploy HPA (Horizontal Pod Autoscaling)"
    
    # Check if metrics-server is available
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        print_warning "Metrics-server not found. Installing metrics-server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        print_info "Waiting for metrics-server to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
        
        print_info "Waiting for metrics to be available..."
        sleep 30
    fi
    
    print_info "Creating HPA..."
    kubectl apply -f 07-hpa.yaml
    
    echo -e "\n${PURPLE}📋 HPA Information:${NC}"
    kubectl get hpa -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}🔍 Current Resource Usage:${NC}"
    kubectl top pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}📊 HPA Configuration:${NC}"
    echo "- Min Replicas: 1"
    echo "- Max Replicas: 5"
    echo "- CPU Target: 5%"
    echo "- Memory Target: 80%"
    
    print_info "HPA is now monitoring the deployment. Use option 9 to generate load."
    
    print_success "Demo 8 completed - HPA deployed!"
    log "Demo 8 completed: HPA deployment"
}

# Demo 9: Generate Load
demo_load() {
    print_header "Demo 9: Generate Load (Test HPA Scaling)"
    
    # Check if HPA exists
    if ! kubectl get hpa k8s-demo-hpa -n "$NAMESPACE" &> /dev/null; then
        print_error "HPA not found. Please deploy HPA first (option 8)."
        return 1
    fi
    
    echo -e "\n${PURPLE}📋 Before Load Generation:${NC}"
    kubectl get hpa -n "$NAMESPACE"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    echo -e "\n${PURPLE}⚡ Starting Load Generation:${NC}"
    print_info "Generating heavy load with curl (50 concurrent requests)..."
    
    # Generate continuous heavy load
    for i in {1..50}; do
        (while true; do 
            curl -s "http://localhost:30080/api/load?iterations=50000000" > /dev/null
            sleep 0.1
        done) &
    done
    
    print_info "Heavy load generation started. Monitoring HPA for 5 minutes..."
    
    for i in {1..60}; do
        echo -e "\n${CYAN}--- Check $i/60 (every 5s) ---${NC}"
        kubectl get hpa -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app --no-headers | wc -l | xargs echo "Pod count:"
        kubectl top pods -n "$NAMESPACE" -l app=k8s-demo-app 2>/dev/null || echo "Metrics not ready yet"
        sleep 5
    done
    
    print_info "Stopping load generation..."
    pkill -f "curl.*api/load" || true
    sleep 5
    
    echo -e "\n${PURPLE}📋 After Load Generation:${NC}"
    kubectl get hpa -n "$NAMESPACE"
    kubectl get pods -n "$NAMESPACE" -l app=k8s-demo-app
    
    print_info "HPA will scale down gradually after load decreases."
    
    print_success "Demo 9 completed - Load generation and scaling demonstrated!"
    log "Demo 9 completed: Load generation and HPA scaling"
}

# Demo 10: Jobs and CronJobs
demo_jobs() {
    print_header "Demo 10: Jobs và CronJobs"
    
    print_info "Creating Jobs and CronJobs..."
    kubectl apply -f 08-jobs.yaml
    
    echo -e "\n${PURPLE}📋 Jobs Information:${NC}"
    kubectl get jobs -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}📋 CronJobs Information:${NC}"
    kubectl get cronjobs -n "$NAMESPACE" -o wide
    
    print_info "Waiting for job to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/k8s-demo-job -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 Job Status:${NC}"
    kubectl get jobs -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📜 Job Logs:${NC}"
    kubectl logs job/k8s-demo-job -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 CronJob Status:${NC}"
    kubectl get cronjobs -n "$NAMESPACE"
    
    print_info "CronJob will run every 5 minutes. Monitor with:"
    echo "kubectl get jobs -n $NAMESPACE -w"
    
    print_success "Demo 10 completed - Jobs and CronJobs demonstrated!"
    log "Demo 10 completed: Jobs and CronJobs"
}

# Demo 11: Persistent Volume
demo_persistent_volume() {
    print_header "Demo 11: Persistent Volume"
    
    print_info "Creating PersistentVolume and PersistentVolumeClaim..."
    kubectl apply -f 10-persistent-volume.yaml
    
    echo -e "\n${PURPLE}📋 PersistentVolume Information:${NC}"
    kubectl get pv -o wide
    
    echo -e "\n${PURPLE}📋 PersistentVolumeClaim Information:${NC}"
    kubectl get pvc -n "$NAMESPACE" -o wide
    
    wait_for_deployment "k8s-demo-deployment-with-volume"
    
    echo -e "\n${PURPLE}📋 Deployment with Volume:${NC}"
    kubectl get deployment k8s-demo-deployment-with-volume -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}🔍 Testing Persistent Storage:${NC}"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l variant=with-volume -o jsonpath='{.items[0].metadata.name}')
    
    print_info "Writing data to persistent volume..."
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- sh -c "echo 'Hello from persistent volume!' > /data/test.txt"
    
    print_info "Reading data from persistent volume..."
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- cat /data/test.txt
    
    print_info "Restarting pod to test persistence..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
    
    # Wait for new pod
    sleep 10
    NEW_POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l variant=with-volume -o jsonpath='{.items[0].metadata.name}')
    
    print_info "Reading data from new pod..."
    kubectl exec "$NEW_POD_NAME" -n "$NAMESPACE" -- cat /data/test.txt
    
    print_success "Demo 11 completed - Persistent storage demonstrated!"
    log "Demo 11 completed: Persistent Volume"
}

# Show cluster status
show_status() {
    print_header "Current Cluster Status"
    
    echo -e "\n${PURPLE}📋 Namespace Resources:${NC}"
    kubectl get all -n "$NAMESPACE" -o wide
    
    echo -e "\n${PURPLE}📋 ConfigMaps and Secrets:${NC}"
    kubectl get configmaps,secrets -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 Persistent Volumes:${NC}"
    kubectl get pv,pvc -n "$NAMESPACE"
    
    echo -e "\n${PURPLE}📋 HPA Status:${NC}"
    kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "No HPA found"
    
    echo -e "\n${PURPLE}📋 Jobs and CronJobs:${NC}"
    kubectl get jobs,cronjobs -n "$NAMESPACE" 2>/dev/null || echo "No Jobs/CronJobs found"
    
    echo -e "\n${PURPLE}📊 Resource Usage:${NC}"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics not available"
}

# Cleanup resources
cleanup() {
    print_header "Cleanup Resources"
    
    print_warning "This will delete all demo resources!"
    echo -e "${YELLOW}Are you sure? (y/N)${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Cleaning up resources..."
        
        # Delete namespace (this will delete all resources in it)
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        
        # Delete PersistentVolume (not namespaced)
        kubectl delete pv k8s-demo-pv --ignore-not-found=true
        
        # Remove local data directory
        sudo rm -rf /tmp/k8s-demo-data 2>/dev/null || true
        
        print_success "Cleanup completed!"
        log "Cleanup completed"
    else
        print_info "Cleanup cancelled."
    fi
}

# Main menu
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    K8s Interactive Demo                     ║"
    echo "║                                                              ║"
    echo "║  Select a demo to run:                                       ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  1. Namespace và Basic Configuration                        ║"
    echo "║  2. Basic Pod Deployment                                     ║"
    echo "║  3. Service và Networking                                    ║"
    echo "║  4. Deployment                                               ║"
    echo "║  5. Self-healing Demo                                        ║"
    echo "║  6. Rolling Updates                                          ║"
    echo "║  7. Rollback Deployment                                      ║"
    echo "║  8. Deploy HPA (Horizontal Pod Autoscaling)                 ║"
    echo "║  9. Generate Load (Test HPA Scaling)                        ║"
    echo "║  10. Jobs và CronJobs                                        ║"
    echo "║  11. Persistent Volume                                       ║"
    echo "║                                                              ║"
    echo "║  s. Show Current Status                                      ║"
    echo "║  0. Build Docker Image                                       ║"
    echo "║  i. Import Images to k3s                                     ║"
    echo "║  c. Cleanup All Resources                                    ║"
    echo "║  q. Quit                                                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Enter your choice:${NC} "
}

# Main function
main() {
    # Initialize log file
    echo "=== K8s Interactive Demo Started at $(date) ===" > "$LOG_FILE"
    
    # Check prerequisites
    check_kubectl
    check_docker
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                demo_namespace
                wait_for_user
                ;;
            2)
                demo_pod
                wait_for_user
                ;;
            3)
                demo_service
                wait_for_user
                ;;
            4)
                demo_deployment
                wait_for_user
                ;;
            5)
                demo_self_healing
                wait_for_user
                ;;
            6)
                demo_rolling_update
                wait_for_user
                ;;
            7)
                demo_rollback
                wait_for_user
                ;;
            8)
                demo_hpa
                wait_for_user
                ;;
            9)
                demo_load
                wait_for_user
                ;;
            10)
                demo_jobs
                wait_for_user
                ;;
            11)
                demo_persistent_volume
                wait_for_user
                ;;
            s|S)
                show_status
                wait_for_user
                ;;
            0)
                build_image
                wait_for_user
                ;;
            i|I)
                import_to_k3s
                wait_for_user
                ;;
            c|C)
                cleanup
                wait_for_user
                ;;
            q|Q)
                print_info "Goodbye!"
                log "Demo session ended"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"