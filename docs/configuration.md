# Configuration Reference

All configuration is via environment variables. Local development uses sensible defaults.

## Server

| Variable | Default | Description |
|----------|---------|-------------|
| `KUIB_HOST` | `0.0.0.0` | Bind address. Use `127.0.0.1` for local-only access. |
| `KUIB_PORT` | `8080` | HTTP port. |
| `KUIB_LOG_LEVEL` | `info` | Log verbosity: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical`. |

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `KUIB_DB_HOST` | `localhost` | PostgreSQL hostname. |
| `KUIB_DB_PORT` | `5432` | PostgreSQL port. |
| `KUIB_DB_NAME` | `kuib` | Database name. Created automatically if using the provided Docker setup. |
| `KUIB_DB_USER` | `kuib` | Database user. |
| `KUIB_DB_PASSWORD` | `kuib` | Database password. **Change in production.** |

## Data Retention

| Variable | Default | Description |
|----------|---------|-------------|
| `KUIB_LOG_RETENTION_DAYS` | `30` | Days to keep archived pod logs. |
| `KUIB_EVENT_RETENTION_DAYS` | `14` | Days to keep persisted Kubernetes events. |

## Kubernetes

KUIB auto-detects its Kubernetes connection:

1. **In-cluster** — Uses the ServiceAccount token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`
2. **kubeconfig** — Falls back to `$KUBECONFIG` or `~/.kube/config`

No environment variables are needed for K8s connectivity.

## Watcher Intervals

The resource watcher uses three polling tiers (not configurable via env vars, set in code):

| Tier | Interval | Resources |
|------|----------|-----------|
| Fast | 5 seconds | Pods, Events |
| Normal | 15 seconds | Deployments, Jobs, CronJobs, StatefulSets, DaemonSets, Services, Ingresses |
| Slow | 60 seconds | Nodes, Namespaces, ConfigMaps, Secrets, PVCs |

## Authentication

KUIB trusts the following headers set by oauth2-proxy:

| Header | Usage |
|--------|-------|
| `X-Forwarded-User` | Logged for audit trail |
| `X-Forwarded-Email` | Logged for audit trail |

No KUIB-specific auth configuration is needed. See the [OAuth2 Proxy deployment guide](deployment/oauth2-proxy.md) for setup.
