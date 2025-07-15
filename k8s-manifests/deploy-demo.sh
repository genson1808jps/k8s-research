#!/bin/bash

# K8s Demo Deployment Script
# Triển khai từng tính năng K8s một cách có thứ tự

set -e

NAMESPACE="k8s-demo"
DOCKER_IMAGE="k8s-demo-app:v1.0.0"

echo "🚀 Starting K8s Demo Deployment..."

# Build Docker image first
echo "📦 Building Docker image..."
cd ../app
docker build -t $DOCKER_IMAGE .
cd ../k8s-manifests

# Function to wait for deployment ready
wait_for_deployment() {
    local deployment_name=$1
    echo "⏳ Waiting for deployment $deployment_name to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment_name -n $NAMESPACE
}

# Function to wait for pod ready
wait_for_pod() {
    local pod_name=$1
    echo "⏳ Waiting for pod $pod_name to be ready..."
    kubectl wait --for=condition=ready --timeout=300s pod/$pod_name -n $NAMESPACE
}

# 1. Create namespace and basic config
echo "🏗️  Step 1: Creating namespace and configuration..."
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secret.yaml
kubectl apply -f 09-resource-quota.yaml

# 2. Demo Pod
echo "🎯 Step 2: Deploying basic Pod..."
kubectl apply -f 04-pod.yaml
wait_for_pod "k8s-demo-pod"

# 3. Demo Service
echo "🔗 Step 3: Creating Services..."
kubectl apply -f 05-service.yaml

# Test basic connectivity
echo "🧪 Testing basic Pod connectivity..."
kubectl port-forward pod/k8s-demo-pod 8080:8080 -n $NAMESPACE &
PF_PID=$!
sleep 5
curl -s http://localhost:8080/health || echo "Health check failed"
kill $PF_PID

# 4. Demo Deployment with Self-healing
echo "🔄 Step 4: Deploying with Self-healing (Deployment)..."
kubectl apply -f 06-deployment.yaml
wait_for_deployment "k8s-demo-deployment"

# Test self-healing by killing a pod
echo "🧪 Testing Self-healing..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=k8s-demo-app,version=v1.0.0 -o jsonpath='{.items[0].metadata.name}')
echo "Killing pod: $POD_NAME"
kubectl delete pod $POD_NAME -n $NAMESPACE
echo "Waiting for new pod to be created..."
sleep 10
kubectl get pods -n $NAMESPACE -l app=k8s-demo-app

# 5. Demo HPA (Horizontal Pod Autoscaling)
echo "📈 Step 5: Setting up HPA..."
# Check if metrics-server is available
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    kubectl apply -f 07-hpa.yaml
    echo "HPA deployed. Generate load to test scaling:"
    echo "kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh"
    echo "while true; do wget -q -O- http://k8s-demo-service.k8s-demo.svc.cluster.local/api/load?iterations=10000000; done"
else
    echo "⚠️  Metrics-server not found. Install it first for HPA demo:"
    echo "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi

# 6. Demo Jobs
echo "⚡ Step 6: Running Jobs and CronJobs..."
kubectl apply -f 08-jobs.yaml

# 7. Demo Rolling Updates
echo "🔄 Step 7: Demonstrating Rolling Updates..."
echo "Current deployment:"
kubectl get deployment k8s-demo-deployment -n $NAMESPACE

# Update image version to trigger rolling update
echo "Updating to v2.0.0..."
kubectl set image deployment/k8s-demo-deployment app=k8s-demo-app:v2.0.0 -n $NAMESPACE

# Watch rolling update
echo "Watching rolling update..."
kubectl rollout status deployment/k8s-demo-deployment -n $NAMESPACE

# Rollback demo
echo "Demonstrating rollback..."
kubectl rollout undo deployment/k8s-demo-deployment -n $NAMESPACE
kubectl rollout status deployment/k8s-demo-deployment -n $NAMESPACE

# 8. Demo Persistent Volume
echo "💾 Step 8: Deploying with Persistent Volume..."
kubectl apply -f 10-persistent-volume.yaml
wait_for_deployment "k8s-demo-deployment-with-volume"

# Final status
echo "✅ Demo deployment completed!"
echo ""
echo "📊 Current status:"
kubectl get all -n $NAMESPACE
echo ""
echo "🔍 Useful commands:"
echo "  View all resources: kubectl get all -n $NAMESPACE"
echo "  Access app: kubectl port-forward svc/k8s-demo-service 8080:80 -n $NAMESPACE"
echo "  Check logs: kubectl logs -f deployment/k8s-demo-deployment -n $NAMESPACE"
echo "  Check HPA: kubectl get hpa -n $NAMESPACE"
echo "  Check PV: kubectl get pv,pvc -n $NAMESPACE"
echo "  Cleanup: kubectl delete namespace $NAMESPACE"