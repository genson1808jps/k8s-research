#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

NAMESPACE="k8s-demo"

# Utility function to wait for user input
wait_for_input() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Header
show_header() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}🎯 Kubernetes Features Demo${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo
}

# Feature 1: Pod Management and Health Checks
demo_health_checks() {
    echo -e "${BLUE}🏥 Demo 1: Health Checks & Pod Management${NC}"
    echo -e "${CYAN}This demo shows how Kubernetes manages pod health${NC}"
    echo
    
    echo -e "${YELLOW}📋 Current pod status:${NC}"
    kubectl get pods -n ${NAMESPACE}
    wait_for_input
    
    echo -e "${YELLOW}🔍 Detailed pod information:${NC}"
    kubectl describe pods -n ${NAMESPACE} | grep -A 10 -B 5 "Liveness\|Readiness"
    wait_for_input
    
    echo -e "${YELLOW}📊 Testing health endpoints:${NC}"
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=k8s-demo-app -o jsonpath='{.items[0].metadata.name}')
    echo "Pod: ${POD_NAME}"
    kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -qO- http://localhost:8080/health
    echo
    kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -qO- http://localhost:8080/ready
    echo
    wait_for_input
}

# Feature 2: Scaling
demo_scaling() {
    echo -e "${BLUE}📈 Demo 2: Horizontal Scaling${NC}"
    echo -e "${CYAN}This demo shows manual and automatic scaling${NC}"
    echo
    
    echo -e "${YELLOW}Current replicas:${NC}"
    kubectl get deployment k8s-demo-app -n ${NAMESPACE}
    wait_for_input
    
    echo -e "${YELLOW}📈 Scaling to 5 replicas:${NC}"
    kubectl scale deployment k8s-demo-app --replicas=5 -n ${NAMESPACE}
    kubectl get pods -n ${NAMESPACE} -w --timeout=30s
    wait_for_input
    
    echo -e "${YELLOW}📉 Scaling back to 3 replicas:${NC}"
    kubectl scale deployment k8s-demo-app --replicas=3 -n ${NAMESPACE}
    kubectl get pods -n ${NAMESPACE} -w --timeout=30s
    wait_for_input
    
    echo -e "${YELLOW}🤖 Checking HPA status (if enabled):${NC}"
    kubectl get hpa -n ${NAMESPACE} 2>/dev/null || echo "HPA not deployed"
    wait_for_input
}

# Feature 3: Configuration Management
demo_config_management() {
    echo -e "${BLUE}⚙️  Demo 3: Configuration Management${NC}"
    echo -e "${CYAN}This demo shows ConfigMaps and Secrets${NC}"
    echo
    
    echo -e "${YELLOW}📋 ConfigMap contents:${NC}"
    kubectl get configmap app-config -n ${NAMESPACE} -o yaml
    wait_for_input
    
    echo -e "${YELLOW}🔐 Secret contents (base64 encoded):${NC}"
    kubectl get secret app-secrets -n ${NAMESPACE} -o yaml
    wait_for_input
    
    echo -e "${YELLOW}🌐 Testing config endpoint:${NC}"
    NODE_PORT=$(kubectl get service k8s-demo-app-nodeport -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    echo "curl http://localhost:${NODE_PORT}/api/config"
    if command -v curl &> /dev/null; then
        curl -s http://localhost:${NODE_PORT}/api/config | jq . 2>/dev/null || curl -s http://localhost:${NODE_PORT}/api/config
    else
        echo "curl not available, use browser to access the URL above"
    fi
    echo
    wait_for_input
}

# Feature 4: Rolling Updates
demo_rolling_updates() {
    echo -e "${BLUE}🔄 Demo 4: Rolling Updates${NC}"
    echo -e "${CYAN}This demo shows zero-downtime updates${NC}"
    echo
    
    echo -e "${YELLOW}Current image version:${NC}"
    kubectl get deployment k8s-demo-app -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}'
    echo
    wait_for_input
    
    echo -e "${YELLOW}📦 Updating to v2.0.0 (simulated):${NC}"
    echo "kubectl set image deployment/k8s-demo-app app=k8s-demo-app:v2.0.0 -n ${NAMESPACE}"
    echo "Note: This will fail as v2.0.0 doesn't exist, showing rollback scenario"
    wait_for_input
    
    kubectl set image deployment/k8s-demo-app app=k8s-demo-app:v2.0.0 -n ${NAMESPACE}
    
    echo -e "${YELLOW}👀 Watching rollout status:${NC}"
    kubectl rollout status deployment/k8s-demo-app -n ${NAMESPACE} --timeout=60s || true
    wait_for_input
    
    echo -e "${YELLOW}🔙 Rolling back to previous version:${NC}"
    kubectl rollout undo deployment/k8s-demo-app -n ${NAMESPACE}
    kubectl rollout status deployment/k8s-demo-app -n ${NAMESPACE}
    wait_for_input
}

# Feature 5: Service Discovery and Load Balancing
demo_service_discovery() {
    echo -e "${BLUE}🌐 Demo 5: Service Discovery & Load Balancing${NC}"
    echo -e "${CYAN}This demo shows how services work${NC}"
    echo
    
    echo -e "${YELLOW}📋 Available services:${NC}"
    kubectl get services -n ${NAMESPACE}
    wait_for_input
    
    echo -e "${YELLOW}🔍 Service details:${NC}"
    kubectl describe service k8s-demo-app-service -n ${NAMESPACE}
    wait_for_input
    
    echo -e "${YELLOW}🎯 Testing load balancing:${NC}"
    echo "Multiple requests will be distributed across pods"
    NODE_PORT=$(kubectl get service k8s-demo-app-nodeport -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    
    for i in {1..5}; do
        echo -e "${CYAN}Request ${i}:${NC}"
        if command -v curl &> /dev/null; then
            curl -s http://localhost:${NODE_PORT}/api/info | jq .hostname 2>/dev/null || curl -s http://localhost:${NODE_PORT}/api/info | grep hostname
        else
            echo "Use: curl http://localhost:${NODE_PORT}/api/info"
        fi
        sleep 1
    done
    wait_for_input
}

# Feature 6: Load Testing (for HPA demo)
demo_load_testing() {
    echo -e "${BLUE}💪 Demo 6: Load Testing (HPA Trigger)${NC}"
    echo -e "${CYAN}This demo generates CPU load to trigger autoscaling${NC}"
    echo
    
    NODE_PORT=$(kubectl get service k8s-demo-app-nodeport -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo -e "${YELLOW}🚀 Generating load... (this may take a minute)${NC}"
    echo "Sending multiple concurrent requests to /api/load endpoint"
    
    if command -v curl &> /dev/null; then
        for i in {1..10}; do
            curl -s "http://localhost:${NODE_PORT}/api/load?iterations=10000000" > /dev/null &
        done
        wait
    else
        echo "curl not available. Use this command manually:"
        echo "for i in {1..10}; do curl -s \"http://localhost:${NODE_PORT}/api/load?iterations=10000000\" > /dev/null & done"
    fi
    
    echo -e "${YELLOW}📊 Check CPU usage and HPA status:${NC}"
    kubectl top pods -n ${NAMESPACE} 2>/dev/null || echo "Metrics server not available"
    kubectl get hpa -n ${NAMESPACE} 2>/dev/null || echo "HPA not deployed"
    wait_for_input
}

# Feature 7: Logs and Debugging
demo_logs_debugging() {
    echo -e "${BLUE}🐛 Demo 7: Logs and Debugging${NC}"
    echo -e "${CYAN}This demo shows how to debug and monitor applications${NC}"
    echo
    
    echo -e "${YELLOW}📜 Recent application logs:${NC}"
    kubectl logs --tail=20 -l app=k8s-demo-app -n ${NAMESPACE}
    wait_for_input
    
    echo -e "${YELLOW}🔍 Pod events:${NC}"
    kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10
    wait_for_input
    
    echo -e "${YELLOW}📊 Resource usage:${NC}"
    kubectl top pods -n ${NAMESPACE} 2>/dev/null || echo "Metrics server not available"
    wait_for_input
}

# Main menu
show_menu() {
    echo -e "${GREEN}Choose a demo:${NC}"
    echo "1. Health Checks & Pod Management"
    echo "2. Horizontal Scaling"
    echo "3. Configuration Management"  
    echo "4. Rolling Updates"
    echo "5. Service Discovery & Load Balancing"
    echo "6. Load Testing (HPA Trigger)"
    echo "7. Logs and Debugging"
    echo "8. Run All Demos"
    echo "9. Exit"
    echo
    echo -n "Enter your choice [1-9]: "
}

# Main script
main() {
    show_header
    
    # Check if deployment exists
    if ! kubectl get deployment k8s-demo-app -n ${NAMESPACE} &> /dev/null; then
        echo -e "${RED}❌ k8s-demo-app deployment not found in namespace ${NAMESPACE}${NC}"
        echo -e "${YELLOW}Please run deploy.sh first${NC}"
        exit 1
    fi
    
    while true; do
        show_menu
        read choice
        echo
        
        case $choice in
            1) demo_health_checks ;;
            2) demo_scaling ;;
            3) demo_config_management ;;
            4) demo_rolling_updates ;;
            5) demo_service_discovery ;;
            6) demo_load_testing ;;
            7) demo_logs_debugging ;;
            8) 
                demo_health_checks
                demo_scaling
                demo_config_management
                demo_rolling_updates
                demo_service_discovery
                demo_load_testing
                demo_logs_debugging
                ;;
            9) 
                echo -e "${GREEN}👋 Thanks for using the K8s demo!${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
        echo
        echo -e "${PURPLE}================================================${NC}"
        echo
    done
}

main 