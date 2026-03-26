# KUIB — Kubernetes UI Board

A Swift-native web UI for monitoring and debugging Kubernetes workloads. KUIB provides Jenkins-like visibility into your cluster's health, jobs, and services with real-time updates, historical log access, and configurable alerting.

## Features

- **Cluster Dashboard** — Real-time overview of pods, deployments, nodes, and alerts
- **Full Resource Coverage** — Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, Services, Ingresses, Nodes, Events, ConfigMaps, Secrets, PVCs
- **Live Log Streaming** — Stream container logs in real-time with a built-in log viewer
- **Historical Logs** — Pod logs persisted to PostgreSQL, accessible after pod termination
- **Job Timeline** — Jenkins-style pass/fail timeline for Jobs and CronJobs
- **Alerting Engine** — Built-in rules for CrashLoopBackOff, OOMKilled, failed deployments, and more
- **Webhook Notifications** — Generic webhook dispatcher for Slack, Discord, PagerDuty, etc.
- **Namespace Filtering** — Filter any resource view by namespace
- **HTMX Live Updates** — Automatic page refresh without full page reload
- **OAuth2 Proxy Auth** — Secured behind oauth2-proxy with X-Forwarded-User header support

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6.2 |
| Web Server | [Hummingbird 2](https://github.com/hummingbird-project/hummingbird) |
| HTML Rendering | [Elementary](https://github.com/elementary-swift/elementary) |
| Interactivity | [HTMX](https://htmx.org) + [ElementaryHTMX](https://github.com/elementary-swift/elementary-htmx) |
| Styling | [Tailwind CSS](https://tailwindcss.com) |
| K8s Client | [SwiftkubeClient](https://github.com/swiftkube/client) |
| Database | PostgreSQL via [PostgresNIO](https://github.com/vapor/postgres-nio) |
| Auth | [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) (external) |

## Quick Start

### Prerequisites

- Swift 6.2+
- Docker (for PostgreSQL)
- Access to a Kubernetes cluster (or kubeconfig)

### Local Development

```bash
# Start PostgreSQL
docker run -d --name kuib-postgres \
  -e POSTGRES_DB=kuib \
  -e POSTGRES_USER=kuib \
  -e POSTGRES_PASSWORD=kuib \
  -p 5432:5432 \
  postgres:16-alpine

# Build and run
swift run kuib

# Open http://localhost:8080
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KUIB_HOST` | `0.0.0.0` | Server bind address |
| `KUIB_PORT` | `8080` | Server bind port |
| `KUIB_LOG_LEVEL` | `info` | Log level (trace, debug, info, warning, error) |
| `KUIB_DB_HOST` | `localhost` | PostgreSQL host |
| `KUIB_DB_PORT` | `5432` | PostgreSQL port |
| `KUIB_DB_NAME` | `kuib` | Database name |
| `KUIB_DB_USER` | `kuib` | Database user |
| `KUIB_DB_PASSWORD` | `kuib` | Database password |
| `KUIB_LOG_RETENTION_DAYS` | `30` | Days to retain stored logs |
| `KUIB_EVENT_RETENTION_DAYS` | `14` | Days to retain stored events |

### Deploy to Kubernetes

```bash
# Build the Docker image
docker build -t kuib:latest .

# Apply Kubernetes manifests
kubectl apply -f Kubernetes/namespace.yaml
kubectl apply -f Kubernetes/serviceaccount.yaml
kubectl apply -f Kubernetes/rbac.yaml
kubectl apply -f Kubernetes/postgres.yaml
kubectl apply -f Kubernetes/deployment.yaml
kubectl apply -f Kubernetes/service.yaml

# Port forward to access
kubectl port-forward -n kuib svc/kuib 8080:80
```

## Project Structure

```
kuib/
├── Package.swift              # Swift package manifest
├── Sources/
│   ├── App/                   # Entry point, application bootstrap
│   ├── Server/                # Hummingbird routes and middleware
│   │   ├── Routes/            # Page and API route handlers
│   │   └── Middleware/        # Auth middleware
│   ├── Pages/                 # Elementary HTML page views
│   ├── Components/            # Reusable HTML components
│   ├── K8s/                   # Kubernetes client, watchers, cache
│   ├── Database/              # PostgreSQL manager, migrations
│   ├── Alerts/                # Alert engine, webhook dispatcher
│   └── Models/                # Shared data models
├── Kubernetes/                # K8s deployment manifests
├── Tests/
│   ├── KuibTests/             # Unit tests
│   ├── KuibIntegrationTests/  # Integration tests (requires Kind)
│   └── Fixtures/              # Test fixture data
├── Dockerfile                 # Multi-stage production build
└── docs/                      # Documentation
```

## Testing

```bash
# Run unit tests
swift test --filter KuibTests

# Run integration tests (requires Kind cluster)
KIND_AVAILABLE=true swift test --filter KuibIntegrationTests

# Run all tests
swift test
```

## Documentation

- [Architecture](docs/architecture.md) — System design and data flow
- [Getting Started](docs/getting-started.md) — Local development setup
- [Configuration](docs/configuration.md) — All configuration options
- [Deployment](docs/deployment/) — Kubernetes, PostgreSQL, and OAuth2 setup
- [Alerting](docs/alerting/) — Alert rules and webhook configuration
- [User Guide](docs/user-guide/) — Feature walkthrough
- [Contributing](docs/contributing.md) — Development workflow
- [Testing](docs/testing.md) — Testing guide

## License

Apache 2.0
