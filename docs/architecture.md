# Architecture

## System Overview

KUIB is a Swift web application that provides a monitoring dashboard for Kubernetes clusters. It follows a layered architecture with clear separation between data access, business logic, and presentation.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                    Browser                          │
│  ┌───────────────────────────────────────────────┐  │
│  │  Elementary (SSR HTML) + HTMX (interactivity) │  │
│  │  ─ Server-rendered pages with Tailwind CSS    │  │
│  │  ─ HTMX for partial updates + SSE for live    │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP / SSE
              ┌────────┴────────┐
              │  oauth2-proxy   │  (external)
              └────────┬────────┘
                       │ X-Forwarded-User
┌──────────────────────┴──────────────────────────────┐
│              Hummingbird Server (Swift)              │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────────┐  │
│  │ Pages    │ │ API      │ │ Background Services  │  │
│  │ (HTML)   │ │ (JSON)   │ │ ─ ResourceWatchers   │  │
│  │          │ │          │ │ ─ AlertEngine         │  │
│  └─────┬────┘ └────┬─────┘ └──────────┬──────────┘  │
│        │           │                   │             │
│    ┌───┴───────────┴───────────────────┴──────┐      │
│    │            ResourceCache (Actor)          │      │
│    │     Thread-safe in-memory state store     │      │
│    └──────────────┬───────────────────────────┘      │
└───────────────────┼──────────────────────────────────┘
          ┌─────────┴─────────┐
          │                   │
   ┌──────┴──────┐    ┌──────┴──────┐
   │ Kubernetes  │    │ PostgreSQL  │
   │ API Server  │    │ ─ Events    │
   │ (in-cluster)│    │ ─ Logs      │
   └─────────────┘    │ ─ Alerts    │
                      │ ─ Job Runs  │
                      └─────────────┘
```

## Module Structure

### Models
Shared data types used across all layers. These are UI-friendly representations of Kubernetes resources, decoupled from SwiftkubeClient types. This allows pages and components to render without importing Kubernetes-specific libraries.

### K8s
- **K8sClientProtocol** — Testable interface for Kubernetes operations
- **SwiftkubeK8sClient** — Production implementation using SwiftkubeClient
- **ResourceCache** — Actor-based in-memory cache for all resource state
- **ResourceWatcher** — Background polling loops that refresh cache from K8s API

### Database
- **DatabaseManager** — PostgreSQL connection, migrations, and query methods
- Persists events, pod logs, job run history, and fired alerts

### Alerts
- **AlertEngine** — Subscribes to cache events, evaluates rules, fires alerts
- **WebhookDispatcher** — Sends HTTP POST to configured endpoints with retry

### Pages
Elementary HTML documents for each resource type. Each page reads from the ResourceCache and renders server-side HTML.

### Components
Reusable HTML components: BaseLayout, HealthBadge, StatCard, ResourceTable, etc.

### Server
Hummingbird routes (page routes and JSON API routes) and middleware (auth).

### App
Application entry point. Initializes all services and starts the server.

## Data Flow

1. **ResourceWatchers** poll the Kubernetes API at configurable intervals
2. Fresh data is written to the **ResourceCache** (actor)
3. The cache notifies **AlertEngine** subscribers of changes
4. AlertEngine evaluates rules and dispatches webhooks via **WebhookDispatcher**
5. HTTP requests read from the cache and render HTML via **Elementary**
6. HTMX on the client polls partial endpoints for live updates
7. Selected data (events, logs, job history, alerts) is persisted to **PostgreSQL**

## Design Decisions

### Why polling instead of K8s watch API?
The initial implementation uses polling for simplicity and reliability. Kubernetes watch connections can drop and require careful reconnection handling. Polling with configurable intervals (5s for pods, 15s for deployments, 60s for nodes) provides a good balance of freshness and API load. The architecture supports upgrading to watches later.

### Why an actor for ResourceCache?
Swift actors provide safe concurrent access without manual locking. Multiple HTTP handlers and background watchers read/write the cache concurrently.

### Why Elementary over Leaf/Stencil/Mustache?
Elementary provides type-safe, SwiftUI-inspired HTML composition with zero dependencies. It catches errors at compile time rather than runtime, and its streaming renderer is memory-efficient for large pages.

### Why HTMX over a SPA framework?
HTMX provides dynamic updates with minimal JavaScript. Server-rendered HTML means the application works without JavaScript enabled (degraded), pages are indexable, and there's no client-side state to manage. This aligns with the monitoring dashboard use case where users primarily view data.
