# Kubernetes Deployment Guide

## Prerequisites

- A Kubernetes cluster (1.24+)
- `kubectl` configured with cluster access
- Container registry access (for pushing the KUIB image)

## Build the Image

```bash
docker build -t your-registry/kuib:latest .
docker push your-registry/kuib:latest
```

## Deploy

Apply manifests in order:

```bash
# 1. Namespace
kubectl apply -f Kubernetes/namespace.yaml

# 2. RBAC (ServiceAccount + ClusterRole + Binding)
kubectl apply -f Kubernetes/serviceaccount.yaml
kubectl apply -f Kubernetes/rbac.yaml

# 3. PostgreSQL
kubectl apply -f Kubernetes/postgres.yaml

# 4. KUIB application
kubectl apply -f Kubernetes/deployment.yaml
kubectl apply -f Kubernetes/service.yaml
```

## Verify

```bash
# Check pods are running
kubectl get pods -n kuib

# Check KUIB logs
kubectl logs -n kuib deploy/kuib

# Port forward to access locally
kubectl port-forward -n kuib svc/kuib 8080:80
```

## RBAC Permissions

The `kuib-reader` ClusterRole grants:

**Read access** (get, list, watch):
- Pods, Pods/log, Services, Events, Namespaces, Nodes
- ConfigMaps, Secrets, PersistentVolumeClaims
- Deployments, StatefulSets, DaemonSets
- Jobs, CronJobs
- Ingresses

**Write access** (for UI actions):
- Pod delete
- Deployment scale (update/patch)
- Job delete

To restrict to read-only, remove the write permission rules from `rbac.yaml`.

## Production Considerations

### Database Credentials
Replace the default credentials in `Kubernetes/postgres.yaml`:
```bash
kubectl create secret generic kuib-postgres-credentials \
  -n kuib \
  --from-literal=POSTGRES_DB=kuib \
  --from-literal=POSTGRES_USER=kuib \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 32)
```

### Image Reference
Update `Kubernetes/deployment.yaml` with your actual image:
```yaml
image: your-registry/kuib:v1.0.0
imagePullPolicy: Always
```

### Resource Limits
Adjust CPU/memory limits in `deployment.yaml` based on cluster size:
- Small cluster (<100 pods): 128Mi/100m
- Medium cluster (100-1000): 512Mi/500m
- Large cluster (1000+): 1Gi/1000m

### PostgreSQL
For production, consider using a managed PostgreSQL service (RDS, CloudSQL, etc.) instead of the in-cluster deployment. Update the `KUIB_DB_*` environment variables accordingly.

### Ingress
Edit `Kubernetes/service.yaml` to set your actual hostname:
```yaml
rules:
  - host: kuib.your-domain.com
```
