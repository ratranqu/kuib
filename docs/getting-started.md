# Getting Started

## Prerequisites

- **Swift 6.2+** — Install from [swift.org](https://swift.org/download/) or via swiftenv
- **Docker** — For running PostgreSQL locally
- **kubectl** — For Kubernetes cluster access
- **A Kubernetes cluster** — Local (Docker Desktop, Minikube, Kind) or remote

## Local Development Setup

### 1. Start PostgreSQL

```bash
docker run -d --name kuib-postgres \
  -e POSTGRES_DB=kuib \
  -e POSTGRES_USER=kuib \
  -e POSTGRES_PASSWORD=kuib \
  -p 5432:5432 \
  postgres:16-alpine
```

### 2. Configure Kubernetes Access

KUIB uses your local kubeconfig by default:

```bash
# Verify you have cluster access
kubectl cluster-info
kubectl get nodes
```

If using a specific kubeconfig:
```bash
export KUBECONFIG=/path/to/your/kubeconfig
```

### 3. Build and Run

```bash
# Clone the repository
git clone <repository-url> kuib
cd kuib

# Build
swift build

# Run
swift run kuib
```

The server starts on `http://localhost:8080` by default.

### 4. Command-Line Options

```bash
swift run kuib --help

# Custom host/port
swift run kuib --host 127.0.0.1 --port 3000

# Custom log level
swift run kuib --log-level debug
```

## Project Layout

```
Sources/
├── App/          # Entry point
├── Server/       # HTTP routes
├── Pages/        # HTML views
├── Components/   # Reusable UI components
├── K8s/          # Kubernetes client
├── Database/     # PostgreSQL
├── Alerts/       # Alert engine
└── Models/       # Shared types
```

## Development Workflow

1. Edit Swift files in `Sources/`
2. `swift build` to check for compilation errors
3. `swift run kuib` to run locally
4. `swift test --filter KuibTests` to run unit tests
5. Open `http://localhost:8080` to see changes

## Running Without a Cluster

KUIB gracefully handles missing Kubernetes connectivity. If no cluster is available, pages will render with empty data. This is useful for working on UI components and styling.

## Running Without PostgreSQL

If PostgreSQL is unavailable, KUIB logs a warning and continues. Historical features (log archives, job history, alert persistence) will be disabled, but live monitoring from the Kubernetes API works normally.

## IDE Setup

### VS Code
Install the Swift extension from the VS Code marketplace. The project's `Package.swift` will be auto-detected.

### Xcode
```bash
open Package.swift
```
Xcode will resolve dependencies and index the project.

## Next Steps

- [Configuration Reference](configuration.md) — All environment variables
- [Deployment Guide](deployment/kubernetes.md) — Deploy to Kubernetes
- [Testing Guide](testing.md) — Running and writing tests
