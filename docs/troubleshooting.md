# Troubleshooting

## Common Issues

### KUIB shows empty data / "No pods found"

**Cause**: Cannot connect to Kubernetes API.

**Check**:
```bash
# Verify cluster access
kubectl cluster-info

# If running in-cluster, check ServiceAccount
kubectl get sa kuib -n kuib
kubectl describe clusterrolebinding kuib-reader-binding
```

**Fix**: Ensure RBAC is configured correctly. The ServiceAccount needs `get`, `list`, `watch` permissions.

### Database connection failed

**Cause**: PostgreSQL is unreachable or credentials are wrong.

**Check**:
```bash
# Verify PostgreSQL is running
kubectl get pods -n kuib -l app.kubernetes.io/component=database

# Test connection
kubectl exec -n kuib deploy/kuib-postgres -- pg_isready -U kuib
```

**Fix**: Check `KUIB_DB_*` environment variables match the PostgreSQL configuration. KUIB continues without a database (historical features disabled).

### Logs show "Failed to poll <resource>"

**Cause**: Kubernetes API returning errors for specific resource types.

**Check**: Look at the specific error message. Common causes:
- RBAC missing for that resource type
- API group not available (e.g., networking.k8s.io for older clusters)

**Fix**: Update the ClusterRole in `rbac.yaml` to include the missing resource.

### Alerts not firing

**Check**:
1. Verify alert rules are loaded: visit `/alerts/rules`
2. Check webhook endpoints are configured: visit `/alerts/webhooks`
3. Review alert history: visit `/alerts`
4. Check logs for "Alert fired" messages

**Common issues**:
- Rule is disabled
- Cooldown period hasn't expired (default: 5 minutes)
- Namespace filter excluding the affected resource
- No webhook endpoints configured

### Webhook delivery failing

**Check**: Visit `/alerts` and look for "Failed" delivery status.

**Common causes**:
- Webhook URL is unreachable from the cluster
- Endpoint returns non-2xx status
- Network policy blocking outbound traffic
- TLS certificate issues

**Debug**:
```bash
# Test connectivity from the KUIB pod
kubectl exec -n kuib deploy/kuib -- curl -v https://your-webhook-url
```

### High memory usage

**Cause**: Large cluster with many resources cached in memory.

**Fix**:
- Increase memory limits in `deployment.yaml`
- Reduce polling intervals for less critical resources
- Consider namespace filtering to monitor only relevant namespaces

### Pages load slowly

**Cause**: Large number of resources being rendered.

**Fix**:
- Use namespace filtering to reduce the resource count per page
- Pagination is built-in (default: 100 items per page for API queries)

## Debug Logging

Enable verbose logging:
```bash
# Via environment variable
KUIB_LOG_LEVEL=debug swift run kuib

# Via command line
swift run kuib --log-level trace
```

Log categories:
- `kuib` — General application
- `kuib.k8s` — Kubernetes client operations
- `kuib.watcher` — Resource watcher polling
- `kuib.db` — Database operations
- `kuib.alerts` — Alert evaluation
- `kuib.webhooks` — Webhook dispatch
- `kuib.auth` — Authentication headers

## Getting Help

- Check the [documentation](.)
- Review [Architecture](architecture.md) for system understanding
- File an issue on the repository
