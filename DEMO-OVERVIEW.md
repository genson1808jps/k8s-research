# Kubernetes Demo Overview

Đây là phần demo thực tế đi kèm với [tài liệu nghiên cứu Kubernetes](../kubernetes-research.md).

## 🔄 Từ Lý thuyết đến Thực hành

### Mapping giữa Research và Demo:

| **Khái niệm trong Research** | **Demo Implementation** | **File/Script** |
|------------------------------|-------------------------|-----------------|
| **Pod** | Go web server containers | `app/main.go`, `deployment.yaml` |
| **Service** | ClusterIP, NodePort services | `service.yaml` |
| **Deployment** | Rolling updates, replicas | `deployment.yaml`, `demo-features.sh` |
| **ConfigMap & Secret** | Environment configuration | `configmap.yaml`, `secret.yaml` |
| **Namespace** | Resource isolation | `namespace.yaml` |
| **Health Checks** | Liveness/Readiness probes | `app/main.go` (`/health`, `/ready`) |
| **Horizontal Scaling** | Manual và HPA | `hpa.yaml`, scaling demos |
| **RBAC** | ServiceAccount, Role, RoleBinding | `rbac.yaml` |
| **Network Policies** | Pod communication rules | `networkpolicy.yaml` |
| **Ingress** | HTTP routing | `ingress.yaml` |

## 🎯 Demo chứng minh các Features chính

### 1. Container Orchestration
- ✅ **Tự động scheduling**: Pods được deploy across nodes
- ✅ **Health checking**: Liveness/Readiness probes tự động restart
- ✅ **Resource management**: CPU/Memory requests & limits

### 2. Service Discovery & Load Balancing  
- ✅ **DNS-based discovery**: Services accessible qua DNS
- ✅ **Load balancing**: Traffic distributed across pods
- ✅ **Multiple service types**: ClusterIP, NodePort

### 3. Storage Orchestration
- ✅ **ConfigMap volumes**: Configuration mounted as files
- ✅ **Secret volumes**: Sensitive data securely injected

### 4. Automated Rollouts & Rollbacks
- ✅ **Rolling updates**: Zero-downtime deployments
- ✅ **Rollback capability**: Tự động rollback khi fail

### 5. Self-healing
- ✅ **Container restart**: Failed containers tự động restart
- ✅ **Pod rescheduling**: Pods recreated khi nodes fail
- ✅ **Health check killing**: Unhealthy containers bị kill

### 6. Configuration Management
- ✅ **ConfigMap**: Non-sensitive configuration
- ✅ **Secret**: Sensitive data (passwords, tokens)
- ✅ **Runtime injection**: Config available as env vars

### 7. Horizontal Pod Autoscaling
- ✅ **CPU-based scaling**: Scale based on CPU usage
- ✅ **Memory-based scaling**: Scale based on memory usage
- ✅ **Custom metrics**: Có thể extend với custom metrics

### 8. Security Features
- ✅ **RBAC**: Role-based access control
- ✅ **Security contexts**: Non-root user, capabilities
- ✅ **Network policies**: Network segmentation

## 🚀 Quick Demo Commands

```bash
# 1. Setup
cd k8s-demo
./scripts/build-and-push.sh
./scripts/deploy.sh

# 2. Verify deployment
kubectl get all -n k8s-demo

# 3. Test application
curl http://localhost:30080/
curl http://localhost:30080/api/info

# 4. Demo scaling
kubectl scale deployment k8s-demo-app --replicas=5 -n k8s-demo
kubectl get pods -n k8s-demo -w

# 5. Demo rolling update
kubectl set image deployment/k8s-demo-app app=k8s-demo-app:v2.0.0 -n k8s-demo
kubectl rollout undo deployment/k8s-demo-app -n k8s-demo

# 6. Demo configuration
kubectl get configmap app-config -n k8s-demo -o yaml
curl http://localhost:30080/api/config

# 7. Demo health checks  
kubectl describe pods -n k8s-demo | grep -A 5 Probes

# 8. Interactive demo
./scripts/demo-features.sh

# 9. Cleanup
./scripts/cleanup.sh
```

## 📈 Learning Path

1. **Đọc research document** - Hiểu concepts
2. **Chạy quick start** - Hands-on experience  
3. **Explore individual features** - Deep dive từng feature
4. **Run interactive demo** - Guided walkthrough
5. **Experiment với modifications** - Tự customize
6. **Try advanced scenarios** - Production-like scenarios

## 💡 Next Steps

Sau khi hoàn thành demo này, bạn có thể:

1. **Extend application**: Thêm database, caching
2. **Production setup**: Multi-node cluster, monitoring stack
3. **CI/CD integration**: GitOps, automated deployments  
4. **Advanced networking**: Service mesh (Istio)
5. **Observability**: Prometheus, Grafana, distributed tracing
6. **Security hardening**: Pod Security Standards, admission controllers

## 🔗 Related Resources

- [Kubernetes Research Document](../kubernetes-research.md)
- [Demo README](./README.md)
- [Kubernetes Official Tutorials](https://kubernetes.io/docs/tutorials/)
- [CNCF Landscape](https://landscape.cncf.io/) 