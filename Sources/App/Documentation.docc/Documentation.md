# ``App``

KUIB — Kubernetes UI Board. A Swift-native web UI for monitoring and debugging Kubernetes workloads.

## Overview

KUIB provides a Jenkins-like monitoring experience for Kubernetes clusters, built entirely in Swift using Hummingbird for the web server and Elementary for HTML rendering.

### Architecture

The application is organized into several modules:

- **Models** — Shared data types for Kubernetes resources
- **K8s** — Kubernetes client protocol, SwiftkubeClient wrapper, resource cache, and watchers
- **Database** — PostgreSQL persistence for events, logs, job history, and alerts
- **Alerts** — Alert evaluation engine and webhook dispatcher
- **Pages** — Elementary HTML pages for the web UI
- **Components** — Reusable HTML components (badges, cards, tables)
- **Server** — Hummingbird routes and middleware
- **App** — Application entry point and bootstrap

### Getting Started

See the [Getting Started guide](https://github.com/ratranqu/kuib/blob/main/docs/getting-started.md) for local development setup.

## Topics

### Essentials
- <doc:Architecture>
