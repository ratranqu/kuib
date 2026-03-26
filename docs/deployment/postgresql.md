# PostgreSQL Setup

## In-Cluster (Default)

The provided `Kubernetes/postgres.yaml` deploys a single-replica PostgreSQL instance with a PersistentVolumeClaim.

```bash
kubectl apply -f Kubernetes/postgres.yaml
```

This creates:
- A `Secret` with database credentials
- A `PersistentVolumeClaim` (10Gi)
- A `Deployment` running PostgreSQL 16
- A `Service` on port 5432

## Managed PostgreSQL

For production, use a managed database:

### AWS RDS
```bash
# Set environment variables in deployment.yaml
KUIB_DB_HOST: your-rds-instance.region.rds.amazonaws.com
KUIB_DB_PORT: "5432"
KUIB_DB_NAME: kuib
KUIB_DB_USER: kuib
KUIB_DB_PASSWORD: <from-secret>
```

### Google CloudSQL
Use the CloudSQL proxy sidecar or direct connection with the CloudSQL Auth Proxy.

## Schema

KUIB manages its own schema via auto-migrations. On startup, it creates:

1. `schema_migrations` — Migration tracking
2. `k8s_events` — Persisted Kubernetes events
3. `pod_logs` — Archived pod log snapshots
4. `job_runs` — Job execution history
5. `fired_alerts` — Alert history
6. `webhook_endpoints` — Webhook configuration
7. `alert_rules` — Alert rule configuration

## Backup

```bash
# Dump the database
kubectl exec -n kuib deploy/kuib-postgres -- \
  pg_dump -U kuib kuib > kuib-backup.sql

# Restore
kubectl exec -i -n kuib deploy/kuib-postgres -- \
  psql -U kuib kuib < kuib-backup.sql
```

## Data Retention

KUIB automatically cleans up old data based on retention settings:
- **Logs**: `KUIB_LOG_RETENTION_DAYS` (default: 30 days)
- **Events**: `KUIB_EVENT_RETENTION_DAYS` (default: 14 days)
