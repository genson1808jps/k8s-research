# Kubernetes Demo - Thực hành các Features của K8s

Đây là một demo thực tế để chứng minh các tính năng chính của Kubernetes bằng cách sử dụng một web service đơn giản được xây dựng bằng Golang.

## 🎯 Mục tiêu

Demo này sẽ chứng minh các K8s features sau:
- **Pod Management & Health Checks**: Liveness/Readiness probes
- **Horizontal Scaling**: Manual và automatic scaling
- **Configuration Management**: ConfigMaps và Secrets
- **Rolling Updates**: Zero-downtime deployments
- **Service Discovery**: Load balancing giữa pods
- **Security**: RBAC, Security contexts
- **Networking**: Services, Ingress, Network policies
- **Monitoring**: Logs, events, metrics

## 🏗️ Kiến trúc Demo

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client        │    │   Kubernetes    │    │   Application   │
│                 │    │                 │    │                 │
│  Browser/curl   ├────┤  Services       ├────┤  Go Web Server  │
│                 │    │  Ingress        │    │  - Health Check │
│                 │    │  Load Balancer  │    │  - Metrics      │
└─────────────────┘    └─────────────────┘    │  - Config API   │
                                              │  - Load Testing │
                                              └─────────────────┘
```

## 📋 Prerequisites

### 1. Cài đặt các tools cần thiết:

**Docker:**
```bash
# macOS
brew install docker

# Linux
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

**kubectl:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Kubernetes Cluster** (chọn một trong các options sau):

**Option A: Minikube (Recommended cho local development)**
```bash
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --cpus=2 --memory=4096
```

**Option B: Docker Desktop Kubernetes**
- Enable Kubernetes trong Docker Desktop settings
- Đảm bảo context đang được set to `docker-desktop`

**Option C: Kind (Kubernetes in Docker)**
```bash
# Install
brew install kind  # macOS
# hoặc download từ GitHub releases

# Create cluster
kind create cluster --name k8s-demo
```

### 2. Verify setup:
```bash
kubectl cluster-info
kubectl get nodes
```

## 🚀 Quick Start

### 1. Clone và setup project:
```bash
git clone <repository-url>
cd k8s-research/k8s-demo
```

### 2. Build Docker image:
```bash
./scripts/build-and-push.sh
```

### 3. Deploy application:
```bash
./scripts/deploy.sh
```

### 4. Chạy demo interactive:
```bash
./scripts/demo-features.sh
```

### 5. Cleanup khi hoàn thành:
```bash
./scripts/cleanup.sh
```

## 📁 Cấu trúc Project

```
k8s-demo/
├── app/                        # Go application source
│   ├── main.go                # Web server với multiple endpoints
│   ├── go.mod                 # Go dependencies
│   ├── Dockerfile             # Multi-stage Docker build
│   └── .dockerignore          # Docker build optimization
├── k8s-manifests/             # Kubernetes YAML files
│   ├── namespace.yaml         # Namespace isolation
│   ├── configmap.yaml         # Application configuration
│   ├── secret.yaml            # Sensitive data
│   ├── rbac.yaml              # Role-based access control
│   ├── deployment.yaml        # Deployment với health checks
│   ├── service.yaml           # ClusterIP và NodePort services
│   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   ├── ingress.yaml           # HTTP routing
│   ├── networkpolicy.yaml     # Network security
│   └── all-in-one.yaml        # Combined manifest
├── scripts/                   # Automation scripts
│   ├── build-and-push.sh      # Build Docker image
│   ├── deploy.sh              # Deploy to Kubernetes
│   ├── demo-features.sh       # Interactive demo
│   └── cleanup.sh             # Resource cleanup
└── README.md                  # Documentation
```

## 🔍 Application Endpoints

Web service cung cấp các endpoints sau:

| Endpoint | Mô tả | Demo Feature |
|----------|-------|--------------|
| `/` | Homepage với navigation | User interface |
| `/health` | Health check endpoint | Liveness probe |
| `/ready` | Readiness check endpoint | Readiness probe |
| `/api/info` | Pod information (hostname, version) | Service discovery |
| `/api/config` | Configuration values | ConfigMap/Secret |
| `/api/metrics` | Prometheus-style metrics | Monitoring |
| `/api/load` | CPU-intensive task | HPA triggering |

## 📊 Demo Features Chi tiết

### 1. Health Checks & Pod Management
```bash
# View pod status
kubectl get pods -n k8s-demo

# Check health endpoints
kubectl exec -n k8s-demo <pod-name> -- wget -qO- http://localhost:8080/health
kubectl exec -n k8s-demo <pod-name> -- wget -qO- http://localhost:8080/ready

# View probe configuration
kubectl describe pods -n k8s-demo
```

### 2. Horizontal Scaling
```bash
# Manual scaling
kubectl scale deployment k8s-demo-app --replicas=5 -n k8s-demo
kubectl get pods -n k8s-demo -w

# Auto-scaling (nếu HPA được deploy)
kubectl apply -f k8s-manifests/hpa.yaml
kubectl get hpa -n k8s-demo

# Generate load để trigger HPA
for i in {1..10}; do curl -s "http://localhost:30080/api/load?iterations=10000000" > /dev/null & done
```

### 3. Configuration Management
```bash
# View ConfigMap
kubectl get configmap app-config -n k8s-demo -o yaml

# View Secret (base64 encoded)
kubectl get secret app-secrets -n k8s-demo -o yaml

# Decode secret
kubectl get secret app-secrets -n k8s-demo -o jsonpath='{.data.API_SECRET}' | base64 -d

# Test config endpoint
curl http://localhost:30080/api/config
```

### 4. Rolling Updates
```bash
# Update image (simulated failure)
kubectl set image deployment/k8s-demo-app app=k8s-demo-app:v2.0.0 -n k8s-demo

# Watch rollout status
kubectl rollout status deployment/k8s-demo-app -n k8s-demo

# Rollback
kubectl rollout undo deployment/k8s-demo-app -n k8s-demo

# View rollout history
kubectl rollout history deployment/k8s-demo-app -n k8s-demo
```

### 5. Service Discovery & Load Balancing
```bash
# View services
kubectl get services -n k8s-demo

# Test load balancing
for i in {1..5}; do curl -s http://localhost:30080/api/info | jq .hostname; done

# Port forward để access qua ClusterIP
kubectl port-forward service/k8s-demo-app-service 8080:80 -n k8s-demo
```

### 6. Security (RBAC)
```bash
# View RBAC resources
kubectl get serviceaccount -n k8s-demo
kubectl get role -n k8s-demo
kubectl get rolebinding -n k8s-demo

# Check permissions
kubectl auth can-i get pods --as=system:serviceaccount:k8s-demo:k8s-demo-app-sa -n k8s-demo
```

### 7. Monitoring & Debugging
```bash
# View logs
kubectl logs -f deployment/k8s-demo-app -n k8s-demo

# View events
kubectl get events -n k8s-demo --sort-by='.lastTimestamp'

# Resource usage (nếu metrics server available)
kubectl top pods -n k8s-demo
kubectl top nodes

# Describe resources for troubleshooting
kubectl describe deployment k8s-demo-app -n k8s-demo
```

## 🌐 Accessing the Application

### Local Access Options:

1. **NodePort** (direct node access):
   ```bash
   # Minikube
   minikube ip  # Get IP
   # Access: http://<minikube-ip>:30080
   
   # Docker Desktop / Kind
   # Access: http://localhost:30080
   ```

2. **Port Forward** (recommended):
   ```bash
   kubectl port-forward service/k8s-demo-app-service 8080:80 -n k8s-demo
   # Access: http://localhost:8080
   ```

3. **Ingress** (nếu ingress controller available):
   ```bash
   # Deploy ingress controller (ví dụ nginx)
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   
   # Apply ingress
   kubectl apply -f k8s-manifests/ingress.yaml
   
   # Add to /etc/hosts
   echo "$(minikube ip) k8s-demo.local" | sudo tee -a /etc/hosts
   # Access: http://k8s-demo.local
   ```

## 🧪 Testing Scenarios

### Scenario 1: Pod Failure Recovery
```bash
# Delete một pod
kubectl delete pod <pod-name> -n k8s-demo

# Watch Kubernetes recreate it
kubectl get pods -n k8s-demo -w
```

### Scenario 2: Resource Limits
```bash
# Generate memory/CPU load
curl "http://localhost:30080/api/load?iterations=50000000"

# Monitor resource usage
kubectl top pods -n k8s-demo
```

### Scenario 3: Configuration Updates
```bash
# Update ConfigMap
kubectl patch configmap app-config -n k8s-demo -p '{"data":{"ENVIRONMENT":"updated"}}'

# Restart deployment để pick up changes
kubectl rollout restart deployment/k8s-demo-app -n k8s-demo
```

## 🔧 Troubleshooting

### Common Issues:

1. **Image Pull Errors**:
   ```bash
   # Check if image exists
   docker images | grep k8s-demo-app
   
   # Rebuild if necessary
   ./scripts/build-and-push.sh
   ```

2. **Pod Not Ready**:
   ```bash
   # Check pod events
   kubectl describe pod <pod-name> -n k8s-demo
   
   # Check logs
   kubectl logs <pod-name> -n k8s-demo
   ```

3. **Service Not Accessible**:
   ```bash
   # Check service endpoints
   kubectl get endpoints -n k8s-demo
   
   # Check service configuration
   kubectl describe service k8s-demo-app-service -n k8s-demo
   ```

4. **HPA Not Working**:
   ```bash
   # Check if metrics server is running
   kubectl get pods -n kube-system | grep metrics-server
   
   # Install metrics server nếu cần
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

## 🎓 Learning Outcomes

Sau khi hoàn thành demo này, bạn sẽ hiểu:

1. **Pod Lifecycle**: Tạo, health checks, restart policies
2. **Deployments**: Rolling updates, rollbacks, scaling
3. **Services**: Load balancing, service discovery
4. **Configuration**: Separation of config from code
5. **Security**: RBAC, security contexts, network policies
6. **Observability**: Logging, monitoring, debugging
7. **Resource Management**: Requests, limits, autoscaling

## 📚 Tài liệu tham khảo

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Go HTTP Server Best Practices](https://golang.org/doc/articles/wiki/)
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

## 🤝 Contributing

Feel free to submit issues và pull requests để improve demo này!

## 📄 License

MIT License - see LICENSE file for details. 